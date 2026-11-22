import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:material_ui/material_ui.dart';

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

    testWidgets('explore map $lang', (tester) async {
      await _withShadows(() async {
        // Each marker kind: exact pins with open, break and closed dots, a
        // cluster of two, an area circle and commune pins with counts.
        final cards = [
          card(
            1,
            placeMode: PlaceMode.exact,
            lat: 36.757,
            lng: 3.068,
            live: custSnap(cardId(1)),
          ),
          card(
            2,
            placeMode: PlaceMode.exact,
            lat: 36.781,
            lng: 3.072,
            live: breakSnap(cardId(2)),
          ),
          card(
            3,
            placeMode: PlaceMode.exact,
            lat: 36.748,
            lng: 3.032,
            live: closedSnap(cardId(3)),
          ),
          card(4, placeMode: PlaceMode.exact, lat: 36.734, lng: 3.074),
          card(5, placeMode: PlaceMode.exact, lat: 36.7345, lng: 3.0752),
          card(
            6,
            placeMode: PlaceMode.area,
            lat: 36.742,
            lng: 3.052,
            areaRadiusM: 1000,
          ),
          for (final i in [7, 8, 9])
            card(i, placeMode: PlaceMode.none, localityId: 1601),
          card(10, placeMode: PlaceMode.none, localityId: 1602),
        ];
        await pumpExplore(
          tester,
          explore: FakeExploreRepository(
            answer: (q, offset) => q.bbox == null || offset > 0 ? [] : cards,
          ),
          location: '/explore?view=map&lat=36.7600&lng=3.0550&z=13',
          locale: locale,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/explore_map_$lang.png'),
        );
      });
      await unmountLive(tester);
    });
  }
}
