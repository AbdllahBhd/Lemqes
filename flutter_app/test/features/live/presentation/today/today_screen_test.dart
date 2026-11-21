import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'today_harness.dart';

void main() {
  setUpAll(registerTodayFallbacks);
  final fr = AppLocalizationsFr();

  MockLiveRepository stubbed({List<OwnerQueueRow> rows = const []}) {
    final repo = MockLiveRepository();
    when(() => repo.ownerQueue(any())).thenAnswer((_) async => rows);
    when(() => repo.blocked(any())).thenAnswer((_) async => const []);
    when(
      () => repo.setStatus(any(), any(), breakUntil: any(named: 'breakUntil')),
    ).thenAnswer((_) async {});
    return repo;
  }

  group('status', () {
    testWidgets('choosing Ouvert opens through the repository', (t) async {
      final repo = stubbed();
      await pumpToday(t, repo: repo, snapshot: ownSnapshot());
      await tapKey(t, 'status_open');
      verify(() => repo.setStatus('p1', LiveStatus.open)).called(1);
    });

    testWidgets('En pause offers return times; 30 min sets break_until', (
      t,
    ) async {
      final repo = stubbed();
      await pumpToday(t, repo: repo, snapshot: openSnapshot(waiting: 0));
      await tapKey(t, 'status_on_break');
      expect(find.text(fr.todayBreakTitle), findsOneWidget);
      expect(find.byKey(const Key('break_none')), findsOneWidget);
      await tapKey(t, 'break_30');
      verify(
        () => repo.setStatus(
          'p1',
          LiveStatus.onBreak,
          breakUntil: testNow.add(const Duration(minutes: 30)),
        ),
      ).called(1);
    });

    testWidgets('Sans heure pauses without a return time', (t) async {
      final repo = stubbed();
      await pumpToday(t, repo: repo, snapshot: openSnapshot(waiting: 0));
      await tapKey(t, 'status_on_break');
      await tapKey(t, 'break_none');
      verify(() => repo.setStatus('p1', LiveStatus.onBreak)).called(1);
    });

    testWidgets('Fermé with customers waiting asks first', (t) async {
      final repo = stubbed(rows: fourEntries());
      await pumpToday(t, repo: repo, snapshot: openSnapshot());
      await tapKey(t, 'status_closed');
      expect(find.text(fr.todayCloseTitle), findsOneWidget);
      expect(find.text(fr.todayCloseBody(3)), findsOneWidget);
      verifyNever(
        () =>
            repo.setStatus(any(), any(), breakUntil: any(named: 'breakUntil')),
      );
      await tapKey(t, 'confirmAction');
      verify(() => repo.setStatus('p1', LiveStatus.closed)).called(1);
    });

    testWidgets('Fermé with nobody waiting closes at once', (t) async {
      final repo = stubbed();
      await pumpToday(t, repo: repo, snapshot: openSnapshot(waiting: 0));
      await tapKey(t, 'status_closed');
      expect(find.text(fr.todayCloseTitle), findsNothing);
      verify(() => repo.setStatus('p1', LiveStatus.closed)).called(1);
    });

    testWidgets('the auto-close row shows the snapshot time in Algiers', (
      t,
    ) async {
      final repo = stubbed();
      when(() => repo.extendAutoClose(any()))
          .thenAnswer((_) async => DateTime.utc(2026, 11, 20, 19, 30));
      final h = await pumpToday(t, repo: repo, snapshot: openSnapshot());
      // 18:30 UTC is 19:30 in Algiers, whatever the device zone.
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text(fr.todayAutoClose), findsOneWidget);

      h.push(
        ownSnapshot(
          status: LiveStatus.open,
          autoCloseAt: DateTime.utc(2026, 11, 20, 19, 30),
          version: 2,
        ),
      );
      await settle(t);
      expect(find.text('20:30'), findsOneWidget);

      await tapKey(t, 'extendAutoClose');
      verify(() => repo.extendAutoClose('p1')).called(1);
    });

    testWidgets('Statut incertain: tapping the current status confirms it', (
      t,
    ) async {
      final repo = stubbed();
      await pumpToday(
        t,
        repo: repo,
        snapshot: ownSnapshot(
          status: LiveStatus.open,
          autoCloseAt: DateTime.utc(2026, 11, 20, 18, 30),
          statusAgeFrom: testNow.subtract(const Duration(hours: 3)),
        ),
      );
      expect(find.text(fr.todayStaleNote), findsOneWidget);
      await tapKey(t, 'status_open');
      verify(() => repo.setStatus('p1', LiveStatus.open)).called(1);
    });

    testWidgets('a fresh status: tapping it again sends nothing', (t) async {
      final repo = stubbed();
      await pumpToday(t, repo: repo, snapshot: openSnapshot(waiting: 0));
      await tapKey(t, 'status_open');
      verifyNever(
        () =>
            repo.setStatus(any(), any(), breakUntil: any(named: 'breakUntil')),
      );
    });

    testWidgets('a closed pro shows no auto-close row', (t) async {
      await pumpToday(t, repo: stubbed(), snapshot: ownSnapshot());
      expect(find.text(fr.todayAutoClose), findsNothing);
    });
  });

  group('queue', () {
    testWidgets('+1, −1, call next and finish call the repository', (t) async {
      final rows = fourEntries();
      final repo = stubbed(rows: rows);
      when(() => repo.addWalkIn(any())).thenAnswer((_) async => rows);
      when(() => repo.undoWalkIn(any())).thenAnswer((_) async => rows);
      when(() => repo.callNext(any())).thenAnswer((_) async => rows);
      when(() => repo.finish(any())).thenAnswer((_) async => rows);
      await pumpToday(t, repo: repo, snapshot: openSnapshot());

      expect(find.text('3'), findsWidgets);
      await tapKey(t, 'walkInAdd');
      verify(() => repo.addWalkIn('p1')).called(1);
      await tapKey(t, 'walkInUndo');
      verify(() => repo.undoWalkIn('p1')).called(1);
      await tapKey(t, 'callNext');
      verify(() => repo.callNext('p1')).called(1);
      await tapKey(t, 'finish');
      verify(() => repo.finish('p1')).called(1);
    });

    testWidgets('a second tap on call next while in flight sends nothing', (
      t,
    ) async {
      final rows = fourEntries();
      final repo = stubbed(rows: rows);
      final gate = Completer<List<OwnerQueueRow>>();
      when(() => repo.callNext(any())).thenAnswer((_) => gate.future);
      await pumpToday(t, repo: repo, snapshot: openSnapshot());

      await tapKey(t, 'callNext');
      await t.tap(find.byKey(const Key('callNext')));
      await settle(t);
      verify(() => repo.callNext('p1')).called(1);

      gate.complete(rows);
      await settle(t);
    });

    testWidgets('while a queue action is in flight every control waits', (
      t,
    ) async {
      final rows = fourEntries();
      final repo = stubbed(rows: rows);
      final gate = Completer<List<OwnerQueueRow>>();
      when(() => repo.callNext(any())).thenAnswer((_) => gate.future);
      when(() => repo.addWalkIn(any())).thenAnswer((_) async => rows);
      await pumpToday(t, repo: repo, snapshot: openSnapshot());

      await tapKey(t, 'callNext');
      // Top to bottom: the list only scrolls down to find a key.
      for (final key in ['walkInAdd', 'walkInUndo', 'finish']) {
        expect(buttonEnabled(t, key), isFalse, reason: key);
      }
      await tapKey(t, 'walkInAdd');
      verifyNever(() => repo.addWalkIn(any()));
      await tapKey(t, 'queueRow_e2');
      expect(find.byKey(const Key('entryName')), findsNothing);
      await tapKey(t, 'queueClear');
      expect(buttonEnabled(t, 'queueClear'), isFalse);
      expect(find.text(fr.todayClearTitle), findsNothing);

      gate.complete(rows);
      await settle(t);
      expect(buttonEnabled(t, 'queueClear'), isTrue);
    });

    testWidgets('+1 in flight shows its progress', (t) async {
      final rows = fourEntries();
      final repo = stubbed(rows: rows);
      final gate = Completer<List<OwnerQueueRow>>();
      when(() => repo.addWalkIn(any())).thenAnswer((_) => gate.future);
      await pumpToday(t, repo: repo, snapshot: openSnapshot());
      await tapKey(t, 'walkInAdd');
      expect(
        find.descendant(
          of: find.byKey(const Key('walkInAdd')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete(rows);
      await settle(t);
    });

    testWidgets('call next is off when nobody waits, finish still works', (
      t,
    ) async {
      final rows = [fourEntries().first];
      final repo = stubbed(rows: rows);
      await pumpToday(t, repo: repo, snapshot: openSnapshot(waiting: 0));
      await tapKey(t, 'callNext');
      verifyNever(() => repo.callNext(any()));
      expect(find.byKey(const Key('finish')), findsOneWidget);
      expect(find.text(fr.todayQueueEmpty), findsOneWidget);
    });

    testWidgets('Vider la file asks first', (t) async {
      final rows = fourEntries();
      final repo = stubbed(rows: rows);
      when(() => repo.clear(any())).thenAnswer((_) async => const []);
      await pumpToday(t, repo: repo, snapshot: openSnapshot());
      await tapKey(t, 'queueClear');
      expect(find.text(fr.todayClearTitle), findsOneWidget);
      await tapKey(t, 'confirmAction');
      verify(() => repo.clear('p1')).called(1);
    });
  });

  testWidgets('offline: a banner and every action disabled', (t) async {
    final rows = fourEntries();
    final repo = stubbed(rows: rows);
    final h = await pumpToday(
      t,
      repo: repo,
      snapshot: openSnapshot(),
      connected: false,
    );
    expect(find.byKey(const Key('offlineBanner')), findsOneWidget);
    expect(find.text(fr.todayOffline), findsOneWidget);
    // Top to bottom: the list only scrolls down to find a key.
    for (final key in [
      'status_closed',
      'extendAutoClose',
      'walkInAdd',
      'walkInUndo',
      'finish',
      'callNext',
    ]) {
      await tapKey(t, key);
    }
    verifyNever(() => repo.addWalkIn(any()));
    verifyNever(() => repo.undoWalkIn(any()));
    verifyNever(() => repo.callNext(any()));
    verifyNever(() => repo.finish(any()));
    verifyNever(() => repo.extendAutoClose(any()));
    verifyNever(
      () => repo.setStatus(any(), any(), breakUntil: any(named: 'breakUntil')),
    );
    expect(find.text(fr.todayCloseTitle), findsNothing);

    h.connected.set(true);
    await settle(t);
    expect(find.byKey(const Key('offlineBanner')), findsNothing);
  });

  testWidgets('offline Retry rejoins the channels and reloads the queue', (
    t,
  ) async {
    final repo = stubbed(rows: fourEntries());
    final h = await pumpToday(
      t,
      repo: repo,
      snapshot: openSnapshot(),
      connected: false,
    );
    clearInteractions(repo);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('offlineBanner')),
        matching: find.text(fr.actionRetry),
      ),
    );
    await settle(t);
    expect(h.retries, 1);
    verify(() => repo.ownerQueue('p1')).called(1);
  });

  testWidgets('an unpublished profile says customers cannot see it', (t) async {
    await pumpToday(
      t,
      repo: stubbed(),
      profile: todayProfile(published: false),
      snapshot: openSnapshot(listed: false),
    );
    expect(find.byKey(const Key('unpublishedBanner')), findsOneWidget);
    expect(find.text(fr.todayUnpublished), findsOneWidget);
  });

  testWidgets('a published profile shows no unpublished banner', (t) async {
    await pumpToday(t, repo: stubbed(), snapshot: openSnapshot());
    expect(find.byKey(const Key('unpublishedBanner')), findsNothing);
  });

  testWidgets('a failure shows a snackbar and keeps the queue', (t) async {
    final rows = fourEntries();
    final repo = stubbed(rows: rows);
    when(() => repo.callNext(any())).thenThrow(const QueueEmpty());
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'callNext');
    expect(find.text(fr.liveErrorQueueEmpty), findsOneWidget);
    expect(find.byKey(const Key('queueRow_e2')), findsOneWidget);
    expect(find.text('Karim M.'), findsOneWidget);
  });

  testWidgets('a network failure says so', (t) async {
    final repo = stubbed(rows: fourEntries());
    when(() => repo.addWalkIn(any())).thenThrow(const LiveNetworkFailure());
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'walkInAdd');
    expect(find.text(fr.errorNetwork), findsOneWidget);
  });

  testWidgets('a salon owner keeps the salon-space state', (t) async {
    await pumpToday(
      t,
      repo: stubbed(),
      noProfile: true,
      account: todayAccount(role: AppRole.salonOwner),
    );
    expect(find.text(fr.dashboardSalonTitle), findsOneWidget);
    expect(find.byKey(const Key('callNext')), findsNothing);
  });

  testWidgets('Arabic at 200 % text does not overflow', (t) async {
    final ar = AppLocalizationsAr();
    await pumpToday(
      t,
      repo: stubbed(rows: fourEntries(arabic: true)),
      snapshot: openSnapshot(),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    expect(find.text(ar.todayCallNext), findsOneWidget);
    // The time stays a left-to-right island.
    final time = t.widget<Text>(find.text('19:30'));
    expect(
      Directionality.of(t.element(find.byWidget(time))),
      TextDirection.ltr,
    );
  });
}
