import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'dashboard_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    final arabic = locale.languageCode == 'ar';
    final displayName = arabic ? 'أمين بن علي' : 'Amine Benali';

    for (final published in [true, false]) {
      final state = published ? 'published' : 'unpublished';
      testWidgets('pro_dashboard_$state $name', (tester) async {
        // flutter_test flattens shadows by default; the soft shadow is the
        // design. Restored in `finally`: the binding checks painting debug
        // vars before tear-downs run.
        debugDisableShadows = false;
        try {
          await pumpDashboard(
            tester,
            account: proAccount(),
            profile: published
                ? publishedBarber(name: displayName, verified: true)
                : copyProfile(
                    barberProfile(service: false, hours: false),
                    displayName: displayName,
                  ),
            locale: locale,
            themeMode: mode,
            // Tall enough to show every section in one capture.
            size: const Size(390, 2000),
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/pro_dashboard_${state}_$name.png'),
          );
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
