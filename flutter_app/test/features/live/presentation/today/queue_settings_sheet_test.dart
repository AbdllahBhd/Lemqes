import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'today_harness.dart';

void main() {
  setUpAll(registerTodayFallbacks);
  final fr = AppLocalizationsFr();

  final blocked = [
    BlockedCustomer(
      blockId: 'b1',
      ticketLabel: 'Karim M.',
      createdAt: DateTime.utc(2026, 11, 19),
    ),
    BlockedCustomer(
      blockId: 'b2',
      ticketLabel: null,
      createdAt: DateTime.utc(2026, 11, 18),
    ),
  ];

  MockLiveRepository stubbed() {
    final repo = MockLiveRepository();
    when(() => repo.ownerQueue(any())).thenAnswer((_) async => const []);
    when(() => repo.blocked(any())).thenAnswer((_) async => blocked);
    when(
      () => repo.setQueueSettings(
        any(),
        mode: any(named: 'mode'),
        hideCount: any(named: 'hideCount'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.unblock(any(), any()))
        .thenAnswer((_) async => [blocked.first]);
    return repo;
  }

  testWidgets('mode: followers is explained and saved with the count', (
    t,
  ) async {
    final repo = stubbed();
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueSettings');
    expect(find.text(fr.queueModeFollowersHint), findsOneWidget);
    await tapKey(t, 'mode_followers');
    verify(
      () => repo.setQueueSettings(
        'p1',
        mode: QueueMode.followers,
        hideCount: false,
      ),
    ).called(1);
  });

  testWidgets('hide count saves with the current mode', (t) async {
    final repo = stubbed();
    await pumpToday(
      t,
      repo: repo,
      snapshot: ownSnapshot(
        status: LiveStatus.open,
        mode: QueueMode.paused,
        waitingCount: 2,
      ),
    );
    await tapKey(t, 'queueSettings');
    await tapKey(t, 'hideCount');
    verify(
      () =>
          repo.setQueueSettings('p1', mode: QueueMode.paused, hideCount: true),
    ).called(1);
  });

  testWidgets('a hidden count reads as on', (t) async {
    await pumpToday(
      t,
      repo: stubbed(),
      snapshot: ownSnapshot(status: LiveStatus.open, countHidden: true),
    );
    await tapKey(t, 'queueSettings');
    final tile = t.widget<SwitchListTile>(find.byKey(const Key('hideCount')));
    expect(tile.value, isTrue);
  });

  testWidgets('closed with the count shown reads as off', (t) async {
    // A closed snapshot carries no count at all: that is not "hidden".
    await pumpToday(
      t,
      repo: stubbed(),
      snapshot: ownSnapshot(waitingCount: null, waitMin: null),
    );
    await tapKey(t, 'queueSettings');
    final tile = t.widget<SwitchListTile>(find.byKey(const Key('hideCount')));
    expect(tile.value, isFalse);
  });

  testWidgets('blocked customers list and unblock', (t) async {
    final repo = stubbed();
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueSettings');
    await t.scrollUntilVisible(
      find.byKey(const Key('unblock_b2')),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Karim M.'), findsOneWidget);
    expect(find.text(fr.queueBlockedUnnamed), findsOneWidget);
    await tapKey(t, 'unblock_b2');
    verify(() => repo.unblock('p1', 'b2')).called(1);
    expect(find.text(fr.queueBlockedUnnamed), findsNothing);
  });

  testWidgets('no blocked customers says so', (t) async {
    final repo = stubbed();
    when(() => repo.blocked(any())).thenAnswer((_) async => const []);
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueSettings');
    await t.scrollUntilVisible(
      find.text(fr.queueBlockedEmpty),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(fr.queueBlockedEmpty), findsOneWidget);
  });

  testWidgets('Arabic at 200 % text: the sheet does not overflow', (t) async {
    await pumpToday(
      t,
      repo: stubbed(),
      snapshot: openSnapshot(),
      locale: const Locale('ar'),
      textScale: 2,
    );
    await tapKey(t, 'queueSettings');
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('mode_paused')), findsOneWidget);
  });
}
