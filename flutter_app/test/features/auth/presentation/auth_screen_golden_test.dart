import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

void main() {
  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    testWidgets('AuthScreen $name', (tester) async {
      // flutter_test flattens shadows by default; the soft shadow is the design.
      // Restored in `finally`: the binding checks painting debug vars before
      // tear-downs run.
      debugDisableShadows = false;
      try {
        await pumpApp(
          tester,
          location: '/auth',
          auth: MockAuthRepository(),
          locale: locale,
          themeMode: mode,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/auth_screen_$name.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
