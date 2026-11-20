import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'today_harness.dart';

void main() {
  setUpAll(registerTodayFallbacks);
  final fr = AppLocalizationsFr();

  MockLiveRepository stubbed(List<OwnerQueueRow> rows) {
    final repo = MockLiveRepository();
    when(() => repo.ownerQueue(any())).thenAnswer((_) async => rows);
    when(() => repo.blocked(any())).thenAnswer((_) async => const []);
    when(
      () => repo.setDetails(
        any(),
        name: any(named: 'name'),
        serviceId: any(named: 'serviceId'),
      ),
    ).thenAnswer((_) async => rows);
    when(() => repo.markAbsent(any())).thenAnswer((_) async => rows);
    when(() => repo.block(any())).thenAnswer((_) async => rows);
    return repo;
  }

  testWidgets('rows: position, label, service, kind, en route', (t) async {
    await pumpToday(t, repo: stubbed(fourEntries()), snapshot: openSnapshot());
    final row2 = find.byKey(const Key('queueRow_e2'));
    // No name: the localized "Client N" from the ticket number.
    expect(
      find.descendant(of: row2, matching: find.text(fr.todayClientN(2))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row2, matching: find.text('Coupe')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row2, matching: find.text(fr.todayKindWalkIn)),
      findsOneWidget,
    );
    expect(find.descendant(of: row2, matching: find.text('1')), findsOneWidget);

    final row3 = find.byKey(const Key('queueRow_e3'));
    expect(
      find.descendant(of: row3, matching: find.text('Karim M.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row3, matching: find.text(fr.todayKindRemote)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row3, matching: find.text(fr.todayOnTheWay)),
      findsOneWidget,
    );

    final row4 = find.byKey(const Key('queueRow_e4'));
    expect(
      find.descendant(of: row4, matching: find.text(fr.todayNoService)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row4, matching: find.text(fr.todayOnTheWay)),
      findsNothing,
    );
    // The serving entry is in its own row, not in the list.
    expect(find.byKey(const Key('queueRow_e1')), findsNothing);
    expect(find.text('Sami B.'), findsOneWidget);
  });

  testWidgets('a walk-in sheet sets service and name, no remote actions', (
    t,
  ) async {
    final repo = stubbed(fourEntries());
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueRow_e2');
    expect(find.byKey(const Key('entryName')), findsOneWidget);
    expect(find.byKey(const Key('entryAbsent')), findsNothing);
    expect(find.byKey(const Key('entryBlock')), findsNothing);

    await t.enterText(find.byKey(const Key('entryName')), 'Walid');
    await tapKey(t, 'entryService_s1');
    await tapKey(t, 'entrySave');
    verify(() => repo.setDetails('e2', name: 'Walid', serviceId: 's1'))
        .called(1);
  });

  testWidgets('a walk-in keeps its name when only the service changes', (
    t,
  ) async {
    final repo = stubbed(fourEntries());
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueRow_e4');
    await tapKey(t, 'entryService_s0');
    await tapKey(t, 'entrySave');
    verify(() => repo.setDetails('e4', name: 'Yanis K.', serviceId: 's0'))
        .called(1);
  });

  testWidgets('a remote sheet: no name field, absent and block confirm', (
    t,
  ) async {
    final repo = stubbed(fourEntries());
    await pumpToday(t, repo: repo, snapshot: openSnapshot());
    await tapKey(t, 'queueRow_e3');
    expect(find.byKey(const Key('entryName')), findsNothing);
    expect(find.byKey(const Key('entryAbsent')), findsOneWidget);

    await tapKey(t, 'entryAbsent');
    expect(find.text(fr.todayAbsentTitle), findsOneWidget);
    await tapKey(t, 'confirmAction');
    verify(() => repo.markAbsent('e3')).called(1);

    await tapKey(t, 'queueRow_e3');
    await tapKey(t, 'entryBlock');
    expect(find.text(fr.todayBlockTitle), findsOneWidget);
    await tapKey(t, 'confirmCancel');
    verifyNever(() => repo.block(any()));
  });

  testWidgets('Arabic at 200 % text: the sheet does not overflow', (t) async {
    await pumpToday(
      t,
      repo: stubbed(fourEntries(arabic: true)),
      snapshot: openSnapshot(),
      locale: const Locale('ar'),
      textScale: 2,
    );
    await tapKey(t, 'queueRow_e3');
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('entryBlock')), findsOneWidget);
  });
}
