import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_channels.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_models_test.dart' show snap;

/// One fake private channel: the test drives its status and broadcasts.
class FakeChannel implements LiveChannel {
  FakeChannel(this.topic, this.onBroadcast, this.onStatus);

  final String topic;
  final LiveBroadcastHandler onBroadcast;
  final LiveStatusHandler onStatus;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  void subscribed() => onStatus(RealtimeSubscribeStatus.subscribed, null);

  void error([Object? e]) =>
      onStatus(RealtimeSubscribeStatus.channelError, e ?? Exception('down'));

  void refuse() => onStatus(
    RealtimeSubscribeStatus.channelError,
    Exception(
      'Unauthorized: You do not have permissions to read from this '
      'Channel topic: $topic',
    ),
  );

  /// A broadcast exactly as realtime_client hands it over (spike b).
  void send(Map<String, Object?> live) => onBroadcast({
    'type': 'broadcast',
    'event': 'live',
    'payload': {...live, 'id': 'message-id'},
    'meta': {'id': 'message-id'},
  });
}

class FakeFactory {
  final channels = <FakeChannel>[];

  List<FakeChannel> get open => [
    for (final c in channels)
      if (!c.closed) c,
  ];

  FakeChannel last(String proId) =>
      channels.lastWhere((c) => c.topic == 'pro:$proId');

  LiveChannel call(
    String topic,
    LiveBroadcastHandler onBroadcast,
    LiveStatusHandler onStatus,
  ) {
    final c = FakeChannel(topic, onBroadcast, onStatus);
    channels.add(c);
    return c;
  }
}

Map<String, Object?> live(
  String proId, {
  int version = 3,
  String serverNow = '2026-11-20T10:00:00+00:00',
  String status = 'open',
}) => {
  ...snap(version: version, serverNow: serverNow),
  'pro_id': proId,
  'status': status,
};

LiveSnapshot snapshot(
  String proId, {
  int version = 3,
  String serverNow = '2026-11-20T10:00:00+00:00',
  String status = 'open',
}) => LiveSnapshot.fromJson(
  live(proId, version: version, serverNow: serverNow, status: status),
);

/// Not awaited: inside testWidgets, awaiting a cancel resumes outside the
/// fake-async zone and the next pump never returns.
void stop(StreamSubscription<Object?> s) => unawaited(s.cancel());

