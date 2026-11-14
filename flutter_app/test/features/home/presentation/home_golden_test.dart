import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/home/presentation/customer_home_screen.dart';

import 'home_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

// The pro home is the dashboard, captured in
// test/features/pro/presentation/dashboard/dashboard_golden_test.dart.
Account _account(Locale locale) => Account(
  id: 'u1',
  fullName: locale.languageCode == 'ar' ? 'أمين بن علي' : 'Amine Benali',
  customerSpace: Space.men,
  proSpace: Space.men,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer, AppRole.barber},
);

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    testWidgets('customer_home $name', (tester) async {
      // flutter_test flattens shadows by default; the soft shadow is the
      // design. Restored in `finally`: the binding checks painting debug
      // vars before tear-downs run.
      debugDisableShadows = false;
      try {
        final account = _account(locale);
        await pumpHome(
          tester,
          home: CustomerHomeScreen(account: account),
          account: account,
          locale: locale,
          themeMode: mode,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/customer_home_$name.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
