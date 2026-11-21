import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_failure.dart';
import 'live_models.dart';

/// The broadcast message as realtime_client hands it over; the snapshot sits
/// under its `payload` key.
typedef LiveBroadcastHandler = void Function(Map<String, dynamic> message);
typedef LiveStatusHandler = void Function(
  RealtimeSubscribeStatus status,
  Object? error,
);

/// One joined `pro:<id>` channel, seen only as something to close.
abstract interface class LiveChannel {
  Future<void> close();
}

/// Joins [topic] privately, listening to the `live` event. A seam: tests pass
/// a fake.
typedef LiveChannelFactory = LiveChannel Function(
  String topic,
  LiveBroadcastHandler onBroadcast,
  LiveStatusHandler onStatus,
);

/// `pro_live_snapshots`: at most [maxSnapshotIds] ids per call; ids the
/// caller may not see are absent from the result.
typedef LiveSnapshotFetcher = Future<Map<String, LiveSnapshot>> Function(
  List<String> proIds,
);

const maxSnapshotIds = 60;

class SupabaseLiveChannel implements LiveChannel {
  SupabaseLiveChannel._(this._client, this._channel);

  factory SupabaseLiveChannel.join(
    SupabaseClient client,
    String topic,
    LiveBroadcastHandler onBroadcast,
    LiveStatusHandler onStatus,
  ) {
    final channel = client
        .channel(topic, opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(event: 'live', callback: onBroadcast)
        .subscribe(onStatus);
    return SupabaseLiveChannel._(client, channel);
  }

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  Future<void> close() => _client.removeChannel(_channel);
}

class _Topic {
  _Topic(this.proId);

  final String proId;
  final sinks = <StreamController<LiveSnapshot>>{};

  /// The owner's listeners (a subset of [sinks]): they keep an unlisted pro.
  final own = <StreamController<LiveSnapshot>>{};
  LiveChannel? channel;

  /// Identifies the current channel: callbacks of a closed one are dropped.
  Object? token;
  Timer? linger;
  Timer? down;
  Timer? retry;
  bool isDown = false;

  void cancelTimers() {
    linger?.cancel();
    down?.cancel();
    retry?.cancel();
    linger = down = retry = null;
  }
}

/// One per app: ref-counts `pro:<id>` private channels, independent of which
/// widget shows them.
///
/// * A channel is shared by every listener of a pro and lingers [linger]
///   after the last one leaves (scrolling back is free); its snapshot is
///   forgotten when it goes.
/// * Every (re)subscribe, and [refreshAll] (app resume), re-fetches
///   snapshots, batched over [batchWindow]: a message missed while the socket
///   was down is replaced by the server's current state.
/// * A snapshot not newer than the one held (`live_version`) is dropped.
/// * At most [maxChannels] channels (the server allows 100 per connection):
///   past it, lingering channels close first, then new pros are served by
///   fetches only until a slot frees. A fetch-only pro refreshes on attach
///   and on resume only: it gets no message in between.
/// * `Unauthorized` means no channel for that pro until [closeAll] (no
///   rejoin), not no pro: it is served by fetches only (on attach and on
///   resume), as a customer the pro blocked sees it (the server's closed
///   shape, whose versions are frozen at the block: a fetch-only pro takes
///   every fetch, whatever its version). Each resume tries its channel again
///   once, so an unblocked customer goes live again. Only when the fetch does not return the pro (another space,
///   unpublished) is it [LiveUnavailable] for everyone. A snapshot saying
///   `listed: false` is [LiveUnavailable] for customers only: the owner's
///   listeners ([watch] with `own`) keep receiving and fetching their pro.
///   None of these counts as a disconnection.
/// * Any other failure closes the channel and joins a new one after
///   [retryAfter]; [connected] turns false once a watched pro has been
///   failing for [downAfter].
class LiveChannels {
  LiveChannels({
    required LiveChannelFactory channelFactory,
    required this._fetch,
    this._onServerNow,
    this._onAlive,
    this.linger = const Duration(seconds: 10),
    this.batchWindow = const Duration(milliseconds: 250),
    this.downAfter = const Duration(seconds: 5),
    this.retryAfter = const Duration(seconds: 3),
    this.maxChannels = 80,
  }) : _factory = channelFactory;

