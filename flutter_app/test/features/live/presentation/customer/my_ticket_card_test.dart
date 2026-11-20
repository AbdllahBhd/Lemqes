import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../../explore/presentation/explore_harness.dart';
import 'customer_live_harness.dart';

final _fr = AppLocalizationsFr();

/// Explore with [ticket] held by the customer (in [space]).
Future<ExploreHarness> _explore(
  WidgetTester tester,
  MyTicket? ticket, {
  Space space = Space.men,
  Locale locale = const Locale('fr'),
  double textScale = 1,
}) {
  final live = CustomerLive()..repo.ticket = ticket;
  return pumpExplore(
    tester,
    account: customer(space: space),
    explore: FakeExploreRepository(cards: threeLiveCards()),
    live: live,
    locale: locale,
    textScale: textScale,
  );
}

Finder _inCard(Finder f) =>
    find.descendant(of: find.byKey(const Key('ticketCard')), matching: f);

void main() {
  setUpAll(registerHarnessFallbacks);

  testWidgets('waiting: place in gold, wait, pro, on my way and leave', (
    tester,
  ) async {
    await _explore(tester, ticketFor());

    expect(_inCard(find.text(_fr.ticketTitle)), findsOneWidget);
    expect(_inCard(find.text('Vous êtes 3e · ~25 min')), findsOneWidget);
    expect(_inCard(find.text('3e')), findsOneWidget);
    expect(_inCard(find.text('chez \u2068Amine Benali\u2069')), findsOneWidget);
    expect(_inCard(find.byKey(const Key('ticketOnMyWay'))), findsOneWidget);
    expect(_inCard(find.byKey(const Key('ticketLeave'))), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('first place agrees with the space', (tester) async {
    await _explore(
      tester,
      ticketFor(position: 1, space: 'women'),
      space: Space.women,
    );
    expect(_inCard(find.text('1re')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('serving: "C’est votre tour", no actions', (tester) async {
    await _explore(tester, ticketFor(state: 'serving'));

    expect(_inCard(find.text(_fr.ticketYourTurn)), findsOneWidget);
    expect(find.byKey(const Key('ticketOnMyWay')), findsNothing);
    expect(find.byKey(const Key('ticketLeave')), findsNothing);
    await unmountLive(tester);
  });

  final ended = <(String, String?, String)>[
    ('absent', null, _fr.ticketAbsent),
    ('cancelled', 'cleared', 'File fermée par le barbier'),
    ('cancelled', 'end_of_day', 'File fermée par le barbier'),
    ('cancelled', 'left', _fr.ticketLeft),
    ('served', null, _fr.ticketServed),
    ('removed', 'blocked', _fr.ticketEnded),
  ];
  for (final (state, reason, words) in ended) {
    testWidgets('ended $state/$reason reads "$words"', (tester) async {
      await _explore(tester, ticketFor(state: state, endReason: reason));

      expect(_inCard(find.text(words)), findsOneWidget);
      expect(find.byKey(const Key('ticketOnMyWay')), findsNothing);
      expect(find.byKey(const Key('ticketLeave')), findsNothing);
      await unmountLive(tester);
    });
  }

  testWidgets('a ticket from the other space never shows', (tester) async {
    final h = await _explore(tester, ticketFor(space: 'women'));

    expect(find.byKey(const Key('ticketCard')), findsNothing);
    expect(h.live.repo.ticketCalls, greaterThan(0));
    await unmountLive(tester);
  });

  testWidgets('no ticket, no card', (tester) async {
    await _explore(tester, null);
    expect(find.byKey(const Key('ticketCard')), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('"Je suis en route" tells the pro, then says it is noted', (
    tester,
  ) async {
    final h = await _explore(tester, ticketFor());
    await tester.tap(find.byKey(const Key('ticketOnMyWay')));
    await settleLive(tester);

    expect(h.live.repo.onMyWays, ['e1']);
    expect(_inCard(find.text(_fr.ticketOnMyWayDone('men'))), findsOneWidget);
    expect(find.byKey(const Key('ticketOnMyWay')), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('leaving asks first; cancel keeps the place', (tester) async {
    final h = await _explore(tester, ticketFor());
    await tester.tap(find.byKey(const Key('ticketLeave')));
    await settleLive(tester);
    expect(find.text(_fr.ticketLeaveTitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmCancel')));
    await settleLive(tester);
    expect(h.live.repo.leaves, isEmpty);
    expect(_inCard(find.text('Vous êtes 3e · ~25 min')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ticketLeave')));
    await settleLive(tester);
    await tester.tap(find.byKey(const Key('confirmAction')));
    await settleLive(tester);
    expect(h.live.repo.leaves, ['e1']);
    expect(_inCard(find.text(_fr.ticketLeft)), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('screen readers hear the new place, once, when it changes', (
    tester,
  ) async {
    final h = await _explore(tester, ticketFor());
    expect(tester.takeAnnouncements(), isEmpty);

    // The queue moves: the pro's broadcast makes the ticket refetch.
    h.live.repo.ticket = ticketFor(position: 2, waitMin: 15);
    h.live.broadcast('p1', custLive('p1', version: 4));
    await settleLive(tester);

    expect(_inCard(find.text('Vous êtes 2e · ~15 min')), findsOneWidget);
    final said = tester.takeAnnouncements();
    expect(said.map((a) => a.message), ['Vous êtes 2e']);

    // A status-only message or a rebuild with the same place says nothing.
    h.live.broadcast('p1', custLive('p1', version: 5));
    await settleLive(tester);
    h.live.advanceTo(DateTime.utc(2026, 11, 20, 10, 1));
    await settleLive(tester);
    expect(tester.takeAnnouncements(), isEmpty);
    await unmountLive(tester);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await _explore(
      tester,
      ticketFor(),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await settleLive(tester);
      expect(tester.takeException(), isNull);
    }
    await unmountLive(tester);
  });

  testWidgets('the turn is announced once when it comes', (tester) async {
    final h = await _explore(tester, ticketFor());
    tester.takeAnnouncements();

    h.live.repo.ticket = ticketFor(state: 'serving');
    h.live.broadcast('p1', custLive('p1', version: 4));
    await settleLive(tester);
    expect(tester.takeAnnouncements().map((a) => a.message), [
      _fr.ticketYourTurn,
    ]);

    h.live.broadcast('p1', custLive('p1', version: 5));
    await settleLive(tester);
    expect(tester.takeAnnouncements(), isEmpty);
    await unmountLive(tester);
  });

  // Finish review: "3 en attente · ~70 min" over "Vous êtes 3e · ~40 min"
  // gave two waits in one card; the ticket's is the customer's.
  testWidgets('holding a place, the profile shows one wait: the ticket\'s', (
    tester,
  ) async {
    final live = CustomerLive()
      ..repo.ticket = ticketFor(proId: proUuid)
      ..repo.server[proUuid] = custSnap(proUuid);
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeLiveCards()),
      pros: PublicProRepository(
        listed: {proUuid: publicBarber()},
        phones: {proUuid: '+213550123456'},
      ),
      live: live,
    );
    unawaited(h.router.push('/pro/$proUuid'));
    await settleLive(tester);
    final block = find.byKey(const Key('liveBlock'));
    final line = find.descendant(
      of: block,
      matching: find.byKey(const Key('liveQueueLine')),
    );
    expect(tester.widget<Text>(line).data, isNot(contains('min')));
    expect(
      find.descendant(of: block, matching: find.textContaining('~25 min')),
      findsOneWidget,
    );
    await unmountLive(tester);
  });

  testWidgets('with the profile pushed over Explore, one announcement', (
    tester,
  ) async {
    final live = CustomerLive()
      ..repo.ticket = ticketFor(proId: proUuid)
      ..repo.server[proUuid] = custSnap(proUuid);
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeLiveCards()),
      pros: PublicProRepository(
        listed: {proUuid: publicBarber()},
        phones: {proUuid: '+213550123456'},
      ),
      live: live,
    );
    unawaited(h.router.push('/pro/$proUuid'));
    await settleLive(tester);
    expect(find.byKey(const Key('liveBlock')), findsOneWidget);
    tester.takeAnnouncements();

    live.repo.ticket = ticketFor(proId: proUuid, position: 2, waitMin: 15);
    live.broadcast(proUuid, custLive(proUuid, version: 4));
    await settleLive(tester);
    expect(tester.takeAnnouncements().map((a) => a.message), ['Vous êtes 2e']);
    await unmountLive(tester);
  });

  test('Arabic: the card title is not the turn', () {
    final ar = AppLocalizationsAr();
    expect(ar.ticketTitle, isNot(contains('دور')));
  });
}
