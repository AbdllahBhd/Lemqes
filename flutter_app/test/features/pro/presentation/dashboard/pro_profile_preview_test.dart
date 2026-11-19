import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/dashboard/pro_profile_preview_screen.dart';
import 'package:lemqes/features/pro/presentation/setup/pro_setup_flow.dart';
import 'package:lemqes/features/auth/presentation/auth_widgets.dart'
    show formatAlgerianPhone;
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:lemqes/shared/widgets/ltr.dart';

import 'dashboard_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('"see my public profile" opens the marked preview', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashPreview');
    // Pushed, so back returns to the dashboard.
    expect(h.router.state.uri.path, '/pro/me/preview');
    expect(find.byType(ProProfilePreviewScreen), findsOneWidget);
    expect(find.text(fr.previewTag), findsOneWidget);
    expect(find.text('Amine Benali'), findsOneWidget);
    // Read from the owner's own profile (the fake repository has no
    // public read at all): the customer RPC serves the owner no services.
    expect(find.text('Coupe homme'), findsOneWidget);

    await tapAndSettle(tester, 'proBack');
    expect(h.location, '/home');
  });

  testWidgets('hidden prices are masked as customers see them', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber(showPrices: false));
    await scrollAndTap(tester, 'dashPreview');
    expect(find.text(fr.proPriceHidden('salon')), findsOneWidget);
    expect(find.text('600 DA'), findsNothing);
  });

  testWidgets('paused services are left out like for customers', (
    tester,
  ) async {
    final profile = copyProfile(
      publishedBarber(),
      services: [
        ...publishedBarber().services,
        const ProService(
          id: 's9',
          presetKey: 'men_beard',
          category: ServiceCategory.beard,
          priceDzd: 300,
          durationMin: 15,
          active: false,
        ),
      ],
    );
    await pumpDashboard(tester, profile: profile);
    await scrollAndTap(tester, 'dashPreview');
    expect(find.text('Taille de barbe'), findsNothing);
  });

  testWidgets('a public phone shows a call button that cannot call', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      profile: publishedBarber(phone: PhoneVisibility.public),
    );
    await scrollAndTap(tester, 'dashPreview');
    final button = tester.widget<LemqesPrimaryButton>(byKey('callPreview'));
    expect(button.onPressed, isNull);
    expect(find.text(fr.previewCallNote), findsOneWidget);
  });

  testWidgets('a public phone shows the contact number customers will get', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      profile: publishedBarber(
        phone: PhoneVisibility.public,
        contactPhone: '+213661234567',
      ),
    );
    await scrollAndTap(tester, 'dashPreview');
    final number = find.text(formatAlgerianPhone('+213661234567'));
    expect(number, findsOneWidget);
    // Digits stay left to right inside RTL screens.
    expect(
      find.ancestor(of: number, matching: find.byType(Ltr)),
      findsOneWidget,
    );
  });

  testWidgets('a hidden phone shows no call button', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashPreview');
    expect(byKey('callPreview'), findsNothing);
  });

  group('routes', () {
    testWidgets('the preview path never reaches the public profile route', (
      tester,
    ) async {
      final h = await pumpDashboard(tester, profile: publishedBarber());
      h.router.go('/pro/me/preview');
      await settle(tester);
      expect(find.byType(ProProfilePreviewScreen), findsOneWidget);
      expect(find.byType(ProPublicProfileScreen), findsNothing);
    });

    testWidgets('setup and public profile routes still resolve', (
      tester,
    ) async {
      final h = await pumpDashboard(tester, profile: publishedBarber());
      h.router.go('/pro/setup/hours');
      await settle(tester);
      expect(find.byType(ProSetupScreen), findsOneWidget);
      expect(find.byType(ProProfilePreviewScreen), findsNothing);

      h.router.go('/pro/7f1c2b8e-4d3a-4c9b-9e21-0a5b6c7d8e9f');
      await settle(tester);
      expect(find.byType(ProPublicProfileScreen), findsOneWidget);
      expect(find.byType(ProProfilePreviewScreen), findsNothing);
    });
  });
}
