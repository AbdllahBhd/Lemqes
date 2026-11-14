import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/home/presentation/customer_home_screen.dart';
import 'package:lemqes/features/home/presentation/home_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart' show byKey, testAccount;
import 'home_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('shows the empty state, the space label and the actions', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: const CustomerHomeScreen(account: testAccount),
      account: testAccount,
    );
    expect(find.text(fr.homeCustomerEmptyTitle('men')), findsOneWidget);
    expect(find.text(fr.homeSpaceLabel('men')), findsOneWidget);
    expect(byKey('roleSwitch'), findsOneWidget);
    expect(byKey('settings'), findsOneWidget);
  });

  testWidgets('tapping Femmes switches the space and the label follows', (
    tester,
  ) async {
    var account = testAccount;
    final h = await pumpHome(
      tester,
      home: const HomeScreen(),
      fetch: () async => account,
    );
    when(() => h.account.setCustomerSpace(Space.women)).thenAnswer((_) async {
      account = const Account(
        id: 'u1',
        fullName: 'Amine Benali',
        customerSpace: Space.women,
        proSpace: null,
        activeRole: AppRole.customer,
        roles: {AppRole.customer},
      );
    });

    await tester.tap(byKey('spaceSwitch_women'));
    await tester.pump();
    await tester.pump();

    verify(() => h.account.setCustomerSpace(Space.women)).called(1);
    expect(find.text(fr.homeSpaceLabel('women')), findsOneWidget);
    expect(find.text(fr.homeSpaceLabel('men')), findsNothing);
  });

  testWidgets('the space switch targets are at least 48 dp', (tester) async {
    await pumpHome(
      tester,
      home: const CustomerHomeScreen(account: testAccount),
    );
    for (final key in ['spaceSwitch_men', 'spaceSwitch_women']) {
      final size = tester.getSize(byKey(key));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await pumpHome(
      tester,
      home: const CustomerHomeScreen(account: testAccount),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rapid double tap writes the space once', (tester) async {
    final h = await pumpHome(
      tester,
      home: const CustomerHomeScreen(account: testAccount),
      account: testAccount,
    );
    final gate = Completer<void>();
    when(() => h.account.setCustomerSpace(Space.women))
        .thenAnswer((_) => gate.future);

    await tester.tap(byKey('spaceSwitch_women'));
    await tester.pump();
    await tester.tap(byKey('spaceSwitch_women'));
    await tester.pump();

    verify(() => h.account.setCustomerSpace(Space.women)).called(1);
    gate.complete();
    await tester.pump();
  });
}