  final LiveChannelFactory _factory;
  final LiveSnapshotFetcher _fetch;
  final void Function(DateTime serverNow)? _onServerNow;

  /// Told when the realtime path proves alive (a channel subscribed, a
  /// broadcast was taken): an earlier RPC failure is no longer the state.
  final void Function()? _onAlive;
  final Duration linger;
  final Duration batchWindow;
  final Duration downAfter;
  final Duration retryAfter;
  final int maxChannels;

  final _topics = <String, _Topic>{};
  final _held = <String, LiveSnapshot>{};

  // These outlive their topics (a returning listener must not wait ~5 s for
  // the same refusal) and are cleared by closeAll only.
  /// Refused at join: fetch-only, for everyone.
  final _unauthorized = <String>{};

  /// Refused at join and absent from the fetch: [LiveUnavailable].
  final _gone = <String>{};

  /// Unpublished: for customers; the owner's listeners bypass it.
  final _unlisted = <String>{};
  final _toFetch = <String>{};
  Timer? _fetchTimer;
  Timer? _rejoinTimer;

  // Bumped by closeAll: a fetch answered for the previous space is dropped.
  var _generation = 0;
  var _disposed = false;
  var _socketWasClosed = false;

  // Signed out: nothing may join or fetch (every join would be refused).
  var _suspended = false;

  var _connected = true;
  final _connectedController = StreamController<bool>.broadcast();

  bool get connected => _connected;

  /// Every change of [connected].
  Stream<bool> get connectedChanges => _connectedController.stream;

  /// The freshest snapshot known for [proId] in the current space.
  LiveSnapshot? latest(String proId) => _held[proId];

  /// Snapshots of [proId], starting with the held one. Errors with
  /// [LiveUnavailable] when the pro is refused or unlisted for this caller.
  /// The owner's screens pass [own]: an unpublished pro stays theirs.
  Stream<LiveSnapshot> watch(String proId, {bool own = false}) {
    late final StreamController<LiveSnapshot> sink;
    sink = StreamController<LiveSnapshot>(
      onListen: () => _attach(proId, sink, own: own),
      onCancel: () => _detach(proId, sink),
    );
    return sink.stream;
  }

  /// A snapshot read elsewhere (the `live` column of `search_pros`).
  void seed(LiveSnapshot snapshot) => _apply(snapshot);

  /// The user's Retry ("Hors ligne"): every watched pro whose channel is
  /// failing or waiting to rejoin joins a new one now, and every watched pro
  /// is fetched again, instead of waiting for [retryAfter] or a resume.
  void retryNow() {
    if (_disposed || _suspended || _rejoinTimer != null) return;
    for (final t in [..._topics.values]) {
      if (t.sinks.isEmpty || !_mayFetch(t)) continue;
      if (_mayJoin(t) && (t.retry != null || t.down != null || t.isDown)) {
        t.retry?.cancel();
        t.retry = null;
        _closeChannel(t);
        _open(t);
      }
      _queueFetch(t.proId);
    }
  }

  /// Fetches [proId] now and applies it, even when this device last saw the
  /// pro unlisted (a listed answer clears that: the profile's open brings a
  /// republished pro back). An answer from before a [closeAll] is dropped,
  /// as the batched fetches' are. Fetch failures are rethrown.
  Future<void> refresh(String proId) async {
    if (_disposed || _suspended || _gone.contains(proId)) return;
    final generation = _generation;
    final found = await _fetch([proId]);
    if (generation != _generation) return;
    final s = found[proId];
    if (s != null) {
      _apply(s);
    } else if (_unauthorized.contains(proId)) {
      _markGone(proId);
    }
  }

  /// Leaves [proId]'s channel and joins it again through the normal path,
  /// so the server authorizes it anew: a block since the join is then
  /// refused (fetch-only, closed). With nobody listening the topic simply
  /// goes, and the next listener joins fresh.
  void rejoin(String proId) {
    if (_disposed || _suspended) return;
    _unauthorized.remove(proId);
    final t = _topics[proId];
    if (t == null) return;
    if (t.sinks.isEmpty) {
      _removeTopic(t);
      _promote();
      return;
    }
    t.retry?.cancel();
    t.retry = null;
    _closeChannel(t);
    if (_rejoinTimer == null) _open(t);
  }

