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
/// * A snapshot older than the one held (`queue_version`, then `server_now`)
///   is dropped.
/// * At most [maxChannels] channels (the server allows 100 per connection):
///   past it, lingering channels close first, then new pros are served by
///   fetches only until a slot frees. A fetch-only pro refreshes on attach
///   and on resume only: it gets no message in between.
/// * `Unauthorized` is final for that pro until [closeAll], for everyone
///   ([LiveUnavailable], no channel, no retry). A snapshot saying
///   `listed: false` does the same for customers only: the owner's listeners
///   ([watch] with `own`) keep receiving and fetching their pro. Neither
///   counts as a disconnection.
/// * Any other failure closes the channel and joins a new one after
///   [retryAfter]; [connected] turns false once a watched pro has been
///   failing for [downAfter].
class LiveChannels {
  LiveChannels({
    required LiveChannelFactory channelFactory,
    required this._fetch,
    this._onServerNow,
    this.linger = const Duration(seconds: 10),
    this.batchWindow = const Duration(milliseconds: 250),
    this.downAfter = const Duration(seconds: 5),
    this.retryAfter = const Duration(seconds: 3),
    this.maxChannels = 80,
  }) : _factory = channelFactory;

  final LiveChannelFactory _factory;
  final LiveSnapshotFetcher _fetch;
  final void Function(DateTime serverNow)? _onServerNow;
  final Duration linger;
  final Duration batchWindow;
  final Duration downAfter;
  final Duration retryAfter;
  final int maxChannels;

  final _topics = <String, _Topic>{};
  final _held = <String, LiveSnapshot>{};

  // Both outlive their topics (a returning listener must not wait ~5 s for
  // the same refusal) and are cleared by closeAll only.
  /// Refused at join: for everyone.
  final _unauthorized = <String>{};

  /// Unpublished: for customers; the owner's listeners bypass it.
  final _unlisted = <String>{};
  final _toFetch = <String>{};
  Timer? _fetchTimer;
  Timer? _rejoinTimer;

  // Bumped by closeAll: a fetch answered for the previous space is dropped.
  var _generation = 0;
  var _disposed = false;

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

  /// Re-fetches every watched pro (app resume).
  void refreshAll() {
    for (final t in _topics.values) {
      if (_mayServe(t)) _queueFetch(t.proId);
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
    if (_unauthorized.contains(proId) || (!own && _unlisted.contains(proId))) {
      sink.addError(const LiveUnavailable());
      return;
    }
    final held = _held[proId];
    if (held != null) sink.add(held);
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
    if (!_mayServe(t)) return;
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
        _queueFetch(t.proId);
      case RealtimeSubscribeStatus.channelError
          when '$error'.contains('Unauthorized'):
        _unauthorized.add(t.proId);
        _dropFor(t.proId, keepOwn: false);
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

  /// Whether this topic may join and fetch: never when refused at join,
  /// and when unlisted only for the owner's listeners.
  bool _mayServe(_Topic t) =>
      !_unauthorized.contains(t.proId) &&
      (!_unlisted.contains(t.proId) || t.own.isNotEmpty);

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
      if (s.proId == t.proId) _apply(s);
    } on Object catch (e, st) {
      // A malformed message must not kill the channel; the next fetch heals.
      developer.log('live broadcast dropped', error: e, stackTrace: st);
    }
  }

  void _apply(LiveSnapshot s) {
    if (_disposed || _unauthorized.contains(s.proId)) return;
    final held = _held[s.proId];
    if (held != null && !s.isNewerThan(held)) return;
    final t = _topics[s.proId];
    final hasOwn = t != null && t.own.isNotEmpty;
    if (!s.listed) {
      final first = _unlisted.add(s.proId);
      if (!hasOwn) {
        _dropFor(s.proId, keepOwn: false);
        return;
      }
      if (first) _dropFor(s.proId, keepOwn: true);
    } else if (_unlisted.contains(s.proId)) {
      // Republished, seen through the owner's channel: customers may join
      // again (they re-watch to get it).
      _unlisted.remove(s.proId);
    }
    _held[s.proId] = s;
    _onServerNow?.call(s.serverNow);
    if (t == null) return;
    for (final sink in [...t.sinks]) {
      if (s.listed || t.own.contains(sink)) sink.add(s);
    }
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
        if (_topics[id] case final t? when _mayServe(t)) id,
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
