import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/explore/presentation/pro_avatar.dart';
import 'package:lemqes/features/explore/presentation/pro_card_tile.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:material_ui/material_ui.dart';

import '../../pro/presentation/pro_test_host.dart';
import '../../live/presentation/customer/customer_live_harness.dart';
import 'explore_harness.dart';

/// Pumps [c] over the real live channels, seeded with [c]'s live object
/// as a search would.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  ProCard c, {
  Locale locale = const Locale('fr'),
  double textScale = 1,
  VoidCallback? onTap,
}) async {
  final live = CustomerLive();
  addTearDown(live.dispose);
  final container = ProviderContainer(
    overrides: [
      photoUploaderProvider.overrideWithValue(FakePhotoUploader()),
      ...live.overrides(),
      customerAccountOverride(),
    ],
  );
  addTearDown(container.dispose);
  await container.read(accountProvider.future);
  if (c.live case final s?) container.read(liveChannelsProvider).seed(s);
  await pumpLocalized(
    tester,
    UncontrolledProviderScope(
      container: container,
      child: ProCardTile(card: c, onTap: onTap ?? () {}),
    ),
    locale: locale,
    textScale: textScale,
  );
  await settleLive(tester);
  return container;
}

String _statusLine(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('liveStatusLine')))
    .textSpan!
    .toPlainText(includePlaceholders: false)
    // Details are kept whole with no-break spaces.
    .replaceAll('\u00a0', ' ');

