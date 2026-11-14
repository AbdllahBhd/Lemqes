import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/home/presentation/pro_home_screen.dart';

import '../../auth/presentation/harness.dart' show byKey;
import 'home_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('has no space switch and names the fixed space', (tester) async {
    await pumpHome(tester, home: const ProHomeScreen(account: pro));
    expect(byKey('spaceSwitch_men'), findsNothing);
    expect(byKey('spaceSwitch_women'), findsNothing);
    expect(find.text(fr.homeSpaceLabel('men')), findsOneWidget);
    expect(find.text(fr.homeProEmptyTitle), findsOneWidget);
    expect(byKey('roleSwitch'), findsOneWidget);
    expect(byKey('settings'), findsOneWidget);
  });

  testWidgets('a barber is shown by full name', (tester) async {
    await pumpHome(tester, home: const ProHomeScreen(account: pro));
    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('a salon owner is shown by business name', (tester) async {
    const owner = Account(
      id: 'u1',
      fullName: 'Amine Benali',
      customerSpace: Space.men,
      proSpace: Space.men,
      activeRole: AppRole.salonOwner,
      roles: {AppRole.customer, AppRole.salonOwner},
      businessName: 'Salon Nassim',
    );
    await pumpHome(tester, home: const ProHomeScreen(account: owner));
    expect(find.text('Salon Nassim'), findsOneWidget);
    expect(find.text('Amine Benali'), findsNothing);
  });

  testWidgets('the complete-profile action is present but disabled', (
    tester,
  ) async {
    await pumpHome(tester, home: const ProHomeScreen(account: pro));
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('completeProfile')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await pumpHome(
      tester,
      home: const ProHomeScreen(account: pro),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