  /// Re-fetches every watched pro (app resume), and joins each refused
  /// one again once: a block lifted meanwhile is live again, a block still
  /// there is just refused again.
  void refreshAll() {
    final refused = [..._unauthorized];
    _unauthorized.clear();
    for (final id in refused) {
      final t = _topics[id];
      if (t != null && t.sinks.isNotEmpty && _rejoinTimer == null) _open(t);
    }
    for (final t in _topics.values) {
      if (_mayFetch(t)) _queueFetch(t.proId);
    }
  }

  /// Space, role or account change: the server authorizes a channel only
  /// when it is joined, so every channel closes and every held snapshot and
  /// refusal is forgotten. The listeners still there after [batchWindow]
  /// (the new screen's) are joined again; the old screen's leave before
  /// that. With [rejoin] false (signed out) nothing joins or fetches until
  /// the next [closeAll].
  void closeAll({bool rejoin = true}) {
    _generation++;
    _toFetch.clear();
    _fetchTimer?.cancel();
    _fetchTimer = null;
    _held.clear();
    _unauthorized.clear();
    _gone.clear();
    _unlisted.clear();
    for (final t in [..._topics.values]) {
      _closeChannel(t);
      t
        ..cancelTimers()
        ..isDown = false;
      if (t.sinks.isEmpty) _topics.remove(t.proId);
    }
    _recomputeConnected();
    _rejoinTimer?.cancel();
    _rejoinTimer = null;
    _suspended = !rejoin;
    if (!rejoin) return;
    _rejoinTimer = Timer(batchWindow, () {
      _rejoinTimer = null;
      for (final t in [..._topics.values]) {
        if (t.sinks.isNotEmpty) _open(t);
      }
    });
  }

  /// The socket closed. A drop also errors every channel, but a
  /// `disconnect()` (supabase_flutter's pause, a lost network seen by the
  /// client) tells no channel: every watched pro is failing from here.
  void socketClosed() {
    if (_disposed) return;
    _socketWasClosed = true;
    for (final t in [..._topics.values]) {
      if (t.channel == null) continue;
      if (t.sinks.isEmpty) {
        _removeTopic(t);
      } else {
        _markFailing(t);
      }
    }
  }

