import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/time/clock_providers.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/live_fakes.dart';
import '../today/today_harness.dart' show FakeConnected, ownSnapshot, testNow;

export '../../data/live_fakes.dart' show FakeFactory, stop;
export '../today/today_harness.dart' show FakeConnected, testNow;

/// The live `live` object for a customer, at [testNow] by default: open
/// until 19:30 Algiers time, last action at 09:55 UTC, 3 waiting, ~40 min.
Map<String, Object?> custLive(
  String proId, {
  String status = 'open',
  DateTime? breakUntil,
  DateTime? autoCloseAt,
  DateTime? ageFrom,
  String mode = 'open',
  String? joinBlock,
  int? waiting = 3,
  int? waitMin = 40,
  bool listed = true,
  int version = 3,
  DateTime? serverNow,
}) => {
  'pro_id': proId,
  'status': status,
  'break_until': breakUntil?.toIso8601String(),
  'auto_close_at': (autoCloseAt ?? DateTime.utc(2026, 11, 20, 18, 30))
      .toIso8601String(),
  'status_age_from': (ageFrom ?? DateTime.utc(2026, 11, 20, 9, 55))
      .toIso8601String(),
  'queue_mode': mode,
  'listed': listed,
  'join_block': joinBlock,
  'waiting_count': waiting,
  'wait_min': waitMin,
  'serving_called_at': null,
  'serving_duration_min': null,
  'ahead_minutes': waitMin ?? 0,
  'queue_version': version,
  'live_version': version,
  'server_now': (serverNow ?? testNow).toIso8601String(),
};

LiveSnapshot custSnap(
  String proId, {
  String status = 'open',
  DateTime? breakUntil,
  DateTime? autoCloseAt,
  DateTime? ageFrom,
  String mode = 'open',
  String? joinBlock,
  int? waiting = 3,
  int? waitMin = 40,
  bool listed = true,
  int version = 3,
  DateTime? serverNow,
}) => LiveSnapshot.fromJson(
  custLive(
    proId,
    status: status,
    breakUntil: breakUntil,
    autoCloseAt: autoCloseAt,
    ageFrom: ageFrom,
    mode: mode,
    joinBlock: joinBlock,
    waiting: waiting,
    waitMin: waitMin,
    listed: listed,
    version: version,
    serverNow: serverNow,
  ),
);

/// On break, back at 11:30 Algiers time (10:30 UTC).
LiveSnapshot breakSnap(String proId) => custSnap(
  proId,
  status: 'on_break',
  breakUntil: DateTime.utc(2026, 11, 20, 10, 30),
  joinBlock: 'on_break',
  waiting: 2,
  waitMin: 25,
);

LiveSnapshot closedSnap(String proId) =>
    custSnap(proId, status: 'closed', joinBlock: 'closed', waiting: 0);

MyTicket ticketFor({
  String proId = 'p1',
  String space = 'men',
  String state = 'waiting',
  String? endReason,
  int? position = 3,
  int? waitMin = 25,
  bool onMyWay = false,
  String name = 'Amine Benali',
}) => MyTicket.fromJson({
  'entry_id': 'e1',
  'pro_id': proId,
  'pro_space': space,
  'ticket_no': 7,
  'state': state,
  'end_reason': endReason,
  'position': state == 'waiting' ? position : null,
  'wait_min': state == 'waiting' ? waitMin : null,
  'on_my_way_at': onMyWay ? '2026-11-20T09:58:00+00:00' : null,
  'called_at': state == 'serving' ? '2026-11-20T09:59:00+00:00' : null,
  'ended_at': state == 'waiting' || state == 'serving'
      ? null
      : '2026-11-20T09:59:00+00:00',
  'display_name': name,
  'avatar_path': null,
});

/// The customer side of the live backend, in memory.
class CustomerLiveRepository extends Fake implements LiveRepository {
  /// What `pro_live_snapshots` answers, by pro id.
  final server = <String, LiveSnapshot>{};
  final snapshotCalls = <List<String>>[];

  /// What `my_ticket` answers.
  MyTicket? ticket;

