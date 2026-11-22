import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../geo/data/fake_device_location.dart';
import '../../live/presentation/customer/customer_live_harness.dart';
import 'explore_harness.dart';

/// flutter_test flattens shadows by default; the soft shadow is the design.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;
    final arabic = lang == 'ar';

    testWidgets('explore list near me $lang', (tester) async {
      await _withShadows(() async {
        final base = threeCards(arabic: arabic);
        final cards = [
          card(
            1,
            name: base[0].displayName,
            verified: true,
            workplaceName: base[0].workplaceName,
            distanceM: 700,
            placeMode: PlaceMode.exact,
            live: custSnap(cardId(1)),
          ),
          card(
            3,
            name: base[2].displayName,
            workplace: WorkplaceType.mobile,
            minPrice: 1500,
            distanceM: 1500,
            placeMode: PlaceMode.area,
            comesToYou: true,
            live: closedSnap(cardId(3)),
          ),
          card(
            2,
            name: base[1].displayName,
            mix: CustomerMix.adultsAndKids,
            minPrice: null,
            distanceM: 3000,
            placeMode: PlaceMode.none,
            live: breakSnap(cardId(2)),
          ),
        ];
        await pumpExplore(
          tester,
          explore: FakeExploreRepository(cards: cards),
          deviceLocation: FakeDeviceLocation(
            status: DevicePermission.approximate,
          ),
          locale: locale,
          size: const Size(390, 1000),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/explore_list_near_$lang.png'),
        );
      });
      await unmountLive(tester);
    });
  }
}
