import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/time/clock_providers.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'live_fakes.dart';

class _MockRepo extends Mock implements LiveRepository {}

Account account({Space space = Space.men, AppRole role = AppRole.customer}) =>
    Account(
      id: 'u1',
      fullName: 'Lina',
      customerSpace: space,
      proSpace: role.isPro ? space : null,
      activeRole: role,
      roles: {AppRole.customer, role},
    );

class _FakeAccount extends AccountController {
  @override
  Future<Account?> build() async => account();
}

OwnerQueueRow row(int n) => OwnerQueueRow.fromJson({
  'entry_id': 'e$n',
  'ticket_no': n,
  'kind': 'walk_in',
  'label': null,
  'service_id': null,
  'duration_min': null,
  'state': 'waiting',
  'on_my_way_at': null,
  'called_at': null,
  'sort_at': '2026-11-20T10:00:00+00:00',
  'position': n,
});

MyTicket ticket({String space = 'men', String proId = 'p1'}) =>
    MyTicket.fromJson({
      'entry_id': 'e1',
      'pro_id': proId,
      'pro_space': space,
      'ticket_no': 3,
      'state': 'waiting',
      'end_reason': null,
      'position': 2,
      'wait_min': 20,
      'on_my_way_at': null,
      'called_at': null,
      'ended_at': null,
      'display_name': 'Karim',
      'avatar_path': null,
    });

