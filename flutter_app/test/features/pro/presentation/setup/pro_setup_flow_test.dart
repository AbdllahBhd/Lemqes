import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/edit/service_editor.dart';
import 'package:lemqes/features/pro/presentation/setup/hours_step.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:lemqes/features/pro/presentation/setup/services_step.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'setup_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  group('entering setup', () {
    // A cold start after the code was verified: the code step finishes the
    // account, then the router decides where the new user lands.
    testWidgets('a barber who finishes sign-up opens the profile step', (
      tester,
    ) async {
      var created = false;
      final h = await pumpSetup(
        tester,
        fetch: () async => created ? proAccount() : null,
        draft: const SignupDraft(
          space: Space.men,
          role: AppRole.barber,
          fullName: 'Amine Benali',
          phone: '+213550123456',
        ),
        stubSignup: () => created = true,
      );

      expect(h.location, '/pro/setup/profile');
      expect(find.byType(ProfileStep), findsOneWidget);
      // Sign-up's four steps, then profile, services, hours.
      expect(find.text(fr.stepProgress(5, 7)), findsOneWidget);
    });

    testWidgets('a customer who finishes sign-up goes home', (tester) async {
      var created = false;
      final h = await pumpSetup(
        tester,
        fetch: () async => created
            ? const Account(
                id: 'u1',
                fullName: 'Amine Benali',
                customerSpace: Space.men,
                proSpace: null,
                activeRole: AppRole.customer,
                roles: {AppRole.customer},
              )
            : null,
        draft: const SignupDraft(
          space: Space.men,
          role: AppRole.customer,
          fullName: 'Amine Benali',
          phone: '+213550123456',
        ),
        stubSignup: () => created = true,
      );

      expect(h.location, '/home');
    });

    testWidgets('setup resumes at the first step with a gap', (tester) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(service: false)),
        location: '/pro/setup',
      );
      expect(h.location, '/pro/setup/services');
      expect(find.byType(ServicesStep), findsOneWidget);
      // Outside sign-up, setup counts its own three steps.
      expect(find.text(fr.stepProgress(2, 3)), findsOneWidget);

      h.router.go('/pro/setup/hours');
      await settle(tester);
      expect(h.location, '/pro/setup/services');
    });

    testWidgets('a pro opening home is not sent into setup', (tester) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(hours: false)),
        location: '/home',
      );
      expect(h.location, '/home');
    });

    testWidgets('adding the barber role from the role sheet opens setup', (
      tester,
    ) async {
      var added = false;
      const customer = Account(
        id: 'u1',
        fullName: 'Amine Benali',
        customerSpace: Space.men,
        proSpace: null,
        activeRole: AppRole.customer,
        roles: {AppRole.customer},
      );
      final h = await pumpSetup(
        tester,
        fetch: () async => added ? proAccount() : customer,
      );
      when(
        () => h.accounts.addRole(
          any(),
          space: any(named: 'space'),
          businessName: any(named: 'businessName'),
        ),
      ).thenAnswer((_) async => added = true);
      expect(h.location, '/home');

      await tapAndSettle(tester, 'roleSwitch');
      await tapAndSettle(tester, 'addRole');
      await tapAndSettle(tester, 'add_barber');
      await tapAndSettle(tester, 'addSpace_men');
      await tapAndSettle(tester, 'confirmAddRole');

      verify(
        () => h.accounts.addRole(
          AppRole.barber,
          space: Space.men,
          businessName: null,
        ),
      ).called(1);
      // The new role becomes the active one, so setup can act as it.
      verify(() => h.accounts.setActiveRole(AppRole.barber)).called(1);
      expect(h.location, '/pro/setup/profile');
    });
  });

  group('profile step', () {
    testWidgets('first save creates the profile, then fills it', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        location: '/pro/setup/profile',
      );
      expect(fieldText(tester, 'displayNameField'), 'Amine Benali');

      await tapAndSettle(tester, 'experience_2');
      await tapAndSettle(tester, 'workplace_own_studio');
      await tester.enterText(byKey('workplaceNameField'), 'Studio Amine');
      await tapAndSettle(tester, 'pickRegion');
      await tapAndSettle(tester, 'option_16');
      await tapAndSettle(tester, 'option_1601');
      await tapAndSettle(tester, 'mix_adults_and_kids');
      await tapAndSettle(tester, 'setupContinue');

      expect(h.pros.calls.take(2), ['create', 'updateProfile']);
      final p = h.pros.profile!;
      expect(p.displayName, 'Amine Benali');
      expect(p.workplaceType, WorkplaceType.ownStudio);
      expect(p.workplaceName, 'Studio Amine');
      expect(p.experienceYears, 7);
      expect(p.localityId, 1601);
      expect(p.customerMix, CustomerMix.adultsAndKids);
      expect(h.location, '/pro/setup/services');
    });

    testWidgets('a missing commune and clientele are named, nothing saved', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        location: '/pro/setup/profile',
      );
      await tester.enterText(byKey('displayNameField'), 'A');
      await tapAndSettle(tester, 'setupContinue');

      expect(find.text(fr.setupDisplayNameLength), findsOneWidget);
      expect(find.text(fr.setupLocalityRequired), findsOneWidget);
      expect(find.text(fr.setupCustomersRequired), findsOneWidget);
      expect(h.pros.calls, isEmpty);
      expect(h.location, '/pro/setup/profile');
    });

    testWidgets('a saved profile is updated, never created again', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(service: false)),
        location: '/pro/setup/profile',
      );
      // The saved commune and clientele are shown back.
      expect(find.text('Alger Centre'), findsOneWidget);
      await tapAndSettle(tester, 'setupContinue');

      expect(h.pros.calls, ['updateProfile']);
      expect(h.location, '/pro/setup/services');
    });

    testWidgets('a home artist works mobile and sets a radius and a fee', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(role: AppRole.homeArtist),
        location: '/pro/setup/profile',
      );
      expect(byKey('workplace_salon'), findsNothing);
      await tapAndSettle(tester, 'pickRegion');
      await tapAndSettle(tester, 'option_16');
      await tapAndSettle(tester, 'option_1601');
      await tapAndSettle(tester, 'mix_adults');
      await tapAndSettle(tester, 'radius_20');
      await tapAndSettle(tester, 'fee_0');
      await tapAndSettle(tester, 'setupContinue');

      final p = h.pros.profile!;
      expect(p.kind, ProKind.homeArtist);
      expect(p.workplaceType, WorkplaceType.mobile);
      expect(p.serviceRadiusKm, 20);
      expect(p.travelFeeDzd, 0);
    });
  });

  group('services step', () {
    testWidgets('a preset opens the editor prefilled and is added', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(service: false)),
        location: '/pro/setup/services',
      );
      expect(
        tester.widget<LemqesPrimaryButton>(byKey('setupContinue')).onPressed,
        isNull,
      );
      expect(find.text(fr.setupServicesNeedOne), findsOneWidget);

      await tapAndSettle(tester, 'preset_men_cut');
      expect(find.byType(ServiceEditor), findsOneWidget);
      expect(fieldText(tester, 'servicePriceField'), '600');
      await tester.enterText(byKey('servicePriceField'), '٧٠٠');
      await tapAndSettle(tester, 'serviceSave');

      final s = h.pros.profile!.services.single;
      expect(s.presetKey, 'men_cut');
      expect(s.priceDzd, 700);
      expect(find.text('700 DA'), findsOneWidget);

      await tapAndSettle(tester, 'setupContinue');
      expect(h.location, '/pro/setup/hours');
    });

    testWidgets('a custom service needs its name', (tester) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(service: false)),
        location: '/pro/setup/services',
      );
      await tapAndSettle(tester, 'addCustomService');
      await tester.enterText(byKey('servicePriceField'), '500');
      await tester.enterText(byKey('serviceDurationField'), '20');
      await tapAndSettle(tester, 'serviceSave');
      expect(find.text(fr.serviceNameRequired), findsOneWidget);

      await tester.enterText(byKey('serviceNameField'), 'Contours');
      await tapAndSettle(tester, 'serviceSave');
      expect(h.pros.profile!.services.single.customName, 'Contours');
    });

    testWidgets('removing a service archives it', (tester) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(hours: false)),
        location: '/pro/setup/services',
      );
      await tapAndSettle(tester, 'service_s0');
      await tapAndSettle(tester, 'serviceRemove');
      expect(h.pros.calls, ['archiveService']);
      expect(h.pros.profile!.services, isEmpty);
    });
  });

  group('hours step', () {
    testWidgets('publishing saves the week, then goes home', (tester) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(hours: false)),
        location: '/pro/setup/hours',
      );
      expect(find.byType(HoursStep), findsOneWidget);
      await tapAndSettle(tester, 'setupPublish');

      expect(h.pros.calls, ['setHours', 'publish']);
      // Sat-Thu 09:00-19:00 is offered; Friday starts closed.
      expect(h.pros.savedWeek!.map((d) => d.weekday).toSet(), {
        1,
        2,
        3,
        4,
        6,
        7,
      });
      expect(h.pros.profile!.isPublished, isTrue);
      expect(h.location, '/home');
    });

    testWidgets('a refusal for missing hours stays here and says so', (
      tester,
    ) async {
      final pros = FakeProRepository(profile: barberProfile(hours: false))
        ..publishFailure = const ProfileIncomplete({ProfileGap.hours});
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: pros,
        location: '/pro/setup/hours',
      );
      await tapAndSettle(tester, 'setupPublish');

      expect(h.location, '/pro/setup/hours');
      expect(find.text(fr.setupIncomplete), findsOneWidget);
    });

    testWidgets('a refusal for missing services opens that step', (
      tester,
    ) async {
      final pros = FakeProRepository(profile: barberProfile(hours: false))
        ..publishFailure = const ProfileIncomplete({ProfileGap.services});
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: pros,
        location: '/pro/setup/hours',
      );
      await tapAndSettle(tester, 'setupPublish');

      expect(h.location, '/pro/setup/services');
      expect(find.text(fr.setupIncomplete), findsOneWidget);
    });

    testWidgets('a network failure keeps the step with a message', (
      tester,
    ) async {
      final pros = FakeProRepository(profile: barberProfile(hours: false))
        ..publishFailure = const ProNetworkFailure();
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: pros,
        location: '/pro/setup/hours',
      );
      await tapAndSettle(tester, 'setupPublish');

      expect(h.location, '/pro/setup/hours');
      expect(find.text(fr.errorNetwork), findsOneWidget);
    });
  });

  group('200 % text in Arabic', () {
    for (final step in ['profile', 'services', 'hours']) {
      testWidgets('the $step step does not overflow', (tester) async {
        await pumpSetup(
          tester,
          account: proAccount(),
          pros: FakeProRepository(profile: barberProfile(hours: false)),
          location: '/pro/setup/$step',
          locale: const Locale('ar'),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      });
    }
  });
}