void main() {
  final fr = AppLocalizationsFr();
  final ar = AppLocalizationsAr();

  setUpAll(registerHarnessFallbacks);

  testWidgets('shows who, where and the starting price', (tester) async {
    await _pump(tester, threeCards().first);

    expect(find.text('Amine Benali'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(fr.proVerified)), findsOneWidget);
    expect(
      find.text('${fr.exploreWorkplaceType('salon')} · Salon El Bahdja'),
      findsOneWidget,
    );
    expect(find.text('Bab Ezzouar · Alger'), findsOneWidget);
    expect(find.text(fr.exploreFromPrice), findsOneWidget);
    expect(find.text('600 DA'), findsOneWidget);
    expect(find.byType(PriceText), findsOneWidget);
  });

  testWidgets('without a photo the avatar shows the initials', (tester) async {
    await _pump(tester, threeCards().first);
    expect(find.text('AB'), findsOneWidget);
  });

  test('Arabic names get one initial, never two joined letters', () {
    expect(initialsOf('كريم سعدي'), 'ك');
    expect(initialsOf('Karim Saadi'), 'KS');
    expect(initialsOf('  amine  '), 'A');
  });

  testWidgets('an unverified pro has no tick', (tester) async {
    await _pump(tester, threeCards()[1]);
    expect(find.bySemanticsLabel(RegExp(fr.proVerified)), findsNothing);
  });

  testWidgets('hidden prices say so instead of a number', (tester) async {
    await _pump(tester, threeCards()[1]);

    expect(find.text(fr.proPriceHidden('salon')), findsOneWidget);
    expect(find.byType(PriceText), findsNothing);
    expect(find.textContaining('DA'), findsNothing);
    expect(find.text(fr.exploreFromPrice), findsNothing);
  });

  testWidgets('a home artist hiding prices is not sent to a salon', (
    tester,
  ) async {
    await _pump(
      tester,
      card(4, workplace: WorkplaceType.mobile, minPrice: null),
    );
    expect(find.text(fr.proPriceHidden('mobile')), findsOneWidget);
    expect(find.text(fr.proPriceHidden('salon')), findsNothing);
  });

  testWidgets('the kids tag follows the customer mix', (tester) async {
    await _pump(tester, card(1, mix: CustomerMix.adultsAndKids));
    expect(find.text(fr.exploreKidsWelcome), findsOneWidget);

    await _pump(tester, card(1, mix: CustomerMix.kidsOnly));
    expect(find.text(fr.customerMixKidsOnly), findsOneWidget);
    expect(find.text(fr.exploreKidsWelcome), findsNothing);

    await _pump(tester, card(1, mix: CustomerMix.adults));
    expect(find.text(fr.customerMixKidsOnly), findsNothing);
    expect(find.text(fr.exploreKidsWelcome), findsNothing);
  });

  testWidgets('Arabic shows the Arabic place names and an LTR price', (
    tester,
  ) async {
    await _pump(
      tester,
      threeCards(arabic: true).first,
      locale: const Locale('ar'),
    );

    expect(find.text('أمين بن علي'), findsOneWidget);
    expect(find.text('باب الزوار · الجزائر'), findsOneWidget);
    expect(find.text('Bab Ezzouar · Alger'), findsNothing);
    expect(find.text(ar.exploreFromPrice), findsOneWidget);
    final price = find.text('600 DA');
    expect(price, findsOneWidget);
    expect(Directionality.of(tester.element(price)), TextDirection.ltr);
  });

  testWidgets('the card is one tappable target of at least 48 dp', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, threeCards().first, onTap: () => taps++);

    final size = tester.getSize(find.byType(ProCardTile));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Amine Benali'));
    expect(taps, 1);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    for (final c in threeLiveCards(arabic: true)) {
      await _pump(tester, c, locale: const Locale('ar'), textScale: 2);
      expect(tester.takeException(), isNull);
    }
    await unmountLive(tester);
  });

  group('live', () {
    testWidgets('open: ring, status with age, count and wait', (tester) async {
      await _pump(tester, card(1, live: custSnap(cardId(1))));

      expect(_statusLine(tester), 'Ouvert · il y a 5 min');
      expect(find.text('3 en attente · ~40 min'), findsOneWidget);
      expect(find.byKey(const Key('liveRing_open')), findsOneWidget);
      await unmountLive(tester);
    });

    testWidgets('a hidden count reads "File ouverte"', (tester) async {
      await _pump(tester, card(1, live: custSnap(cardId(1), waiting: null)));

      expect(find.text('File ouverte · ~40 min'), findsOneWidget);
      expect(find.textContaining('en attente'), findsNothing);
      await unmountLive(tester);
    });

    testWidgets('a paused queue reads "File complète"', (tester) async {
      await _pump(
        tester,
        card(
          1,
          live: custSnap(cardId(1), mode: 'paused', joinBlock: 'paused'),
        ),
      );

      expect(find.text('File complète'), findsOneWidget);
      await unmountLive(tester);
    });

    testWidgets('on break: dashed ring and the return time', (tester) async {
      await _pump(tester, card(1, live: breakSnap(cardId(1))));

      expect(find.byKey(const Key('liveRing_onBreak')), findsOneWidget);
      expect(_statusLine(tester), contains('retour \u206611:30\u2069'));
      await unmountLive(tester);
    });

    testWidgets('closed: no ring and no queue line', (tester) async {
      await _pump(tester, card(1, live: closedSnap(cardId(1))));

      expect(_statusLine(tester), 'Fermé');
      expect(find.byKey(const Key('liveQueueLine')), findsNothing);
      expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
      await unmountLive(tester);
    });

    testWidgets('a broadcast updates a card on screen with no new search', (
      tester,
    ) async {
      final h = await pumpExplore(
        tester,
        explore: FakeExploreRepository(cards: threeLiveCards()),
      );
      expect(find.text('3 en attente · ~40 min'), findsOneWidget);
      final searches = h.explore.queries.length;

      h.live.broadcast(
        cardId(1),
        custLive(cardId(1), waiting: 5, waitMin: 60, version: 4),
      );
      await settleLive(tester);

      expect(find.text('5 en attente · ~60 min'), findsOneWidget);
      expect(find.text('3 en attente · ~40 min'), findsNothing);
      expect(h.explore.queries.length, searches);
      await unmountLive(tester);
    });

    testWidgets('no live object: the card still reads, with no live line', (
      tester,
    ) async {
      await _pump(tester, card(1));

      expect(find.text('Pro 1'), findsOneWidget);
      expect(find.byKey(const Key('liveStatusLine')), findsNothing);
      await unmountLive(tester);
    });
  });
}
