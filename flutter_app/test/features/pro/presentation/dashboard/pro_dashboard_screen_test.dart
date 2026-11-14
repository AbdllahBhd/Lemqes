import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/features/pro/presentation/dashboard/pro_dashboard_screen.dart';
import 'package:lemqes/features/pro/presentation/edit/service_editor.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
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
    expect(h.router.state.uri.toString(), '/pro/setup/profile?edit=1');
    // Pushed over the dashboard, so system back returns to it.
    expect(h.router.canPop(), isTrue);
    expect(find.byType(ProfileStep), findsOneWidget);
    expect(find.text(fr.dashboardEditProfile), findsWidgets);

    await tester.enterText(byKey('displayNameField'), 'Amine B.');
    await tapAndSettle(tester, 'setupContinue');
    expect(h.router.state.uri.path, '/home');
    expect(h.router.canPop(), isFalse);
    expect(h.pros.profile!.displayName, 'Amine B.');
    expect(find.text('Amine B.'), findsOneWidget);
  });

  testWidgets('back from the profile edit returns to the dashboard', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditProfile');
    await tester.tap(find.byTooltip('Retour'));
    await settle(tester);
    expect(h.router.state.uri.path, '/home');
    expect(find.byType(ProDashboardScreen), findsOneWidget);
    expect(h.pros.calls, isNot(contains('updateProfile')));
  });

  testWidgets('a failed profile save then a retry that works leaves no '
      'snackbar on the dashboard', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditProfile');
    await tester.enterText(byKey('displayNameField'), 'Amine B.');
    h.pros.nextFailure = const ProNetworkFailure();
    await tapAndSettle(tester, 'setupContinue');
    // Said in place, on the edit page.
    expect(h.router.state.uri.path, '/pro/setup/profile');
    expect(find.text(fr.errorNetwork), findsOneWidget);

    await tapAndSettle(tester, 'setupContinue');
    expect(h.router.state.uri.path, '/home');
    expect(h.pros.profile!.displayName, 'Amine B.');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(fr.errorNetwork), findsNothing);
  });

  testWidgets('leaving the profile edit after a failure it reported does '
      'not repeat it on the dashboard', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditProfile');
    await tester.enterText(byKey('displayNameField'), 'Amine B.');
    h.pros.nextFailure = const ProNetworkFailure();
    await tapAndSettle(tester, 'setupContinue');
    expect(find.text(fr.errorNetwork), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await settle(tester);
    expect(h.router.state.uri.path, '/home');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failure under a sheet is still said once back on top', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'dashEditProfile');
    // A write that fails while the edit page covers the dashboard, not
    // reported by that page.
    h.pros.nextFailure = const ProNetworkFailure();
    await h.container
        .read(myProProvider.notifier)
        .updateProfile(const ProProfilePatch(bio: 'x'));
    await tester.tap(find.byTooltip('Retour'));
    await settle(tester);
    expect(find.widgetWithText(SnackBar, fr.errorNetwork), findsOneWidget);
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

  group('customer to barber switch', () {
    Future<SetupHarness> switchToBarber(
      WidgetTester tester,
      Future<ProProfile?> Function() mine,
    ) async {
      var role = AppRole.customer;
      final pros = FakeProRepository(profile: publishedBarber());
      final h = await pumpDashboard(
        tester,
        pros: pros,
        fetch: () async => proAccount(role: role),
      );
      pros.mineScript.add(mine);
      role = AppRole.barber;
      await h.container.read(accountProvider.notifier).refresh();
      await settle(tester);
      expect(find.byType(ProDashboardScreen), findsOneWidget);
      return h;
    }

    testWidgets('waits for the profile instead of asking to set it up', (
      tester,
    ) async {
      final pending = Completer<ProProfile?>();
      await switchToBarber(tester, () => pending.future);
      expect(find.text(fr.homeProEmptyTitle), findsNothing);
      expect(byKey('dashComplete'), findsNothing);
      expect(find.byType(LoadingView), findsOneWidget);

      pending.complete(publishedBarber());
      await settle(tester);
      expect(find.text(fr.dashboardPublished), findsOneWidget);
    });

    testWidgets('a failed load offers a retry, not the setup', (tester) async {
      await switchToBarber(tester, () async => throw const ProNetworkFailure());
      expect(find.text(fr.homeProEmptyTitle), findsNothing);
      expect(byKey('dashComplete'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);

      await tester.tap(find.text(fr.actionRetry));
      await settle(tester);
      expect(find.text(fr.dashboardPublished), findsOneWidget);
    });
  });

  testWidgets('a service stored but not reloaded shows once reloaded', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.pros.mineScript.add(() async => throw const ProNetworkFailure());
    await scrollAndTap(tester, 'dashAddService');
    await tapAndSettle(tester, 'addPreset_men_beard');
    await tapAndSettle(tester, 'serviceSave');
    expect(h.pros.calls.where((c) => c == 'upsertService'), hasLength(1));
    // Seen as stored, so the pro is not led to add it a second time.
    expect(byKey('dashService_s1'), findsOneWidget);
  });

  testWidgets('a failure under a sheet is said once the sheet closes', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    final gate = Completer<void>();
    h.photos
      ..gate = gate
      ..nextFailure = const ProNetworkFailure();
    await tapAndSettle(tester, 'dashAvatar');
    await scrollAndTap(tester, 'dashAddService');
    gate.complete();
    await settle(tester);
    expect(find.text(fr.errorNetwork), findsNothing);

    Navigator.of(tester.element(byKey('addCustom'))).pop();
    await settle(tester);
    expect(find.text(fr.errorNetwork), findsOneWidget);
  });

  group('avatar picker', () {
    testWidgets('a second tap does not open a second picker', (tester) async {
      var opened = 0;
      final pick = Completer<XFile?>();
      final h = await pumpDashboard(
        tester,
        profile: publishedBarber(),
        picker: () {
          opened++;
          return pick.future;
        },
      );
      await tester.tap(byKey('dashAvatar'));
      await tester.pump();
      await tester.tap(byKey('dashAvatar'));
      await settle(tester);
      expect(opened, 1);

      pick.complete(jpegFile());
      await settle(tester);
      expect(h.photos.calls, ['uploadAvatar']);
    });

    testWidgets('a picker that fails says so and can be tried again', (
      tester,
    ) async {
      var opened = 0;
      await pumpDashboard(
        tester,
        profile: publishedBarber(),
        picker: () async {
          opened++;
          throw PlatformException(code: 'photo_access_denied');
        },
      );
      await tapAndSettle(tester, 'dashAvatar');
      expect(find.text(fr.photoPickFailed), findsOneWidget);
      await tapAndSettle(tester, 'dashAvatar');
      expect(opened, 2);
    });
  });

  group('hours sheet', () {
    testWidgets('refuses a week with every day closed', (tester) async {
      final h = await pumpDashboard(tester, profile: publishedBarber());
      await scrollAndTap(tester, 'dashEditHours');
      for (final wd in [6, 7, 1, 2, 3, 4]) {
        await tapAndSettle(tester, 'day_${wd}_open');
      }
      await tapAndSettle(tester, 'hoursSave');
      expect(find.text(fr.dashboardHoursNeedOne), findsOneWidget);
      expect(byKey('hoursSave'), findsOneWidget);
      expect(h.pros.calls, isNot(contains('setHours')));
    });

    testWidgets('refuses a week with a flagged day', (tester) async {
      final h = await pumpDashboard(
        tester,
        profile: publishedBarber(),
        timeAnswers: [const TimeOfDay(hour: 9, minute: 0)],
      );
      await scrollAndTap(tester, 'dashEditHours');
      // Closing at the opening time.
      await tapAndSettle(tester, 'day_6_closes');
      await tapAndSettle(tester, 'hoursSave');
      expect(find.text(fr.hoursFixErrors), findsOneWidget);
      expect(h.pros.calls, isNot(contains('setHours')));
    });
  });

  testWidgets('the space hint is not announced as a button', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber());
    expect(
      tester.getSemantics(find.bySemanticsLabel(fr.proSpaceFixedHint)),
      isSemantics(isButton: false, label: fr.proSpaceFixedHint),
    );
  });
}
