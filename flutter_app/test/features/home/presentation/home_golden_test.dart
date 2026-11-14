import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/home/presentation/customer_home_screen.dart';
import 'package:lemqes/features/home/presentation/pro_home_screen.dart';

import 'home_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

Account _account(Locale locale, {required bool isPro}) => Account(
  id: 'u1',
  fullName: locale.languageCode == 'ar' ? 'أمين بن علي' : 'Amine Benali',
  customerSpace: Space.men,
  proSpace: Space.men,
  activeRole: isPro ? AppRole.barber : AppRole.customer,
  roles: const {AppRole.customer, AppRole.barber},
);

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    for (final isPro in [false, true]) {
      final screen = isPro ? 'pro_home' : 'customer_home';
      testWidgets('$screen $name', (tester) async {
        // flutter_test flattens shadows by default; the soft shadow is the
        // design. Restored in `finally`: the binding checks painting debug
        // vars before tear-downs run.
        debugDisableShadows = false;
        try {
          final account = _account(locale, isPro: isPro);
          await pumpHome(
            tester,
            home: isPro
                ? ProHomeScreen(account: account)
                : CustomerHomeScreen(account: account),
            account: account,
            locale: locale,
            themeMode: mode,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/${screen}_$name.png'),
          );
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
