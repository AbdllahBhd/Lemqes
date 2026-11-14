import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';

import '../../auth/presentation/harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

void main() {
  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    testWidgets('RoleStep $name', (tester) async {
      // flutter_test flattens shadows by default; the soft shadow is the design.
      // Restored in `finally`: the binding checks painting debug vars before
      // tear-downs run.
      debugDisableShadows = false;
      try {
        await pumpApp(
          tester,
          location: '/signup/role',
          draft: const SignupDraft(space: Space.men, role: AppRole.customer),
          auth: MockAuthRepository(),
          locale: locale,
          themeMode: mode,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/role_step_$name.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
