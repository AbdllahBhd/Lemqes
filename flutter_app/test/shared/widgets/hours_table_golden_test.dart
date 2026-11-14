import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/shared/widgets/hours_table.dart';
import 'package:material_ui/material_ui.dart';

import 'golden_host.dart';

DayHours _day(int wd, int oh, int ch, {bool brk = false}) => DayHours(
  weekday: wd,
  opens: TimeOfDay(hour: oh, minute: 0),
  closes: TimeOfDay(hour: ch, minute: 0),
  breakStart: brk ? const TimeOfDay(hour: 13, minute: 0) : null,
  breakEnd: brk ? const TimeOfDay(hour: 14, minute: 0) : null,
);

void main() {
  // Sunday is missing (closed); Saturday runs past midnight; today is Wednesday.
  final week = [
    _day(1, 9, 19),
    _day(2, 9, 19),
    _day(3, 9, 19, brk: true),
    _day(4, 9, 19),
    _day(5, 9, 12),
    _day(6, 14, 1),
  ];

  for (final v in goldenVariants) {
    testWidgets('HoursTable ${goldenName(v)}', (tester) async {
      tester.view.physicalSize = const Size(390, 520) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const key = ValueKey('hours');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lemqesTheme(v.brightness),
          locale: v.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: key,
                child: Builder(
                  builder: (context) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HoursTable(
                        week: week,
                        clock: () => DateTime(2026, 11, 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/hours_table_${goldenName(v)}.png'),
      );
    });
  }
}