void main() {
  late FakeFactory factory;
  late List<List<String>> fetches;
  late Map<String, LiveSnapshot> server;
  late LiveChannels channels;
  late List<DateTime> serverTimes;

  LiveChannels make({int maxChannels = 80}) => LiveChannels(
    channelFactory: factory.call,
    fetch: (ids) async {
      fetches.add(ids);
      return {
        for (final id in ids)
          if (server[id] != null) id: server[id]!,
      };
    },
    onServerNow: serverTimes.add,
    maxChannels: maxChannels,
  );

  setUp(() {
    factory = FakeFactory();
    fetches = [];
    server = {};
    serverTimes = [];
  });

  // Every test runs on fake time (testWidgets) and disposes the channels
  // before it ends, so no timer outlives it.
  void channelsTest(String name, Future<void> Function(WidgetTester t) body) =>
      testWidgets(name, (t) async {
        channels = make();
        await body(t);
        channels.dispose();
      });

  channelsTest('two listeners share one private channel', (t) async {
    final a = channels.watch('p1').listen((_) {});
    final b = channels.watch('p1').listen((_) {});
    expect(factory.channels.map((c) => c.topic), ['pro:p1']);
    stop(a);
    stop(b);
  });

  channelsTest('an unlistened channel lingers 10 s, then closes', (t) async {
    final a = channels.watch('p1').listen((_) {});
    stop(a);
    await t.pump(const Duration(seconds: 9));
    expect(factory.last('p1').closed, isFalse);
    // A listener coming back within the linger keeps the same channel.
    final b = channels.watch('p1').listen((_) {});
    stop(b);
    await t.pump(const Duration(seconds: 9));
    expect(factory.channels, hasLength(1));
    expect(factory.last('p1').closed, isFalse);
    await t.pump(const Duration(seconds: 2));
    expect(factory.last('p1').closed, isTrue);
  });

  channelsTest('(re)subscribes trigger one batched re-fetch', (t) async {
    server['p1'] = snapshot('p1');
    server['p2'] = snapshot('p2');
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    final b = channels.watch('p2').listen((_) {});
    factory.last('p1').subscribed();
    factory.last('p2').subscribed();
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches, [
      ['p1', 'p2'],
    ]);
    expect(got, [server['p1']]);

    // The socket drops and comes back: a fresh fetch, never an old message.
    factory.last('p1').error();
    server['p1'] = snapshot('p1', version: 4);
    factory.last('p1').subscribed();
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.last, ['p1']);
    expect(got.last.queueVersion, 4);
    stop(a);
    stop(b);
  });

  channelsTest('fetches are chunked at 60 ids', (t) async {
    final subs = [
      for (var i = 0; i < 61; i++) channels.watch('p$i').listen((_) {}),
    ];
    for (final c in factory.channels) {
      c.subscribed();
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.map((f) => f.length), [60, 1]);
    for (final s in subs) {
      stop(s);
    }
  });

  channelsTest('an older broadcast is ignored', (t) async {
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    final ch = factory.last('p1');
    ch.send(live('p1', version: 5));
    await t.pump();
    ch.send(live('p1', version: 4, serverNow: '2026-11-20T10:05:00+00:00'));
    // Same version, same stamp: a duplicate.
    ch.send(live('p1', version: 5));
    await t.pump();
    expect(got.map((s) => s.queueVersion), [5]);
    // Same version, later stamp: a status-only change.
    ch.send(
      live(
        'p1',
        version: 5,
        serverNow: '2026-11-20T10:01:00+00:00',
        status: 'on_break',
      ),
    );
    await t.pump();
    expect(got.last.status, LiveStatus.onBreak);
    expect(serverTimes, hasLength(2));
    stop(a);
  });

  channelsTest('a later listener gets the held snapshot at once', (t) async {
    channels.seed(snapshot('p1'));
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    await t.pump();
    expect(got, [snapshot('p1')]);
    stop(a);
  });

  channelsTest(
    'closeAll closes every channel and re-joins only the listeners left',
    (t) async {
      final got = <LiveSnapshot>[];
      final menCard = channels.watch('men').listen((_) {});
      final own = channels.watch('own').listen(got.add);
      final lingering = channels.watch('gone').listen((_) {});
      stop(lingering);
      channels.seed(snapshot('own'));
      await t.pump();
      expect(got, [snapshot('own')]);
      got.clear();
      final before = [...factory.channels];

      channels.closeAll();
      expect(before.every((c) => c.closed), isTrue);
      // The old space's card goes away while the new space settles.
      stop(menCard);
      await t.pump(const Duration(milliseconds: 300));

      expect(factory.open.map((c) => c.topic), ['pro:own']);
      // The old space's snapshot is not served again.
      expect(channels.latest('own'), isNull);
      // A broadcast on a closed channel is dropped.
      before.firstWhere((c) => c.topic == 'pro:own').send(live('own'));
      await t.pump();
      expect(got, isEmpty);
      stop(own);
    },
  );

  channelsTest('a fetch from before closeAll is discarded', (t) async {
    final gate = Completer<Map<String, LiveSnapshot>>();
    channels.dispose();
    channels = LiveChannels(
      channelFactory: factory.call,
      fetch: (_) => gate.future,
    );
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    factory.last('p1').subscribed();
    await t.pump(const Duration(milliseconds: 300));
    channels.closeAll();
    gate.complete({'p1': snapshot('p1')});
    await t.pump();
    expect(got, isEmpty);
    expect(channels.latest('p1'), isNull);
    stop(a);
  });

  channelsTest('a channel error marks disconnected after 5 s', (t) async {
    final flips = <bool>[];
    final s = channels.connectedChanges.listen(flips.add);
    final a = channels.watch('p1').listen((_) {});
    factory.last('p1').subscribed();
    expect(channels.connected, isTrue);
    factory.last('p1').error();
    await t.pump(const Duration(seconds: 4));
    expect(channels.connected, isTrue);
    await t.pump(const Duration(seconds: 2));
    expect(channels.connected, isFalse);
    factory.last('p1').subscribed();
    expect(channels.connected, isTrue);
    await t.pump();
    expect(flips, [false, true]);
    // A blip shorter than 5 s never shows.
    factory.last('p1').error();
    await t.pump(const Duration(seconds: 3));
    factory.last('p1').subscribed();
    await t.pump(const Duration(seconds: 5));
    expect(flips, [false, true]);
    stop(a);
    stop(s);
  });

  channelsTest('an Unauthorized refusal is terminal for that pro only', (
    t,
  ) async {
    channels.seed(snapshot('p1'));
    final errors = <Object>[];
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add, onError: errors.add);
    final b = channels.watch('p2').listen((_) {});
    factory.last('p2').subscribed();
    // The refusal lands ~5 s after the join; nothing waited for it.
    await t.pump(const Duration(seconds: 5));
    factory.last('p1').refuse();
    await t.pump(const Duration(seconds: 10));

    expect(errors.single, isA<LiveUnavailable>());
    expect(factory.last('p1').closed, isTrue);
    expect(factory.channels.where((c) => c.topic == 'pro:p1'), hasLength(1));
    expect(channels.connected, isTrue);
    expect(channels.latest('p1'), isNull);
    // A new watcher learns it at once, without another join.
    final late = <Object>[];
    final c = channels.watch('p1').listen((_) {}, onError: late.add);
    await t.pump();
    expect(late.single, isA<LiveUnavailable>());
    expect(factory.channels.where((c) => c.topic == 'pro:p1'), hasLength(1));
    // A space change gives it a new chance.
    channels.closeAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(factory.open.map((c) => c.topic), containsAll(['pro:p1']));
    for (final s in [a, b, c]) {
      stop(s);
    }
  });

  channelsTest('resume re-fetches every watched pro', (t) async {
    final a = channels.watch('p1').listen((_) {});
    final b = channels.watch('p2').listen((_) {});
    channels.refreshAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.single, unorderedEquals(['p1', 'p2']));
    stop(a);
    stop(b);
  });

  testWidgets('at the cap, lingering channels go first, then fetch-only', (
    t,
  ) async {
    channels = make(maxChannels: 3);
    final subs = [
      for (final id in ['a', 'b', 'c']) channels.watch(id).listen((_) {}),
    ];
    stop(subs[0]); // 'a' lingers.
    final d = channels.watch('d').listen((_) {});
    expect(factory.last('a').closed, isTrue);
    expect(factory.open.map((c) => c.topic), ['pro:b', 'pro:c', 'pro:d']);

    // No lingering channel left: 'e' is served by fetches only.
    server['e'] = snapshot('e');
    final got = <LiveSnapshot>[];
    final e = channels.watch('e').listen(got.add);
    await t.pump(const Duration(milliseconds: 300));
    expect(factory.channels.where((c) => c.topic == 'pro:e'), isEmpty);
    expect(fetches.last, ['e']);
    expect(got, [server['e']]);
    channels.refreshAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.last, contains('e'));

    // A freed slot goes to the fetch-only pro.
    stop(d);
    await t.pump(const Duration(seconds: 11));
    expect(factory.open.map((c) => c.topic), contains('pro:e'));
    for (final s in [...subs.skip(1), e]) {
      stop(s);
    }
    channels.dispose();
  });
}
