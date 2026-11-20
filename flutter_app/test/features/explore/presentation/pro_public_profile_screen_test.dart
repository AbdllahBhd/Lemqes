import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/pro/data/price_parse.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/presentation/setup/pro_setup_flow.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/shared/widgets/hours_table.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
import 'package:material_ui/material_ui.dart';

import '../../live/presentation/customer/customer_live_harness.dart';
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

  testWidgets('a failed reload hides the call bar under the error', (
    tester,
  ) async {
    final pros = _repo();
    final h = await pumpExplore(tester, pros: pros, location: '/pro/$proUuid');
    expect(byKey('callPro'), findsOneWidget);

    pros.publicFailure = const ProNetworkFailure();
    h.container.invalidate(publicProProvider(proUuid));
    await settle(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(byKey('callPro'), findsNothing);
    expect(find.text('+213 550 12 34 56'), findsNothing);
  });

  testWidgets('a failed phone lookup says so and retry recovers', (
    tester,
  ) async {
    final pros = _repo()..phoneFailure = const ProNetworkFailure();
    await pumpExplore(tester, pros: pros, location: '/pro/$proUuid');

    expect(byKey('callPro'), findsNothing);
    expect(find.text(fr.proPhoneUnavailable), findsOneWidget);

    pros.phoneFailure = null;
    await tester.tap(byKey('phoneRetry'));
    await settle(tester);

    expect(find.text(fr.proPhoneUnavailable), findsNothing);
    expect(byKey('callPro'), findsOneWidget);
  });

  testWidgets('a failed commune lookup does not stick to the next profile', (
    tester,
  ) async {
    const second = '11111111-1111-4111-8111-111111111111';
    final geo = FlakyGeoRepository()..fail = true;
    final h = await pumpExplore(
      tester,
      pros: PublicProRepository(
        listed: {
          proUuid: publicBarber(),
          second: publicBarber(id: second),
        },
      ),
      geo: geo,
      location: '/pro/$proUuid',
    );
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(find.text('Alger Centre · Alger'), findsNothing);

    geo.fail = false;
    h.router.go('/pro/$second');
    await settle(tester);

    expect(find.text('Alger Centre · Alger'), findsOneWidget);
  });

  testWidgets('screen readers can open a photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpExplore(tester, pros: _repo(), location: '/pro/$proUuid');
    await tester.scrollUntilVisible(
      byKey('proPhoto_0'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester.getSemantics(byKey('proPhoto_0')),
      isSemantics(
        label: fr.photoViewerPosition(1, 3),
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('back returns to the explore list', (tester) async {
    final id = cardId(1);
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
      pros: PublicProRepository(listed: {id: publicBarber(id: id)}),
    );
    await tester.tap(byKey('proCard_$id'));
    await settle(tester);
    expect(h.location, '/pro/$id');
    expect(find.textContaining('Barbier depuis 2016'), findsOneWidget);

    await tester.tap(byKey('proBack'));
    await settle(tester);
    expect(h.location, '/home');
    expect(byKey('proCard_$id'), findsOneWidget);
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

  group('live block', () {
    Future<ExploreHarness> live(
      WidgetTester tester,
      LiveSnapshot snapshot, {
      MyTicket? ticket,
      Locale locale = const Locale('fr'),
      double textScale = 1,
    }) {
      final l = CustomerLive()
        ..repo.server[proUuid] = snapshot
        ..repo.ticket = ticket;
      return pumpExplore(
        tester,
        pros: PublicProRepository(
          listed: {proUuid: publicBarber(arabic: locale.languageCode == 'ar')},
          phones: {proUuid: _phone},
        ),
        location: '/pro/$proUuid',
        live: l,
        locale: locale,
        textScale: textScale,
      );
    }

    VoidCallback? join(WidgetTester tester) => tester
        .widget<LemqesPrimaryButton>(find.byKey(const Key('liveJoin')))
        .onPressed;

    testWidgets('shows status, queue and an enabled join when joinable', (
      tester,
    ) async {
      final h = await live(tester, custSnap(proUuid));

      final block = find.byKey(const Key('liveBlock'));
      expect(
        find.descendant(
          of: block,
          matching: find.text('3 en attente · ~40 min'),
        ),
        findsOneWidget,
      );
      expect(join(tester), isNotNull);
      // Opening the profile asks the server for a fresh snapshot.
      expect(h.live.repo.snapshotCalls, contains(equals([proUuid])));
      await unmountLive(tester);
    });

    final blocked = <String, LiveSnapshot>{
      'closed': closedSnap(proUuid),
      'on break': breakSnap(proUuid),
      'paused': custSnap(proUuid, mode: 'paused', joinBlock: 'paused'),
      'followers': custSnap(proUuid, mode: 'followers', joinBlock: 'followers'),
      'uncertain': custSnap(
        proUuid,
        ageFrom: DateTime.utc(2026, 11, 20, 7, 55),
      ),
      'past auto-close': custSnap(
        proUuid,
        autoCloseAt: DateTime.utc(2026, 11, 20, 9, 59),
      ),
    };
    for (final MapEntry(key: name, value: snapshot) in blocked.entries) {
      testWidgets('join is disabled: $name', (tester) async {
        await live(tester, snapshot);
        expect(join(tester), isNull);
        await unmountLive(tester);
      });
    }

    testWidgets('holding a place here shows the ticket, not the join', (
      tester,
    ) async {
      await live(tester, custSnap(proUuid), ticket: ticketFor(proId: proUuid));

      final block = find.byKey(const Key('liveBlock'));
      expect(
        find.descendant(
          of: block,
          matching: find.text('Vous êtes 3e · ~25 min'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('liveJoin')), findsNothing);
      await unmountLive(tester);
    });

    testWidgets('a pro seen unlisted, then republished, recovers on open', (
      tester,
    ) async {
      final l = CustomerLive()
        ..repo.server[proUuid] = custSnap(proUuid, version: 4);
      final h = await pumpExplore(
        tester,
        explore: FakeExploreRepository(
          cards: [card(1, live: custSnap(cardId(1)))],
        ),
        pros: PublicProRepository(
          listed: {proUuid: publicBarber()},
          phones: {proUuid: _phone},
        ),
        live: l,
      );
      // An unpublish seen by this device: customers drop the pro.
      h.container
          .read(liveChannelsProvider)
          .seed(custSnap(proUuid, listed: false, version: 3));
      h.router.push('/pro/$proUuid');
      await settleLive(tester);

      expect(find.byKey(const Key('liveBlock')), findsOneWidget);
      expect(join(tester), isNotNull);
      await unmountLive(tester);
    });

    testWidgets('the owner preview shows the live block, read-only', (
      tester,
    ) async {
      final l = CustomerLive()..own = (id) => custSnap(id, version: 1);
      await pumpExplore(
        tester,
        account: proAccount(),
        pros: PublicProRepository(profile: barberProfile()),
        location: '/pro/me/preview',
        live: l,
      );

      expect(find.byKey(const Key('liveBlock')), findsOneWidget);
      expect(find.text('3 en attente · ~40 min'), findsOneWidget);
      expect(find.byKey(const Key('liveJoin')), findsNothing);
      // The owner's own channel only: never the customer one.
      expect(l.repo.snapshotCalls, isEmpty);
      expect(l.factory.channels, isEmpty);
      await unmountLive(tester);
    });

    testWidgets('does not overflow at 2x text in Arabic with a ticket', (
      tester,
    ) async {
      await live(
        tester,
        breakSnap(proUuid),
        ticket: ticketFor(proId: proUuid),
        locale: const Locale('ar'),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await settleLive(tester);
        expect(tester.takeException(), isNull);
      }
      await unmountLive(tester);
    });
  });
}
