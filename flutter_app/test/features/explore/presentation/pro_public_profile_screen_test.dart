import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/pro/data/price_parse.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/presentation/setup/pro_setup_flow.dart';
import 'package:lemqes/shared/widgets/hours_table.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
import 'package:material_ui/material_ui.dart';

import 'explore_harness.dart';

const _phone = '+213550123456';

PublicProRepository _repo({bool showPrices = true, String? phone = _phone}) =>
    PublicProRepository(
      listed: {proUuid: publicBarber(showPrices: showPrices)},
      phones: {proUuid: ?phone},
    );

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('shows the hero, bio, customers, services and hours', (
    tester,
  ) async {
    await pumpExplore(tester, pros: _repo(), location: '/pro/$proUuid');

    expect(find.byType(ProPublicProfileScreen), findsOneWidget);
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(fr.proVerified)), findsOneWidget);
    expect(
      find.text(
        '${fr.roleBarberTitle('men')} · ${fr.proPublicExperience('b2')}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('${fr.exploreWorkplaceType('salon')} · Salon El Bahdja'),
      findsOneWidget,
    );
    expect(find.text('Alger Centre · Alger'), findsOneWidget);
    expect(find.textContaining('Barbier depuis 2016'), findsOneWidget);
    expect(find.text(fr.customerMixAdultsAndKids('men')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Taille de barbe'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Coupe homme'), findsOneWidget);
    expect(find.text('600 DA'), findsOneWidget);
    expect(find.text(formatDzd(1500, const Locale('fr'))), findsOneWidget);
    expect(find.text(fr.serviceDuration(30)), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(HoursTable),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(HoursTable), findsOneWidget);
  });

  testWidgets('the call button appears with a public phone and dials it', (
    tester,
  ) async {
    final dialled = <Uri>[];
    await pumpExplore(
      tester,
      pros: _repo(),
      location: '/pro/$proUuid',
      launcher: (uri) async {
        dialled.add(uri);
        return true;
      },
    );

    expect(byKey('callPro'), findsOneWidget);
    final number = find.text('+213 550 12 34 56');
    expect(number, findsOneWidget);
    expect(Directionality.of(tester.element(number)), TextDirection.ltr);

    await tester.tap(byKey('callPro'));
    await settle(tester);

    expect(dialled, [Uri(scheme: 'tel', path: _phone)]);
  });

  testWidgets('no public phone, no call button', (tester) async {
    await pumpExplore(
      tester,
      pros: _repo(phone: null),
      location: '/pro/$proUuid',
    );

    expect(find.text('Amine Benali'), findsOneWidget);
    expect(byKey('callPro'), findsNothing);
    expect(find.text(fr.proPublicCall), findsNothing);
  });

  testWidgets('a call the device cannot place says so', (tester) async {
    await pumpExplore(
      tester,
      pros: _repo(),
      location: '/pro/$proUuid',
      launcher: (_) async => false,
    );

    await tester.tap(byKey('callPro'));
    await settle(tester);

    expect(find.text(fr.proPublicCallFailed), findsOneWidget);
  });

  testWidgets('hidden prices show the hidden-price words per service', (
    tester,
  ) async {
    await pumpExplore(
      tester,
      pros: _repo(showPrices: false),
      location: '/pro/$proUuid',
    );

    await tester.scrollUntilVisible(
      find.text('Taille de barbe'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(fr.proPriceHidden('salon')), findsNWidgets(2));
    expect(find.byType(PriceText), findsNothing);
  });

  testWidgets('an unknown id shows the unavailable state', (tester) async {
    const other = '00000000-0000-4000-8000-000000000000';
    final h = await pumpExplore(tester, pros: _repo(), location: '/pro/$other');

    expect(byKey('proUnavailable'), findsOneWidget);
    expect(find.text(fr.proUnavailableTitle), findsOneWidget);
    expect(h.pros.publicCalls, [other]);

    await tester.tap(find.text(fr.proUnavailableBack));
    await settle(tester);
    expect(h.location, '/home');
  });

  testWidgets('an id that is not a uuid is unavailable without a query', (
    tester,
  ) async {
    final h = await pumpExplore(tester, pros: _repo(), location: '/pro/p1');

    expect(byKey('proUnavailable'), findsOneWidget);
    expect(h.pros.publicCalls, isEmpty);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final pros = _repo()..publicFailure = const ProNetworkFailure();
    await pumpExplore(tester, pros: pros, location: '/pro/$proUuid');

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(fr.errorNetwork), findsOneWidget);

    pros.publicFailure = null;
    await tester.tap(find.text(fr.actionRetry));
    await settle(tester);

    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('a photo opens the full-screen viewer, which swipes', (
    tester,
  ) async {
    await pumpExplore(tester, pros: _repo(), location: '/pro/$proUuid');

    await tester.scrollUntilVisible(
      byKey('proPhoto_0'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(byKey('proPhoto_0'));
    await settle(tester);

    expect(byKey('photoViewer'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.fling(byKey('photoViewer'), const Offset(-200, 0), 1000);
    await settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(byKey('photoViewerClose'));
    await settle(tester);
    expect(byKey('photoViewer'), findsNothing);
    expect(find.byType(ProPublicProfileScreen), findsOneWidget);
  });

  testWidgets('back returns to the explore list', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
      pros: PublicProRepository(listed: {'p1': publicBarber(id: 'p1')}),
    );
    await tester.tap(byKey('proCard_p1'));
    await settle(tester);
    expect(h.location, '/pro/p1');

    await tester.tap(byKey('proBack'));
    await settle(tester);
    expect(h.location, '/home');
  });

  testWidgets('/pro/setup still opens setup, not a profile', (tester) async {
    final h = await pumpExplore(
      tester,
      account: proAccount(),
      pros: PublicProRepository(profile: barberProfile(hours: false)),
      location: '/pro/setup',
    );

    expect(h.location, '/pro/setup/hours');
    expect(find.byType(ProSetupScreen), findsOneWidget);
    expect(find.byType(ProPublicProfileScreen), findsNothing);
    expect(h.pros.publicCalls, isEmpty);
  });

  testWidgets('/pro/<uuid> opens the public profile', (tester) async {
    final h = await pumpExplore(
      tester,
      pros: _repo(),
      location: '/pro/$proUuid',
    );

    expect(h.location, '/pro/$proUuid');
    expect(find.byType(ProPublicProfileScreen), findsOneWidget);
    expect(h.pros.publicCalls, [proUuid]);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await pumpExplore(
      tester,
      pros: PublicProRepository(
        listed: {proUuid: publicBarber(arabic: true)},
        phones: {proUuid: _phone},
      ),
      location: '/pro/$proUuid',
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await settle(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
