import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/settings/presentation/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart' show byKey, testAccount;
import '../../home/presentation/home_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  Future<HomeHarness> pump(WidgetTester tester) =>
      pumpHome(tester, home: const SettingsScreen(), account: testAccount);

  testWidgets('choosing Taqbaylit sets the kab locale', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.text('Taqbaylit'));
    await tester.pump();
    expect(h.container.read(localeProvider), const Locale('kab'));
  });

  testWidgets('lists the four languages by their own names', (tester) async {
    await pump(tester);
    for (final name in ['العربية', 'Français', 'English', 'Taqbaylit']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('choosing Sombre sets the dark theme', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.text(fr.themeDark));
    await tester.pump();
    expect(h.container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('sign-out asks first, then signs out', (tester) async {
    final h = await pump(tester);
    await tester.ensureVisible(byKey('signOut'));
    await tester.tap(byKey('signOut'));
    await tester.pumpAndSettle();

    expect(find.text(fr.signOutConfirmTitle), findsOneWidget);
    verifyNever(() => h.auth.signOut());

    await tester.tap(byKey('confirmSignOut'));
    await tester.pumpAndSettle();
    verify(() => h.auth.signOut()).called(1);
  });

  testWidgets('cancelling the sign-out keeps the session', (tester) async {
    final h = await pump(tester);
    await tester.ensureVisible(byKey('signOut'));
    await tester.tap(byKey('signOut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.actionCancel));
    await tester.pumpAndSettle();
    verifyNever(() => h.auth.signOut());
  });

  testWidgets('the role switch entry opens the sheet', (tester) async {
    await pump(tester);
    await tester.ensureVisible(byKey('roleSwitch'));
    await tester.tap(byKey('roleSwitch'));
    await tester.pumpAndSettle();
    expect(find.text(fr.roleSwitchTitle), findsWidgets);
    expect(byKey('addRole'), findsOneWidget);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await pumpHome(
      tester,
      home: const SettingsScreen(),
      account: testAccount,
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed role switch shows the snackbar', (tester) async {
    final h = await pump(tester);
    when(() => h.account.setActiveRole(any()))
        .thenThrow(const NetworkAccountFailure());
    await tester.ensureVisible(byKey('roleSwitch'));
    await tester.tap(byKey('roleSwitch'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('role_customer'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(fr.errorNetwork), findsWidgets);
  });
}