  /// When set, the next joins throw it.
  LiveFailure? joinFailure;

  /// The ticket a successful join returns (and `my_ticket` answers after).
  MyTicket? joinResult;
  final joins = <(String, String)>[];
  final onMyWays = <String>[];
  final leaves = <String>[];
  var ticketCalls = 0;

  @override
  Future<Map<String, LiveSnapshot>> snapshots(List<String> proIds) async {
    snapshotCalls.add(proIds);
    return {for (final id in proIds) id: ?server[id]};
  }

  @override
  Future<MyTicket?> myTicket() async {
    ticketCalls++;
    return ticket;
  }

  @override
  Future<MyTicket> joinQueue(String proId, String serviceId) async {
    joins.add((proId, serviceId));
    final f = joinFailure;
    if (f != null) throw f;
    return ticket = joinResult ?? ticketFor(proId: proId);
  }

  @override
  Future<MyTicket> onMyWay(String entryId) async {
    onMyWays.add(entryId);
    final t = ticket!;
    return ticket = ticketFor(
      proId: t.proId,
      space: t.proSpace,
      position: t.position,
      waitMin: t.waitMin,
      onMyWay: true,
      name: t.displayName,
    );
  }

  @override
  Future<MyTicket> leaveQueue(String entryId) async {
    leaves.add(entryId);
    final t = ticket!;
    return ticket = ticketFor(
      proId: t.proId,
      space: t.proSpace,
      state: 'cancelled',
      endReason: 'left',
      name: t.displayName,
    );
  }

  @override
  Future<List<OwnerQueueRow>> ownerQueue(String proId) async => const [];

  @override
  Future<List<BlockedCustomer>> blocked(String proId) async => const [];
}

/// A device clock the test moves.
class TestClock {
  DateTime now = testNow;
}

/// The live backend a customer screen talks to: the real [LiveChannels]
/// over fake channels, a fake repository, a clock and a ticker the test
/// drives. The owner's own snapshots come from [own].
class CustomerLive {
  final repo = CustomerLiveRepository();
  final factory = FakeFactory();
  final ticks = StreamController<int>.broadcast();
  final clock = TestClock();

  /// The owner's own pro (Today tab, preview), by pro id.
  LiveSnapshot Function(String proId) own = (id) => ownSnapshot(proId: id);

  List<Override> overrides({bool connected = true}) => [
    liveRepositoryProvider.overrideWithValue(repo),
    liveChannelFactoryProvider.overrideWithValue(factory.call),
    liveTickerProvider.overrideWith((ref) => ticks.stream),
    appResumesProvider.overrideWithValue(const Stream<void>.empty()),
    utcClockProvider.overrideWithValue(() => clock.now),
    liveConnectedProvider.overrideWith(() => FakeConnected(connected)),
    ownLiveSnapshotProvider.overrideWith(
      (ref, proId) => Stream.value(own(proId)),
    ),
  ];

  /// Moves the clock and lets the 30 s ticker fire once, with no message.
  void advanceTo(DateTime t) {
    clock.now = t;
    ticks.add(0);
  }

  /// A broadcast on [proId]'s channel.
  void broadcast(String proId, Map<String, Object?> live) =>
      factory.last(proId).send(live);

  void dispose() => unawaited(ticks.close());
}

/// Live state flows through streams, Riverpod's refresh timer and async
/// builds: steps time so every hop lands.
Future<void> settleLive(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts the screen and lets the channels' 10 s linger run out, so no
/// timer outlives the test.
Future<void> unmountLive(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 11));
}

class _CustomerAccount extends AccountController {
  _CustomerAccount(this.account);

  final Account account;

  @override
  Future<Account?> build() async => account;
}

Account liveCustomer({Space space = Space.men}) => Account(
  id: 'u1',
  fullName: 'Lina Haddad',
  customerSpace: space,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer},
);

/// For widget tests without the router: a signed-in customer.
Override customerAccountOverride([Account? account]) => accountProvider
    .overrideWith(() => _CustomerAccount(account ?? liveCustomer()));
