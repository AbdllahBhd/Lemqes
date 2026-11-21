import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/home/presentation/customer_home_screen.dart';
import 'package:lemqes/features/home/presentation/home_screen.dart';
import 'package:lemqes/features/home/presentation/pro_shell.dart';
import 'package:lemqes/features/live/presentation/today/today_screen.dart';
import 'package:lemqes/features/pro/presentation/dashboard/pro_dashboard_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/presentation/harness.dart' show testAccount;
import 'home_harness.dart';

class _Account extends AccountController {
  @override
  Future<Account?> build() async => pro;
}

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('a pro lands on Aujourd’hui', (tester) async {
    await pumpHome(tester, home: const HomeScreen(), account: pro);
    expect(find.byType(ProShell), findsOneWidget);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(ProDashboardScreen), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(find.text(fr.proNavToday), findsOneWidget);
    expect(find.text(fr.proNavProfile), findsOneWidget);
  });

  testWidgets('Mon profil is the M2 dashboard, and back to today', (
    tester,
  ) async {
    await pumpHome(tester, home: const HomeScreen(), account: pro);
    await tester.tap(find.text(fr.proNavProfile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ProDashboardScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);

    await tester.tap(find.text(fr.proNavToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  test(
    'the tab goes back to Aujourd’hui on an account or role change',
    () async {
      final c = ProviderContainer(
        overrides: [accountProvider.overrideWith(_Account.new)],
      );
      addTearDown(c.dispose);
      c.listen(proTabProvider, (_, _) {});
      await c.read(accountProvider.future);
      final tab = c.read(proTabProvider.notifier)..select(ProTab.profile);
      expect(c.read(proTabProvider), ProTab.profile);

      // A refresh of the same account keeps the tab.
      c.read(accountProvider.notifier).state = const AsyncData(pro);
      expect(c.read(proTabProvider), ProTab.profile);

      c.read(accountProvider.notifier).state = AsyncData(
        Account(
          id: pro.id,
          fullName: pro.fullName,
          customerSpace: pro.customerSpace,
          proSpace: pro.proSpace,
          activeRole: AppRole.homeArtist,
          roles: const {AppRole.customer, AppRole.barber, AppRole.homeArtist},
        ),
      );
      expect(c.read(proTabProvider), ProTab.today);

      tab.select(ProTab.profile);
      c.read(accountProvider.notifier).state = AsyncData(
        Account(
          id: 'u2',
          fullName: 'Bilal',
          customerSpace: Space.men,
          proSpace: Space.men,
          activeRole: AppRole.barber,
          roles: const {AppRole.customer, AppRole.barber},
        ),
      );
      expect(c.read(proTabProvider), ProTab.today);
    },
  );

  testWidgets('customers keep their home, with no pro navigation', (
    tester,
  ) async {
    await pumpHome(tester, home: const HomeScreen(), account: testAccount);
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(ProShell), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Arabic at 200 % text does not overflow', (tester) async {
    final ar = AppLocalizationsAr();
    await pumpHome(
      tester,
      home: const HomeScreen(),
      account: pro,
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(ar.proNavToday), findsOneWidget);
  });
}
