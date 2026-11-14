import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/presentation/role_switch_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart' show byKey, tapKey, testAccount;
import '../../home/presentation/home_harness.dart';

const _customerOnly = testAccount;

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  // The real modal sheet, so popping it leaves the page underneath.
  Future<HomeHarness> pump(WidgetTester tester, Account account) async {
    final h = await pumpHome(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => showRoleSwitchSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      account: account,
    );
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('lists only the held roles, the active one marked', (
    tester,
  ) async {
    await pump(tester, pro);
    expect(byKey('role_customer'), findsOneWidget);
    expect(byKey('role_barber'), findsOneWidget);
    expect(byKey('role_home_artist'), findsNothing);
    expect(byKey('role_salon_owner'), findsNothing);
    expect(
      find.descendant(
        of: byKey('role_barber'),
        matching: find.text(fr.roleActive),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a held role switches to it', (tester) async {
    final h = await pump(tester, pro);
    await tapKey(tester, 'role_customer');
    verify(() => h.account.setActiveRole(AppRole.customer)).called(1);
  });

  testWidgets('adding a role when the pro space is fixed asks nothing', (
    tester,
  ) async {
    final h = await pump(tester, _withPro(Space.men));
    await tapKey(tester, 'addRole');
    await tapKey(tester, 'add_barber');

    expect(byKey('addSpace_men'), findsNothing);
    expect(byKey('addSpace_women'), findsNothing);
    expect(find.text(fr.roleSpaceLockedNote('men')), findsOneWidget);
    await tapKey(tester, 'confirmAddRole');

    verify(
      () => h.account.addRole(AppRole.barber, space: null, businessName: null),
    ).called(1);
  });

  testWidgets('without a pro space it asks for one before adding', (
    tester,
  ) async {
    final h = await pump(tester, _customerOnly);
    await tapKey(tester, 'addRole');
    await tapKey(tester, 'add_barber');

    expect(byKey('addSpace_men'), findsOneWidget);
    expect(byKey('addSpace_women'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: byKey('confirmAddRole'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNull);

    await tapKey(tester, 'addSpace_women');
    await tapKey(tester, 'confirmAddRole');
    verify(
      () => h.account.addRole(
        AppRole.barber,
        space: Space.women,
        businessName: null,
      ),
    ).called(1);
  });

  testWidgets('a salon owner must give a business name', (tester) async {
    final h = await pump(tester, _withPro(Space.men));
    await tapKey(tester, 'addRole');
    await tapKey(tester, 'add_salon_owner');

    await tapKey(tester, 'confirmAddRole');
    expect(find.text(fr.businessNameRequired), findsOneWidget);
    verifyNever(
      () => h.account.addRole(
        any(),
        space: any(named: 'space'),
        businessName: any(named: 'businessName'),
      ),
    );

    await tester.enterText(
      find.descendant(
        of: byKey('businessNameField'),
        matching: find.byType(EditableText),
      ),
      '  Salon Nassim ',
    );
    await tapKey(tester, 'confirmAddRole');
    verify(
      () => h.account.addRole(
        AppRole.salonOwner,
        space: null,
        businessName: 'Salon Nassim',
      ),
    ).called(1);
  });
}

Account _withPro(Space space) => Account(
  id: 'u1',
  fullName: 'Amine Benali',
  customerSpace: Space.men,
  proSpace: space,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer},
);
