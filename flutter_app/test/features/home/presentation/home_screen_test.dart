import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:lemqes/features/home/presentation/customer_home_screen.dart';
import 'package:lemqes/features/home/presentation/home_screen.dart';
import 'package:lemqes/features/home/presentation/pro_home_screen.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart' show testAccount;
import 'home_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('shows the loading view while the account loads', (tester) async {
    final gate = never<Account?>();
    await pumpHome(tester, home: const HomeScreen(), fetch: () => gate.future);
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('a failed load shows the error view and retry refreshes', (
    tester,
  ) async {
    var calls = 0;
    final h = await pumpHome(
      tester,
      home: const HomeScreen(),
      fetch: () async {
        calls++;
        if (calls == 1) throw const NetworkAccountFailure();
        return testAccount;
      },
    );
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(find.textContaining('Instance of'), findsNothing);

    await tester.tap(find.text(fr.actionRetry));
    await tester.pump();
    await tester.pump();

    verify(() => h.account.fetchMine()).called(2);
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('a customer sees the customer home', (tester) async {
    await pumpHome(tester, home: const HomeScreen(), account: testAccount);
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(ProHomeScreen), findsNothing);
  });

  testWidgets('a pro sees the pro home', (tester) async {
    await pumpHome(tester, home: const HomeScreen(), account: pro);
    expect(find.byType(ProHomeScreen), findsOneWidget);
    expect(find.byType(CustomerHomeScreen), findsNothing);
  });

  testWidgets('a failed space switch keeps the home and says why', (
    tester,
  ) async {
    final h = await pumpHome(
      tester,
      home: const HomeScreen(),
      account: testAccount,
    );
    when(() => h.account.setCustomerSpace(any()))
        .thenThrow(const NetworkAccountFailure());

    await tester.tap(find.byKey(const Key('spaceSwitch_women')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(fr.errorNetwork), findsOneWidget);
  });

  testWidgets('two consecutive failed switches each show the snackbar', (
    tester,
  ) async {
    final h = await pumpHome(
      tester,
      home: const HomeScreen(),
      account: testAccount,
    );
    when(() => h.account.setCustomerSpace(any()))
        .thenThrow(const NetworkAccountFailure());

    await tester.tap(find.byKey(const Key('spaceSwitch_women')));
    await tester.pump();
    await tester.pump();
    expect(find.text(fr.errorNetwork), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(CustomerHomeScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('spaceSwitch_women')));
    await tester.pump();
    await tester.pump();
    expect(find.text(fr.errorNetwork), findsOneWidget);
  });

  testWidgets('a reload after a failure does not repeat the snackbar', (
    tester,
  ) async {
    var reloads = 0;
    final h = await pumpHome(
      tester,
      home: const HomeScreen(),
      fetch: () =>
          reloads++ == 0 ? Future.value(testAccount) : never<Account?>().future,
    );
    when(() => h.account.setCustomerSpace(any()))
        .thenThrow(const NetworkAccountFailure());
    await tester.tap(find.byKey(const Key('spaceSwitch_women')));
    await tester.pump();
    await tester.pump();
    ScaffoldMessenger.of(tester.element(find.byType(CustomerHomeScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // Loading again, the state still carries the old error.
    h.container.invalidate(accountProvider);
    await tester.pump();
    expect(h.container.read(accountProvider).isLoading, isTrue);
    expect(h.container.read(accountProvider).hasError, isTrue);

    expect(find.byType(SnackBar), findsNothing);
  });
}