/// A broadcast reaches a provider through a stream microtask, then
/// Riverpod's zero-delay refresh timer, then the async build: zero-length
/// pumps do not drain that chain, so each step advances 1 ms (well under
/// every LiveChannels delay).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  late _MockRepo repo;
  late FakeFactory factory;
  late StreamController<int> ticks;
  late StreamController<void> resumes;
  late DateTime clock;
  late Map<String, LiveSnapshot> server;

  setUp(() {
    repo = _MockRepo();
    factory = FakeFactory();
    ticks = StreamController<int>.broadcast();
    resumes = StreamController<void>.broadcast();
    clock = DateTime.utc(2026, 11, 20, 10);
    server = {};
    when(() => repo.snapshots(any())).thenAnswer(
      (i) async => {
        for (final id in i.positionalArguments[0] as List<String>)
          if (server[id] != null) id: server[id]!,
      },
    );
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        liveRepositoryProvider.overrideWithValue(repo),
        liveChannelFactoryProvider.overrideWithValue(factory.call),
        liveTickerProvider.overrideWith((ref) => ticks.stream),
        appResumesProvider.overrideWithValue(resumes.stream),
        utcClockProvider.overrideWithValue(() => clock),
        accountProvider.overrideWith(_FakeAccount.new),
      ],
    );
    return c;
  }

  // Fake time; the container is disposed inside the body so no timer
  // outlives the test.
  void providerTest(
    String name,
    Future<void> Function(WidgetTester t, ProviderContainer c) body,
  ) => testWidgets(name, (t) async {
    final c = make();
    await c.read(accountProvider.future);
    await body(t, c);
    c.dispose();
    await settle(t);
  });

  group('proLiveProvider', () {
    providerTest('the ticker flips open to closed with no message', (
      t,
      c,
    ) async {
      clock = DateTime.utc(2026, 11, 20, 19);
      c
          .read(liveChannelsProvider)
          .seed(
            LiveSnapshot.fromJson({
              ...live('p1', serverNow: '2026-11-20T19:00:00+00:00'),
              'status_age_from': '2026-11-20T18:55:00+00:00',
              'auto_close_at': '2026-11-20T19:30:00+00:00',
            }),
          );
      final sub = c.listen(proLiveProvider('p1'), (_, _) {});
      await settle(t);
      expect(sub.read().requireValue.status, LiveStatus.open);

      clock = DateTime.utc(2026, 11, 20, 19, 31);
      await settle(t);
      // Nothing re-derives before the tick.
      expect(sub.read().requireValue.status, LiveStatus.open);
      ticks.add(1);
      await settle(t);
      expect(sub.read().requireValue.status, LiveStatus.closed);
      expect(
        factory.channels.where((ch) => ch.topic == 'pro:p1'),
        hasLength(1),
      );
      sub.close();
    });

    providerTest('the owner view keeps an unpublished pro', (t, c) async {
      final own = c.listen(ownProLiveProvider('p1'), (_, _) {});
      final customer = c.listen(proLiveProvider('p1'), (_, _) {});
      await settle(t);
      factory.last('p1').send(live('p1', listed: false));
      await settle(t);
      expect(own.read().requireValue.snapshot.listed, isFalse);
      expect(customer.read().error, isA<LiveUnavailable>());
      own.close();
      customer.close();
    });

    providerTest('a refused channel makes the pro unavailable', (t, c) async {
      final sub = c.listen(proLiveProvider('p1'), (_, _) {});
      await settle(t);
      factory.last('p1').refuse();
      await settle(t);
      expect(sub.read().error, isA<LiveUnavailable>());
      // A refusal is not a disconnection.
      expect(c.read(liveConnectedProvider), isTrue);
      sub.close();
    });
  });

  group('ownerQueueProvider', () {
    providerTest('refetches only when queue_version changes', (t, c) async {
      when(() => repo.ownerQueue('p1')).thenAnswer((_) async => [row(1)]);
      final sub = c.listen(ownerQueueProvider('p1'), (_, _) {});
      await settle(t);
      expect(sub.read().requireValue.rows.single.ticketNo, 1);

      final ch = factory.last('p1');
      ch.send(live('p1', version: 3));
      await settle(t);
      clearInteractions(repo);

      // Status-only change: same version, later stamp.
      ch.send(
        live(
          'p1',
          version: 3,
          serverNow: '2026-11-20T10:01:00+00:00',
          status: 'on_break',
        ),
      );
      await settle(t);
      verifyNever(() => repo.ownerQueue(any()));

      when(() => repo.ownerQueue('p1'))
          .thenAnswer((_) async => [row(1), row(2)]);
      ch.send(live('p1', version: 4, serverNow: '2026-11-20T10:02:00+00:00'));
      await settle(t);
      verify(() => repo.ownerQueue('p1')).called(1);
      expect(sub.read().requireValue.rows, hasLength(2));
      sub.close();
    });

    providerTest('keeps working when its own pro is unpublished', (t, c) async {
      when(() => repo.ownerQueue('p1')).thenAnswer((_) async => [row(1)]);
      final sub = c.listen(ownerQueueProvider('p1'), (_, _) {});
      await settle(t);
      factory.last('p1').send(live('p1', version: 4, listed: false));
      await settle(t);
      expect(factory.last('p1').closed, isFalse);
      expect(c.read(ownLiveSnapshotProvider('p1')).value?.listed, isFalse);
      expect(sub.read().requireValue.rows, hasLength(1));
      sub.close();
    });

    providerTest('an action exposes its in-flight state and ignores taps', (
      t,
      c,
    ) async {
      when(() => repo.ownerQueue('p1')).thenAnswer((_) async => [row(1)]);
      final gate = Completer<List<OwnerQueueRow>>();
      when(() => repo.callNext('p1')).thenAnswer((_) => gate.future);
      final sub = c.listen(ownerQueueProvider('p1'), (_, _) {});
      await settle(t);

      final n = c.read(ownerQueueProvider('p1').notifier);
      final first = n.callNext();
      await settle(t);
      expect(sub.read().requireValue.inFlight, OwnerAction.callNext);
      expect(sub.read().requireValue.busy, isTrue);
      await n.callNext();
      await n.finish();
      verify(() => repo.callNext('p1')).called(1);
      verifyNever(() => repo.finish(any()));

      // A broadcast from the action itself rebuilds; still in flight.
      factory.last('p1').send(live('p1', version: 9));
      await settle(t);
      expect(sub.read().requireValue.inFlight, OwnerAction.callNext);

      gate.complete([row(2)]);
      await first;
      expect(sub.read().requireValue.inFlight, isNull);
      expect(sub.read().requireValue.rows.single.ticketNo, 2);
      sub.close();
    });

    providerTest('a failing action ends in-flight and rethrows', (t, c) async {
      when(() => repo.ownerQueue('p1')).thenAnswer((_) async => [row(1)]);
      when(() => repo.finish('p1'))
          .thenAnswer((_) async => throw const NothingServing());
      final sub = c.listen(ownerQueueProvider('p1'), (_, _) {});
      await settle(t);
      await expectLater(
        c.read(ownerQueueProvider('p1').notifier).finish(),
        throwsA(isA<NothingServing>()),
      );
      expect(sub.read().requireValue.inFlight, isNull);
      expect(sub.read().requireValue.rows.single.ticketNo, 1);
      sub.close();
    });

    providerTest('owner status writes run one at a time', (t, c) async {
      final gate = Completer<void>();
      when(() => repo.setStatus('p1', LiveStatus.open, breakUntil: null))
          .thenAnswer((_) => gate.future);
      final sub = c.listen(ownerLiveProvider('p1'), (_, _) {});
      final owner = c.read(ownerLiveProvider('p1').notifier);
      final first = owner.setStatus(LiveStatus.open);
      expect(sub.read(), OwnerLiveAction.status);
      await owner.extendAutoClose();
      verifyNever(() => repo.extendAutoClose(any()));
      gate.complete();
      await first;
      expect(sub.read(), isNull);
      sub.close();
    });

    providerTest('a failed owner write rethrows and reads as offline', (
      t,
      c,
    ) async {
      when(() => repo.extendAutoClose('p1'))
          .thenAnswer((_) async => throw const LiveNetworkFailure());
      final sub = c.listen(ownerLiveProvider('p1'), (_, _) {});
      await expectLater(
        c.read(ownerLiveProvider('p1').notifier).extendAutoClose(),
        throwsA(isA<LiveNetworkFailure>()),
      );
      expect(sub.read(), isNull);
      expect(c.read(liveRpcHealthProvider), isFalse);
      sub.close();
    });

    providerTest('unblock replaces the blocked list', (t, c) async {
      final a = BlockedCustomer(
        blockId: 'b1',
        ticketLabel: null,
        createdAt: DateTime.utc(2026, 11, 19),
      );
      final b = BlockedCustomer(
        blockId: 'b2',
        ticketLabel: 'Karim',
        createdAt: DateTime.utc(2026, 11, 19),
      );
      when(() => repo.blocked('p1')).thenAnswer((_) async => [a, b]);
      when(() => repo.unblock('p1', 'b1')).thenAnswer((_) async => [b]);
      final sub = c.listen(ownerBlockedProvider('p1'), (_, _) {});
      await settle(t);
      expect(sub.read().requireValue, hasLength(2));
      await c.read(ownerBlockedProvider('p1').notifier).unblock('b1');
      expect(sub.read().requireValue.single.blockId, 'b2');
      sub.close();
    });

    providerTest('a failing fetch is not retried automatically', (t, c) async {
      when(() => repo.ownerQueue('p1'))
          .thenAnswer((_) async => throw const LiveNetworkFailure());
      final sub = c.listen(ownerQueueProvider('p1'), (_, _) {});
      await t.pump(const Duration(seconds: 10));
      expect(sub.read().error, isA<LiveNetworkFailure>());
      verify(() => repo.ownerQueue('p1')).called(1);
      // The network failure reads as "Hors ligne".
      expect(c.read(liveConnectedProvider), isFalse);

      when(() => repo.ownerQueue('p1')).thenAnswer((_) async => [row(1)]);
      c.invalidate(ownerQueueProvider('p1'));
      await settle(t);
      expect(c.read(liveConnectedProvider), isTrue);
      sub.close();
    });
  });

  group('myTicketProvider', () {
    providerTest('refetches on its pro snapshots and on resume', (t, c) async {
      when(() => repo.myTicket()).thenAnswer((_) async => ticket());
      final sub = c.listen(myTicketProvider, (_, _) {});
      await settle(t);
      expect(sub.read().requireValue!.ticketNo, 3);
      final ch = factory.last('p1');
      ch.send(live('p1', version: 3));
      await settle(t);
      clearInteractions(repo);

      ch.send(live('p1', version: 4));
      await settle(t);
      verify(() => repo.myTicket()).called(1);

      resumes.add(null);
      await settle(t);
      verify(() => repo.myTicket()).called(1);
      sub.close();
    });

    providerTest('the first snapshot of its pro refetches once', (t, c) async {
      when(() => repo.myTicket()).thenAnswer((_) async => ticket());
      final sub = c.listen(myTicketProvider, (_, _) {});
      await settle(t);
      verify(() => repo.myTicket()).called(1);
      factory.last('p1').send(live('p1', version: 3));
      await settle(t);
      await t.pump(const Duration(seconds: 1));
      // Once: the rebuilt listener sees the same version and stays quiet.
      verify(() => repo.myTicket()).called(1);
      sub.close();
    });

    providerTest('a ticket of the other space is hidden', (t, c) async {
      when(() => repo.myTicket())
          .thenAnswer((_) async => ticket(space: 'women'));
      final sub = c.listen(myTicketProvider, (_, _) {});
      await settle(t);
      expect(sub.read().requireValue, isNull);
      expect(factory.channels, isEmpty);

      c.read(accountProvider.notifier).state = AsyncData(
        account(space: Space.women),
      );
      await settle(t);
      expect(sub.read().requireValue!.proId, 'p1');
      sub.close();
    });

    providerTest('a failing fetch is not retried automatically', (t, c) async {
      when(() => repo.myTicket())
          .thenAnswer((_) async => throw const LiveNetworkFailure());
      final sub = c.listen(myTicketProvider, (_, _) {});
      await t.pump(const Duration(seconds: 10));
      expect(sub.read().hasError, isTrue);
      verify(() => repo.myTicket()).called(1);
      sub.close();
    });
  });

  group('liveChannelsProvider', () {
    for (final change in {
      'space': account(space: Space.women),
      'role': account(role: AppRole.barber),
    }.entries) {
      providerTest('a ${change.key} change closes every channel', (t, c) async {
        final s = c.read(liveChannelsProvider).watch('p1').listen((_) {});
        final before = factory.last('p1');
        c.read(accountProvider.notifier).state = AsyncData(change.value);
        await settle(t);
        expect(before.closed, isTrue);
        await t.pump(const Duration(milliseconds: 300));
        expect(factory.last('p1'), isNot(same(before)));
        expect(factory.last('p1').closed, isFalse);
        stop(s);
      });
    }

    providerTest('sign-out closes every channel', (t, c) async {
      final s = c.read(liveChannelsProvider).watch('p1').listen((_) {});
      c.read(accountProvider.notifier).state = const AsyncData(null);
      await settle(t);
      expect(factory.last('p1').closed, isTrue);
      stop(s);
    });

    providerTest('signed out, nothing re-joins until the next account', (
      t,
      c,
    ) async {
      final s = c.read(liveChannelsProvider).watch('p1').listen((_) {});
      c.read(accountProvider.notifier).state = const AsyncData(null);
      await t.pump(const Duration(seconds: 1));
      expect(factory.open, isEmpty);
      resumes.add(null);
      await t.pump(const Duration(seconds: 1));
      verifyNever(() => repo.snapshots(any()));

      c.read(accountProvider.notifier).state = AsyncData(account());
      await t.pump(const Duration(milliseconds: 300));
      expect(factory.open.map((ch) => ch.topic), ['pro:p1']);
      stop(s);
    });

    providerTest('resume re-fetches the watched pros', (t, c) async {
      final s = c.read(liveChannelsProvider).watch('p1').listen((_) {});
      resumes.add(null);
      await t.pump(const Duration(milliseconds: 300));
      verify(() => repo.snapshots(['p1'])).called(1);
      stop(s);
    });

    providerTest('snapshots teach the server offset', (t, c) async {
      clock = DateTime.utc(2026, 11, 20, 9, 59, 30);
      c.read(liveChannelsProvider).seed(snapshot('p1'));
      expect(c.read(serverOffsetProvider), const Duration(seconds: 30));
      expect(c.read(serverNowProvider)(), DateTime.utc(2026, 11, 20, 10));
    });

    providerTest('connected goes false after 5 s of channel errors', (
      t,
      c,
    ) async {
      final sub = c.listen(liveConnectedProvider, (_, _) {});
      final s = c.read(liveChannelsProvider).watch('p1').listen((_) {});
      factory.last('p1').error();
      await t.pump(const Duration(seconds: 6));
      expect(sub.read(), isFalse);
      factory.last('p1').subscribed();
      await settle(t);
      expect(sub.read(), isTrue);
      stop(s);
      sub.close();
    });
  });
}
