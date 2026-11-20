import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_channels.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_fakes.dart';

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
    await t.pump(const Duration(seconds: 3));
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
    // A status-only change: live_version moves, queue_version does not.
    ch.send(
      live(
        'p1',
        version: 6,
        queueVersion: 5,
        serverNow: '2026-11-20T10:01:00+00:00',
        status: 'on_break',
      ),
    );
    await t.pump();
    expect(got.last.status, LiveStatus.onBreak);
    expect(serverTimes, hasLength(2));
    stop(a);
  });

  channelsTest('a fetch older than a broadcast never replaces it', (t) async {
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    final ch = factory.last('p1');
    // The fetch's transaction started before the status change committed:
    // same queue_version, a later server_now, but the older live_version.
    server['p1'] = snapshot(
      'p1',
      version: 5,
      queueVersion: 5,
      serverNow: '2026-11-20T10:00:02+00:00',
    );
    ch.subscribed();
    ch.send(
      live(
        'p1',
        version: 6,
        queueVersion: 5,
        serverNow: '2026-11-20T10:00:01+00:00',
        status: 'on_break',
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches, [
      ['p1'],
    ]);
    expect(got.map((s) => s.status), [LiveStatus.onBreak]);
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

  channelsTest('refresh: an answer from before closeAll is discarded', (
    t,
  ) async {
    final gate = Completer<Map<String, LiveSnapshot>>();
    channels.dispose();
    channels = LiveChannels(
      channelFactory: factory.call,
      fetch: (_) => gate.future,
    );
    final done = channels.refresh('p1');
    channels.closeAll();
    gate.complete({'p1': snapshot('p1')});
    await done;
    expect(channels.latest('p1'), isNull);
    await t.pump(const Duration(milliseconds: 300));
  });

  channelsTest('refresh brings back a pro last seen unlisted', (t) async {
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add, onError: (_) {});
    factory.last('p1').send(live('p1', version: 4, listed: false));
    await t.pump();
    server['p1'] = snapshot('p1', version: 5);
    await channels.refresh('p1');
    await t.pump();
    expect(got.map((s) => s.liveVersion), [5]);
    expect(fetches, [
      ['p1'],
    ]);
    stop(a);
  });

  channelsTest('retryNow rejoins failing channels and refetches', (t) async {
    final alive = <int>[];
    channels.dispose();
    channels = LiveChannels(
      channelFactory: factory.call,
      fetch: (ids) async => {
        for (final id in ids)
          if (server[id] != null) id: server[id]!,
      },
      onAlive: () => alive.add(1),
    );
    final a = channels.watch('p1').listen((_) {});
    final first = factory.last('p1')..error();
    channels.retryNow();
    final second = factory.last('p1');
    expect(second, isNot(same(first)));
    // No second join when the old retry timer would have fired.
    await t.pump(const Duration(seconds: 4));
    expect(factory.channels, hasLength(2));
    second.subscribed();
    expect(alive, [1]);
    second.send(live('p1', version: 9));
    expect(alive, [1, 1]);
    stop(a);
  });

  // realtime_client reports a socket closed by `disconnect()` to no channel,
  // and a bare `connect()` rejoins none (supabase_flutter's resume adds a
  // forceRejoin() of the joined channels after it; this covers the rest).
  channelsTest('a closed socket marks watched pros down after 5 s', (t) async {
    final a = channels.watch('p1').listen((_) {});
    factory.last('p1').subscribed();
    channels.socketClosed();
    await t.pump(const Duration(seconds: 4));
    expect(channels.connected, isTrue);
    await t.pump(const Duration(seconds: 2));
    expect(channels.connected, isFalse);
    stop(a);
  });

  channelsTest('a reopened socket joins every watched pro again', (t) async {
    server['p1'] = snapshot('p1');
    final got = <LiveSnapshot>[];
    final a = channels.watch('p1').listen(got.add);
    final b = channels.watch('p2').listen((_) {});
    factory.last('p1').subscribed();
    factory.last('p2').subscribed();
    await t.pump(const Duration(milliseconds: 300));
    final before = [factory.last('p1'), factory.last('p2')];

    channels.socketClosed();
    await t.pump(const Duration(seconds: 6));
    expect(channels.connected, isFalse);
    server['p1'] = snapshot('p1', version: 4);
    channels.socketOpened();
    expect(before.every((c) => c.closed), isTrue);
    expect(factory.open.map((c) => c.topic), ['pro:p1', 'pro:p2']);
    // The old channel's callbacks no longer count.
    before.first.error();
    factory.last('p1').subscribed();
    factory.last('p2').subscribed();
    expect(channels.connected, isTrue);
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.last, ['p1', 'p2']);
    expect(got.last.queueVersion, 4);
    await t.pump(const Duration(seconds: 6));
    expect(channels.connected, isTrue);
    stop(a);
    stop(b);
  });

  channelsTest('the first socket open rejoins nothing', (t) async {
    final a = channels.watch('p1').listen((_) {});
    channels.socketOpened();
    expect(factory.channels, hasLength(1));
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

  channelsTest('a join-reply error without Unauthorized rejoins', (t) async {
    final a = channels.watch('p1').listen((_) {});
    final first = factory.last('p1');
    // realtime_client schedules no rejoin for an error join reply.
    first.error(Exception('"ChannelRateLimitReached: Too many channels"'));
    expect(first.closed, isTrue);
    await t.pump(const Duration(seconds: 3));
    final second = factory.last('p1');
    expect(second, isNot(same(first)));
    expect(channels.connected, isTrue);
    second.subscribed();
    await t.pump(const Duration(seconds: 6));
    expect(channels.connected, isTrue);
    stop(a);
  });

  channelsTest('a refused pro stays refused after its listeners leave', (
    t,
  ) async {
    final a = channels.watch('p1').listen((_) {}, onError: (_) {});
    factory.last('p1').refuse();
    stop(a);
    await t.pump(const Duration(seconds: 20));
    final errors = <Object>[];
    final b = channels.watch('p1').listen((_) {}, onError: errors.add);
    await t.pump();
    expect(errors.single, isA<LiveUnavailable>());
    expect(factory.channels.where((c) => c.topic == 'pro:p1'), hasLength(1));
    stop(b);
  });

  channelsTest('an unlisted pro becomes unavailable to customers', (t) async {
    final errors = <Object>[];
    final a = channels.watch('p1').listen((_) {}, onError: errors.add);
    final ch = factory.last('p1');
    ch.send(live('p1'));
    await t.pump();
    ch.send(live('p1', version: 4, listed: false));
    await t.pump();
    expect(errors.single, isA<LiveUnavailable>());
    expect(ch.closed, isTrue);
    expect(channels.latest('p1'), isNull);
    stop(a);
    await t.pump(const Duration(seconds: 20));
    // Kept until the next closeAll, even with nobody listening meanwhile.
    final again = <Object>[];
    final b = channels.watch('p1').listen((_) {}, onError: again.add);
    await t.pump();
    expect(again.single, isA<LiveUnavailable>());
    expect(factory.channels, hasLength(1));
    stop(b);
    channels.closeAll();
    await t.pump(const Duration(milliseconds: 300));
    final c = channels.watch('p1').listen((_) {});
    expect(factory.channels, hasLength(2));
    stop(c);
  });

  channelsTest('a listed seed serves a refused listener and joins again', (
    t,
  ) async {
    final got = <LiveSnapshot>[];
    final errors = <Object>[];
    final a = channels.watch('p1').listen((_) {}, onError: (_) {});
    factory.last('p1').send(live('p1', version: 4, listed: false));
    await t.pump();
    // A listener that arrives while the pro is unlisted is refused...
    final b = channels.watch('p1').listen(got.add, onError: errors.add);
    await t.pump();
    expect(errors.single, isA<LiveUnavailable>());
    final before = factory.channels.length;

    // ...until a fresh listed snapshot says it is back (republished).
    channels.seed(snapshot('p1', version: 5));
    await t.pump();
    expect(got.single.queueVersion, 5);
    expect(factory.channels.length, before + 1);
    expect(factory.channels.last.closed, isFalse);
    stop(a);
    stop(b);
  });

  channelsTest('the owner keeps an unlisted pro', (t) async {
    final got = <LiveSnapshot>[];
    final errors = <Object>[];
    final a = channels
        .watch('p1', own: true)
        .listen(got.add, onError: errors.add);
    factory.last('p1').send(live('p1', listed: false));
    await t.pump();
    expect(errors, isEmpty);
    expect(got.single.listed, isFalse);
    expect(factory.last('p1').closed, isFalse);
    stop(a);
  });

  channelsTest('an unpublish during the linger does not lock the owner out', (
    t,
  ) async {
    final a = channels.watch('p1', own: true).listen((_) {});
    final first = factory.last('p1');
    first.send(live('p1'));
    await t.pump();
    // The dashboard unmounts (redirect to setup); the channel lingers.
    stop(a);
    await t.pump(const Duration(seconds: 1));
    first.send(live('p1', version: 4, listed: false));
    await t.pump();
    expect(first.closed, isTrue);

    // Back on the dashboard: the owner gets their pro again.
    server['p1'] = snapshot('p1', version: 4).copyWithListed(false);
    final got = <LiveSnapshot>[];
    final errors = <Object>[];
    final b = channels
        .watch('p1', own: true)
        .listen(got.add, onError: errors.add);
    final second = factory.last('p1');
    expect(second, isNot(same(first)));
    second.subscribed();
    await t.pump(const Duration(milliseconds: 300));
    expect(errors, isEmpty);
    expect(got.single.listed, isFalse);
    expect(fetches.last, ['p1']);

    // A customer view of the same pro is still unavailable.
    final customer = <Object>[];
    final c = channels.watch('p1').listen((_) {}, onError: customer.add);
    await t.pump();
    expect(customer.single, isA<LiveUnavailable>());
    stop(b);
    stop(c);
  });

  channelsTest('own and customer listeners split on an unpublish', (t) async {
    final own = <LiveSnapshot>[];
    final customer = <Object>[];
    final a = channels.watch('p1', own: true).listen(own.add);
    final b = channels.watch('p1').listen((_) {}, onError: customer.add);
    factory.last('p1').send(live('p1', listed: false));
    await t.pump();
    expect(own.single.listed, isFalse);
    expect(customer.single, isA<LiveUnavailable>());
    expect(factory.last('p1').closed, isFalse);
    // Fetches still serve the owner.
    channels.refreshAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(fetches.last, ['p1']);
    stop(a);
    stop(b);
  });

  channelsTest('Unauthorized applies to the owner too', (t) async {
    final errors = <Object>[];
    final a = channels
        .watch('p1', own: true)
        .listen((_) {}, onError: errors.add);
    factory.last('p1').refuse();
    await t.pump();
    expect(errors.single, isA<LiveUnavailable>());
    stop(a);
    final again = <Object>[];
    final b = channels
        .watch('p1', own: true)
        .listen((_) {}, onError: again.add);
    await t.pump();
    expect(again.single, isA<LiveUnavailable>());
    expect(factory.channels, hasLength(1));
    stop(b);
  });

  channelsTest('a topic removed after its linger forgets its snapshot', (
    t,
  ) async {
    final a = channels.watch('p1').listen((_) {});
    factory.last('p1').send(live('p1'));
    await t.pump();
    expect(channels.latest('p1'), isNotNull);
    stop(a);
    await t.pump(const Duration(seconds: 11));
    expect(channels.latest('p1'), isNull);
  });

  channelsTest('a lingering channel closed by the server is just dropped', (
    t,
  ) async {
    final a = channels.watch('p1').listen((_) {});
    stop(a);
    await t.pump();
    factory.last('p1').onStatus(RealtimeSubscribeStatus.closed, null);
    // Nobody is listening: no "Hors ligne", not even before the linger ends.
    await t.pump(const Duration(seconds: 6));
    expect(channels.connected, isTrue);
    await t.pump(const Duration(seconds: 20));
    expect(factory.channels, hasLength(1));
  });

  testWidgets('a lingering channel closed by the server frees its slot', (
    t,
  ) async {
    channels = make(maxChannels: 1);
    final a = channels.watch('a').listen((_) {});
    final b = channels.watch('b').listen((_) {});
    expect(factory.open.map((c) => c.topic), ['pro:a']);
    stop(a);
    await t.pump();
    factory.last('a').onStatus(RealtimeSubscribeStatus.closed, null);
    expect(factory.open.map((c) => c.topic), ['pro:b']);
    stop(b);
    channels.dispose();
  });

  channelsTest('signed out: nothing joins until closeAll', (t) async {
    channels.closeAll(rejoin: false);
    final a = channels.watch('p1').listen((_) {});
    channels.refreshAll();
    await t.pump(const Duration(seconds: 1));
    expect(factory.channels, isEmpty);
    expect(fetches, isEmpty);
    channels.closeAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(factory.open.map((c) => c.topic), ['pro:p1']);
    stop(a);
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
