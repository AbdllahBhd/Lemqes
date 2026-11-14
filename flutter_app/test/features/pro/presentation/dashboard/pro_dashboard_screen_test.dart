import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/presentation/dashboard/pro_dashboard_screen.dart';
import 'package:lemqes/features/pro/presentation/edit/service_editor.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:material_ui/material_ui.dart';

import 'dashboard_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('a pro lands on the dashboard with name, space and actions', (
    tester,
  ) async {
    await pumpDashboard(tester, profile: publishedBarber(verified: true));
    expect(find.byType(ProDashboardScreen), findsOneWidget);
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(find.text(fr.homeSpaceLabel('men')), findsOneWidget);
    expect(find.bySemanticsLabel(fr.proVerified), findsOneWidget);
    expect(byKey('roleSwitch'), findsOneWidget);
    expect(byKey('settings'), findsOneWidget);
  });

  testWidgets('an unpublished profile says why and offers to complete it', (
    tester,
  ) async {
    final h = await pumpDashboard(
      tester,
      profile: barberProfile(service: false, hours: false),
    );
    expect(find.text(fr.dashboardHidden), findsOneWidget);
    expect(find.text(fr.dashboardPublished), findsNothing);
    expect(find.text(fr.dashboardGap('services')), findsOneWidget);
    expect(find.text(fr.dashboardGap('hours')), findsOneWidget);
    expect(find.text(fr.dashboardGap('locality')), findsNothing);

    await tapAndSettle(tester, 'dashComplete');
    // `/pro/setup` resumes at the first gap.
    expect(h.location, '/pro/setup/services');
  });

  testWidgets('a complete but unlisted profile offers to publish', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: barberProfile());
    expect(find.text(fr.dashboardHidden), findsOneWidget);
    expect(find.text(fr.dashboardReadyBody), findsOneWidget);
    await tapAndSettle(tester, 'dashPublish');
    expect(h.pros.calls, contains('publish'));
    await scrollToTop(tester);
    expect(find.text(fr.dashboardPublished), findsOneWidget);
  });

  testWidgets('a published profile says it is published', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber());
    expect(find.text(fr.dashboardPublished), findsOneWidget);
    expect(find.text(fr.dashboardPublishedBody('men')), findsOneWidget);
    expect(byKey('dashComplete'), findsNothing);
    expect(byKey('dashPublish'), findsNothing);
  });

  testWidgets('pausing the last service hides the profile after the refetch', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashService_s0');
    expect(find.byType(ServiceEditor), findsOneWidget);
    await tapAndSettle(tester, 'serviceActiveSwitch');
    await tapAndSettle(tester, 'serviceSave');

    expect(h.pros.calls, contains('upsertService'));
    await scrollToTop(tester);
    expect(find.text(fr.dashboardHidden), findsOneWidget);
    expect(find.text(fr.dashboardGap('services')), findsOneWidget);
  });

  testWidgets('removing the last service hides the profile too', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashService_s0');
    await tapAndSettle(tester, 'serviceRemove');
    expect(h.pros.calls, contains('archiveService'));
    expect(byKey('dashService_s0'), findsNothing);
    await scrollToTop(tester);
    expect(find.text(fr.dashboardHidden), findsOneWidget);
  });

  testWidgets('a service is added from the space presets', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashAddService');
    // The cut is already offered; only the beard is left to add.
    expect(byKey('addPreset_men_cut'), findsNothing);
    await tapAndSettle(tester, 'addPreset_men_beard');
    await tapAndSettle(tester, 'serviceSave');
    expect(h.pros.calls, contains('upsertService'));
    expect(h.pros.profile!.services.map((s) => s.presetKey), [
      'men_cut',
      'men_beard',
    ]);
  });

  testWidgets('the hours are edited in a sheet and saved', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditHours');
    await tapAndSettle(tester, 'hoursSave');
    expect(h.pros.calls, contains('setHours'));
    expect(h.pros.savedWeek, hasLength(6));
  });

  testWidgets('a failure shows a snackbar and keeps the dashboard', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.pros.nextFailure = const ProNetworkFailure();
    await scrollAndTap(tester, 'showPricesSwitch');

    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(find.text('Amine Benali'), findsOneWidget);
    await scrollToTop(tester);
    expect(find.text(fr.dashboardPublished), findsOneWidget);
    expect(h.pros.profile!.showPrices, isTrue);
  });

  testWidgets('editing the profile returns to the dashboard', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditProfile');
    expect(h.uri.toString(), '/pro/setup/profile?edit=1');
    expect(find.byType(ProfileStep), findsOneWidget);
    expect(find.text(fr.dashboardEditProfile), findsWidgets);

    await tester.enterText(byKey('displayNameField'), 'Amine B.');
    await tapAndSettle(tester, 'setupContinue');
    expect(h.location, '/home');
    expect(h.pros.profile!.displayName, 'Amine B.');
    expect(find.text('Amine B.'), findsOneWidget);
  });

  testWidgets('the header photo changes the avatar', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await tapAndSettle(tester, 'dashAvatar');
    expect(h.photos.calls, ['uploadAvatar']);
    expect(h.pros.profile!.avatarPath, 'p1/avatar.jpg');
  });

  testWidgets('a pro without a profile is sent to set it up', (tester) async {
    final h = await pumpDashboard(tester);
    expect(find.text(fr.homeProEmptyTitle), findsOneWidget);
    await tapAndSettle(tester, 'dashComplete');
    expect(h.location, '/pro/setup/profile');
  });

  testWidgets('a salon owner sees the salon space is coming', (tester) async {
    await pumpDashboard(
      tester,
      account: const Account(
        id: 'u1',
        fullName: 'Amine Benali',
        customerSpace: Space.men,
        proSpace: Space.men,
        activeRole: AppRole.salonOwner,
        roles: {AppRole.customer, AppRole.salonOwner},
        businessName: 'Salon Nassim',
      ),
    );
    expect(find.text('Salon Nassim'), findsOneWidget);
    expect(find.text(fr.dashboardSalonTitle), findsOneWidget);
    expect(byKey('dashComplete'), findsNothing);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    final pros = FakeProRepository(profile: publishedBarber());
    pros.mineScript.add(() async => throw const ProNetworkFailure());
    await pumpDashboard(tester, pros: pros);
    expect(find.text(fr.errorNetwork), findsOneWidget);
    await tester.tap(find.text(fr.actionRetry));
    await settle(tester);
    expect(find.text(fr.dashboardPublished), findsOneWidget);
  });

  for (final unpublished in [false, true]) {
    testWidgets(
      'no overflow at 2x text in Arabic (unpublished: $unpublished)',
      (tester) async {
        await pumpDashboard(
          tester,
          profile: unpublished
              ? barberProfile(service: false)
              : publishedBarber(photos: 3),
          locale: const Locale('ar'),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          byKey('dashPreview'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
