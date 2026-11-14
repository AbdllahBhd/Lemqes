import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'explore_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

/// flutter_test flattens shadows by default; the soft shadow is the design.
/// Restored in `finally`: the binding checks painting debug vars before
/// tear-downs run.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    final arabic = locale.languageCode == 'ar';

    testWidgets('explore $name', (tester) async {
      await _withShadows(() async {
        await pumpExplore(
          tester,
          explore: FakeExploreRepository(cards: threeCards(arabic: arabic)),
          locale: locale,
          themeMode: mode,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/explore_$name.png'),
        );
      });
    });

    testWidgets('pro_public_profile $name', (tester) async {
      await _withShadows(() async {
        await pumpExplore(
          tester,
          pros: PublicProRepository(
            listed: {proUuid: publicBarber(arabic: arabic)},
            phones: {proUuid: '+213550123456'},
          ),
          location: '/pro/$proUuid',
          locale: locale,
          themeMode: mode,
          // Tall enough to show every section in one capture.
          size: const Size(390, 1800),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pro_public_profile_$name.png'),
        );
      });
    });
  }
}