  /// The socket is open again after [socketClosed]. realtime_client's
  /// `connect()` rejoins only the channels it saw error (supabase_flutter's
  /// resume, 2.18.3, also calls `forceRejoin()` on the joined ones; a bare
  /// reconnect does not): every watched pro joins a new channel, whose
  /// subscribe re-fetches, whichever path reopened the socket.
  void socketOpened() {
    if (_disposed || !_socketWasClosed) return;
    _socketWasClosed = false;
    if (_rejoinTimer != null) return;
    for (final t in [..._topics.values]) {
      if (t.sinks.isEmpty || !_mayJoin(t)) continue;
      t.retry?.cancel();
      t.retry = null;
      _closeChannel(t);
      _open(t);
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _fetchTimer?.cancel();
    _rejoinTimer?.cancel();
    for (final t in _topics.values) {
      _closeChannel(t);
      t.cancelTimers();
      for (final s in [...t.sinks]) {
        unawaited(s.close());
      }
    }
    _topics.clear();
    _held.clear();
    unawaited(_connectedController.close());
  }

  int get _channelCount =>
      _topics.values.where((t) => t.channel != null).length;

  void _attach(
    String proId,
    StreamController<LiveSnapshot> sink, {
    required bool own,
  }) {
    if (_disposed) return;
    final t = _topics.putIfAbsent(proId, () => _Topic(proId));
    t.sinks.add(sink);
    if (own) t.own.add(sink);
    t.linger?.cancel();
    t.linger = null;
    if (_gone.contains(proId) || (!own && _unlisted.contains(proId))) {
      sink.addError(const LiveUnavailable());
      return;
    }
    final held = _held[proId];
    if (held != null) sink.add(held);
    if (_unauthorized.contains(proId)) {
      _queueFetch(proId);
      return;
    }
    if (t.channel == null && t.retry == null && _rejoinTimer == null) _open(t);
  }

  void _detach(String proId, StreamController<LiveSnapshot> sink) {
    final t = _topics[proId];
    if (t == null) return;
    t.sinks.remove(sink);
    t.own.remove(sink);
    if (t.sinks.isNotEmpty) return;
    if (t.channel == null) {
      _removeTopic(t);
      return;
    }
    t.linger = Timer(linger, () {
      _removeTopic(t);
      _promote();
    });
  }

  /// Forgets a pro nobody listens to: its channel, timers and snapshot.
  void _removeTopic(_Topic t) {
    _closeChannel(t);
    t.cancelTimers();
    _topics.remove(t.proId);
    _held.remove(t.proId);
    _recomputeConnected();
  }

  void _open(_Topic t) {
    if (_disposed || _suspended || t.channel != null) return;
    if (!_mayJoin(t)) return;
    if (_channelCount >= maxChannels) _evictLingering();
    if (_channelCount >= maxChannels) {
      // Fetch-only until a slot frees ([_promote]).
      _queueFetch(t.proId);
      return;
    }
    final token = Object();
    t.token = token;
    t.channel = _factory(
      'pro:${t.proId}',
      (message) {
        if (identical(t.token, token)) _onBroadcast(t, message);
      },
      (status, error) {
        if (identical(t.token, token)) _onStatus(t, status, error);
      },
    );
  }

  void _evictLingering() {
    for (final t in [..._topics.values]) {
      if (t.sinks.isEmpty && t.channel != null) {
        _removeTopic(t);
        return;
      }
    }
  }

  /// Gives a freed slot to a pro served by fetches only.
  void _promote() {
    if (_rejoinTimer != null) return;
    for (final t in [..._topics.values]) {
      if (_channelCount >= maxChannels) return;
      if (t.channel == null && t.sinks.isNotEmpty && t.retry == null) {
        _open(t);
      }
    }
  }

  void _closeChannel(_Topic t) {
    final c = t.channel;
    t.channel = null;
    t.token = null;
    if (c != null) {
      unawaited(
        c.close().catchError((Object e, StackTrace st) {
          developer.log('live channel close failed', error: e, stackTrace: st);
        }),
      );
    }
  }

  void _onStatus(_Topic t, RealtimeSubscribeStatus status, Object? error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        t.down?.cancel();
        t.down = null;
        t.isDown = false;
        _recomputeConnected();
        _onAlive?.call();
        _queueFetch(t.proId);
      case RealtimeSubscribeStatus.channelError
          when '$error'.contains('Unauthorized'):
        _refused(t);
      case RealtimeSubscribeStatus.timedOut:
        // realtime_client re-sends a timed-out join by itself.
        _markFailing(t);
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.closed:
        // An error join reply (rate limits) and a server close get no rejoin
        // from realtime_client (2.13.2), so join a new channel ourselves.
        _rejoinLater(t);
    }
  }

  /// No channel for this pro from now on: its listeners keep what they show
  /// and get one fetch; the fetch decides between served and gone. The held
  /// snapshot is forgotten: the fetch replaces it whatever its version.
  void _refused(_Topic t) {
    _unauthorized.add(t.proId);
    _held.remove(t.proId);
    if (t.sinks.isEmpty) {
      _removeTopic(t);
      _promote();
      return;
    }
    _closeChannel(t);
    t
      ..cancelTimers()
      ..isDown = false;
    _recomputeConnected();
    _queueFetch(t.proId);
    _promote();
  }

  /// Refused at join and not returned by the fetch: unavailable for everyone.
  void _markGone(String proId) {
    _gone.add(proId);
    _dropFor(proId, keepOwn: false);
  }

  void _rejoinLater(_Topic t) {
    if (t.sinks.isEmpty) {
      // Lingering: nobody to serve, so nothing to report or rejoin.
      _removeTopic(t);
      _promote();
      return;
    }
    _markFailing(t);
    _closeChannel(t);
    t.retry ??= Timer(retryAfter, () {
      t.retry = null;
      if (_topics[t.proId] == t && t.sinks.isNotEmpty) _open(t);
    });
  }

  void _markFailing(_Topic t) {
    t.down ??= Timer(downAfter, () {
      t.down = null;
      t.isDown = true;
      _recomputeConnected();
    });
  }

  /// Whether this topic may be fetched: never once gone, and when unlisted
  /// only for the owner's listeners.
  bool _mayFetch(_Topic t) =>
      !_gone.contains(t.proId) &&
      (!_unlisted.contains(t.proId) || t.own.isNotEmpty);

