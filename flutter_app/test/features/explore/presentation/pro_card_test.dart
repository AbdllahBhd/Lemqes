import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/presentation/pro_avatar.dart';
import 'package:lemqes/features/explore/presentation/pro_card_tile.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:material_ui/material_ui.dart';

import '../../pro/presentation/pro_test_host.dart';
import 'explore_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  ProCard c, {
  Locale locale = const Locale('fr'),
  double textScale = 1,
  VoidCallback? onTap,
}) => pumpLocalized(
  tester,
  ProviderScope(
    overrides: [photoUploaderProvider.overrideWithValue(FakePhotoUploader())],
    child: ProCardTile(card: c, onTap: onTap ?? () {}),
  ),
  locale: locale,
  textScale: textScale,
);

void main() {
  final fr = AppLocalizationsFr();
  final ar = AppLocalizationsAr();

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
    for (final c in threeCards(arabic: true)) {
      await _pump(tester, c, locale: const Locale('ar'), textScale: 2);
      expect(tester.takeException(), isNull);
    }
  });
}
