import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'today_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

void main() {
  setUpAll(registerTodayFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    final arabic = locale.languageCode == 'ar';

    final states = {
      'open': (openSnapshot(), fourEntries(arabic: arabic)),
      'on_break': (
        ownSnapshot(
          status: LiveStatus.onBreak,
          // 11:30 Algiers.
          breakUntil: DateTime.utc(2026, 11, 20, 10, 30),
          autoCloseAt: DateTime.utc(2026, 11, 20, 18, 30),
          waitingCount: 1,
          waitMin: 20,
        ),
        [fourEntries(arabic: arabic)[1]],
      ),
      'closed': (ownSnapshot(), const <OwnerQueueRow>[]),
    };

    for (final MapEntry(key: state, value: (snapshot, rows))
        in states.entries) {
      testWidgets('today_$state $name', (tester) async {
        // flutter_test flattens shadows by default; the soft shadow is the
        // design. Restored in `finally`: the binding checks painting debug
        // vars before tear-downs run.
        debugDisableShadows = false;
        try {
          final repo = MockLiveRepository();
          when(() => repo.ownerQueue(any())).thenAnswer((_) async => rows);
          await pumpToday(
            tester,
            repo: repo,
            profile: todayProfile(
              name: arabic ? 'أمين بن علي' : 'Amine Benali',
              arabic: arabic,
            ),
            snapshot: snapshot,
            locale: locale,
            themeMode: mode,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/today_${state}_$name.png'),
          );
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