  /// Whether this topic may join a channel: as [_mayFetch], and never once
  /// refused at join.
  bool _mayJoin(_Topic t) => !_unauthorized.contains(t.proId) && _mayFetch(t);

  /// Gives every listener not entitled to [proId] a [LiveUnavailable]. With
  /// [keepOwn] the owner's listeners keep the channel; otherwise (or when
  /// none is attached) the channel, timers and snapshot go.
  void _dropFor(String proId, {required bool keepOwn}) {
    _toFetch.remove(proId);
    final t = _topics[proId];
    if (t != null) {
      for (final s in t.sinks) {
        if (!keepOwn || !t.own.contains(s)) {
          s.addError(const LiveUnavailable());
        }
      }
      if (keepOwn && t.own.isNotEmpty) return;
    }
    _held.remove(proId);
    if (t == null) return;
    _closeChannel(t);
    t
      ..cancelTimers()
      ..isDown = false;
    if (t.sinks.isEmpty) _topics.remove(proId);
    _recomputeConnected();
    _promote();
  }

  void _onBroadcast(_Topic t, Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return;
    try {
      final s = LiveSnapshot.fromJson(Map<String, Object?>.from(payload));
      if (s.proId == t.proId && _apply(s)) _onAlive?.call();
    } on Object catch (e, st) {
      // A malformed message must not kill the channel; the next fetch heals.
      developer.log('live broadcast dropped', error: e, stackTrace: st);
    }
  }

  /// Whether [s] was taken (newer than the held one).
  bool _apply(LiveSnapshot s) {
    if (_disposed || _gone.contains(s.proId)) return false;
    final held = _held[s.proId];
    // A fetch-only pro gets no message to order: each fetch is the state.
    if (held != null &&
        !s.isNewerThan(held) &&
        !_unauthorized.contains(s.proId)) {
      return false;
    }
    final t = _topics[s.proId];
    final hasOwn = t != null && t.own.isNotEmpty;
    if (!s.listed) {
      final first = _unlisted.add(s.proId);
      if (!hasOwn) {
        _dropFor(s.proId, keepOwn: false);
        return true;
      }
      if (first) _dropFor(s.proId, keepOwn: true);
    } else if (_unlisted.contains(s.proId)) {
      // Republished (seen through the owner's channel, or a fresh fetch):
      // customers may follow it again.
      _unlisted.remove(s.proId);
    }
    _held[s.proId] = s;
    _onServerNow?.call(s.serverNow);
    if (t == null) return true;
    // Listeners refused while it was unlisted are still attached: they get
    // this snapshot below and a channel for the next ones.
    if (t.channel == null &&
        t.retry == null &&
        _rejoinTimer == null &&
        t.sinks.isNotEmpty) {
      _open(t);
    }
    for (final sink in [...t.sinks]) {
      if (s.listed || t.own.contains(sink)) sink.add(s);
    }
    return true;
  }

  void _queueFetch(String proId) {
    if (_suspended) return;
    _toFetch.add(proId);
    _fetchTimer ??= Timer(batchWindow, _flush);
  }

  void _flush() {
    _fetchTimer = null;
    final ids = [
      for (final id in _toFetch)
        if (_topics[id] case final t? when _mayFetch(t)) id,
    ];
    _toFetch.clear();
    final generation = _generation;
    for (var i = 0; i < ids.length; i += maxSnapshotIds) {
      final chunk = ids.sublist(
        i,
        i + maxSnapshotIds > ids.length ? ids.length : i + maxSnapshotIds,
      );
      unawaited(
        _fetch(chunk).then(
          (found) {
            if (generation != _generation) return;
            found.values.forEach(_apply);
            for (final id in chunk) {
              if (_unauthorized.contains(id) && !found.containsKey(id)) {
                _markGone(id);
              }
            }
          },
          onError: (Object e, StackTrace st) {
            // Shown as "Hors ligne" by the RPC health; the next
            // (re)subscribe or resume fetches again.
            developer.log(
              'live snapshots fetch failed',
              error: e,
              stackTrace: st,
            );
          },
        ),
      );
    }
  }

  void _recomputeConnected() {
    final next = !_topics.values.any((t) => t.isDown);
    if (next == _connected) return;
    _connected = next;
    if (!_connectedController.isClosed) _connectedController.add(next);
  }
}
