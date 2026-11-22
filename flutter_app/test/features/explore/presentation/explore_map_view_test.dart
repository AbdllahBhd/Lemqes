import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/explore/presentation/explore_map_view.dart';
import 'package:lemqes/features/explore/presentation/pro_card_tile.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/map/presentation/commune_pin.dart';
import 'package:material_ui/material_ui.dart';

import '../../geo/data/fake_device_location.dart';
import '../../live/presentation/customer/customer_live_harness.dart';
import 'explore_harness.dart';

const _mapAt = '/explore?view=map&lat=36.7650&lng=3.0550&z=13';

/// One of each marker kind around Alger Centre: an exact pin, an area, two
/// commune-only pros in Alger Centre (1601) and one in Bab El Oued (1602).
List<ProCard> mapCards() => [
  card(
    1,
    name: 'Amine Benali',
    placeMode: PlaceMode.exact,
    lat: 36.76,
    lng: 3.06,
    live: custSnap(cardId(1)),
  ),
  card(
    2,
    name: 'Yacine Mourad',
    placeMode: PlaceMode.area,
    lat: 36.745,
    lng: 3.045,
    areaRadiusM: 1000,
  ),
  card(3, name: 'Karim Saadi', placeMode: PlaceMode.none, localityId: 1601),
  card(4, name: 'Nadir Ould', placeMode: PlaceMode.none, localityId: 1601),
  card(5, name: 'Sofiane Rahmi', placeMode: PlaceMode.none, localityId: 1602),
];

/// List searches answer [list]; map searches (with a box) answer [map].
FakeExploreRepository _repo({
  List<ProCard> list = const [],
  List<ProCard>? map,
}) => FakeExploreRepository(
  answer: (q, offset) =>
      offset > 0 ? const [] : (q.bbox == null ? list : (map ?? mapCards())),
);

List<ExploreQuery> _mapQueries(ExploreHarness h) => [
  for (final q in h.explore.queries)
    if (q.bbox != null) q,
];

GeoPoint _centreOf(GeoBounds b) =>
    GeoPoint((b.minLat + b.maxLat) / 2, (b.minLng + b.maxLng) / 2);

Future<void> _pan(WidgetTester tester, Offset by) async {
  await tester.drag(find.byKey(const Key('exploreMap')), by);
  await settle(tester);
}

void main() {
  setUpAll(registerHarnessFallbacks);

  testWidgets('the toggle keeps the text, the filters and the origin', (
    tester,
  ) async {
    final h = await pumpExplore(
      tester,
      explore: _repo(list: threeCards()),
      deviceLocation: FakeDeviceLocation(status: DevicePermission.approximate),
    );
    await tester.enterText(byKey('exploreSearch'), 'amine');
    h.container.read(exploreQueryProvider.notifier).setKidsOnly(true);
    await settle(tester);
    final before = h.query;
    expect(before.origin, isNotNull);

    await tester.tap(byKey('exploreViewToggle'));
    await settle(tester);
    expect(byKey('exploreMap'), findsOneWidget);
    expect(h.router.state.uri.path, '/explore');
    expect(h.router.state.uri.queryParameters['view'], 'map');
    // The shared query never carries the box: the list is not re-searched.
    expect(h.query, before);
    final search = _mapQueries(h).single;
    expect(search.text, 'amine');
    expect(search.kidsOnly, isTrue);
    expect(search.origin, before.origin);
    expect(h.explore.limits.last, 101);
    // No camera in the route: the map opens on the origin.
    final centre = _centreOf(search.bbox!);
    expect(centre.lat, closeTo(before.origin!.lat, 0.01));
    expect(centre.lng, closeTo(before.origin!.lng, 0.01));

    await tester.tap(byKey('exploreViewToggle'));
    await settle(tester);
    expect(byKey('exploreMap'), findsNothing);
    expect(h.location, '/home');
    expect(h.query, before);
    expect(find.text('amine'), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('the map camera round-trips through the route', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: _repo(),
      location: '/explore?view=map&lat=36.7000&lng=3.1000&z=12',
    );
    final first = _centreOf(_mapQueries(h).single.bbox!);
    expect(first.lat, closeTo(36.70, 0.01));
    expect(first.lng, closeTo(3.10, 1e-3));

    await _pan(tester, const Offset(-150, 0));
    await tester.tap(byKey('exploreMapSearchArea'));
    await settle(tester);
    final params = h.router.state.uri.queryParameters;
    expect(params['view'], 'map');
    expect(params['z'], '12.00');
    final second = _centreOf(_mapQueries(h).last.bbox!);
    expect(double.parse(params['lng']!), closeTo(second.lng, 1e-3));
    expect(double.parse(params['lng']!), greaterThan(3.11));

    // A new location while the map is open moves it and searches there.
    h.router.go('/explore?view=map&lat=36.8000&lng=3.0000&z=12');
    await settle(tester);
    final third = _centreOf(_mapQueries(h).last.bbox!);
    expect(_mapQueries(h), hasLength(3));
    expect(third.lat, closeTo(36.80, 0.01));
    expect(third.lng, closeTo(3.00, 1e-3));
    await unmountLive(tester);
  });

  testWidgets('exact pins, area polygons and commune pins with counts', (
    tester,
  ) async {
    await pumpExplore(tester, explore: _repo(), location: _mapAt);
    expect(byKey('exactPin_${cardId(1)}'), findsOneWidget);
    expect(byKey('areaPin_${cardId(2)}'), findsOneWidget);
    final polygons = tester
        .widgetList<PolygonLayer>(find.byType(PolygonLayer))
        .expand((l) => l.polygons)
        .toList();
    expect(polygons, hasLength(1));
    expect(polygons.single.points.length, greaterThanOrEqualTo(72));
    expect(find.byType(CircleLayer), findsNothing);

    // Grouped by commune, at the commune centre.
    final centre = tester.widget<CommunePin>(
      find.descendant(
        of: byKey('communePin_1601'),
        matching: find.byType(CommunePin),
      ),
    );
    expect(centre.count, 2);
    final babElOued = tester.widget<CommunePin>(
      find.descendant(
        of: byKey('communePin_1602'),
        matching: find.byType(CommunePin),
      ),
    );
    expect(babElOued.count, 1);
    // The commune pros have no pin of their own.
    expect(byKey('exactPin_${cardId(3)}'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('close pins merge into a cluster that zooms in on tap', (
    tester,
  ) async {
    final h = await pumpExplore(
      tester,
      explore: _repo(
        map: [
          for (final (i, d) in [0.0, 0.0008, 0.0016].indexed)
            card(10 + i, placeMode: PlaceMode.exact, lat: 36.76 + d, lng: 3.06),
        ],
      ),
      location: _mapAt,
    );
    final cluster = find.byType(MapClusterPin);
    expect(cluster, findsOneWidget);
    expect(tester.widget<MapClusterPin>(cluster).count, 3);
    expect(find.text('3'), findsOneWidget);
    expect(byKey('exactPin_${cardId(10)}'), findsNothing);

    for (var i = 0; i < 3 && cluster.evaluate().isNotEmpty; i++) {
      await tester.tap(cluster.first);
      await settle(tester);
    }
    expect(cluster, findsNothing);
    for (final i in [10, 11, 12]) {
      expect(byKey('exactPin_${cardId(i)}'), findsOneWidget);
    }
    // Zooming in to a cluster is a client move: no new search, no button.
    expect(_mapQueries(h), hasLength(1));
    expect(byKey('exploreMapSearchArea'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('"Rechercher dans cette zone" after a pan sends one box', (
    tester,
  ) async {
    final h = await pumpExplore(tester, explore: _repo(), location: _mapAt);
    expect(_mapQueries(h), hasLength(1));
    expect(byKey('exploreMapSearchArea'), findsNothing);

    await _pan(tester, const Offset(-120, 40));
    await _pan(tester, const Offset(60, -80));
    // Panning never searches.
    expect(_mapQueries(h), hasLength(1));
    expect(find.text('Rechercher dans cette zone'), findsOneWidget);

    await tester.tap(byKey('exploreMapSearchArea'));
    await settle(tester);
    expect(_mapQueries(h), hasLength(2));
    expect(_mapQueries(h).last.bbox, isNot(_mapQueries(h).first.bbox));
    expect(h.explore.offsets.last, 0);
    expect(h.explore.limits.last, 101);
    expect(byKey('exploreMapSearchArea'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('a 101st row says "Zoomez pour voir plus"', (tester) async {
    List<ProCard> rows(int n) => [
      for (var i = 0; i < n; i++)
        card(
          100 + i,
          placeMode: PlaceMode.exact,
          lat: 36.74 + (i ~/ 10) * 0.004,
          lng: 3.03 + (i % 10) * 0.005,
        ),
    ];
    await pumpExplore(
      tester,
      explore: _repo(map: rows(101)),
      location: _mapAt,
    );
    expect(find.text('Zoomez pour voir plus'), findsOneWidget);
    await unmountLive(tester);

    await pumpExplore(
      tester,
      explore: _repo(map: rows(100)),
      location: _mapAt,
    );
    expect(find.text('Zoomez pour voir plus'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('a tapped pin shows the same card as the list', (tester) async {
    await pumpExplore(tester, explore: _repo(), location: _mapAt);
    await tester.tap(byKey('exactPin_${cardId(1)}'));
    await settle(tester);
    expect(find.byType(ProCardTile), findsOneWidget);
    expect(byKey('proCard_${cardId(1)}'), findsOneWidget);
    expect(byKey('directions'), findsOneWidget);
    await tester.tapAt(const Offset(195, 120));
    await settle(tester);

    await tester.tap(byKey('areaPin_${cardId(2)}'));
    await settle(tester);
    expect(byKey('proCard_${cardId(2)}'), findsOneWidget);
    // Directions only to an exact pin.
    expect(byKey('directions'), findsNothing);
    await tester.tapAt(const Offset(195, 120));
    await settle(tester);

    await tester.tap(byKey('communePin_1601'));
    await settle(tester);
    expect(find.text('Alger Centre'), findsOneWidget);
    expect(byKey('proCard_${cardId(3)}'), findsOneWidget);
    expect(byKey('proCard_${cardId(4)}'), findsOneWidget);
    expect(byKey('directions'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('a pro the box search leaves out is not on the map', (
    tester,
  ) async {
    // A pro that blocked the viewer has no search point: the server leaves
    // it out of every box, while the list still shows it as closed.
    final blocked = card(
      9,
      placeMode: PlaceMode.none,
      live: closedSnap(cardId(9)),
    );
    await pumpExplore(
      tester,
      explore: _repo(list: [blocked], map: mapCards()),
      location: _mapAt,
    );
    expect(byKey('exactPin_${cardId(9)}'), findsNothing);
    expect(byKey('areaPin_${cardId(9)}'), findsNothing);
    await tester.tap(byKey('communePin_1601'));
    await settle(tester);
    expect(byKey('proCard_${cardId(9)}'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('"Itinéraire" opens Google Maps, Waze is in the overflow', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpExplore(
      tester,
      explore: _repo(),
      location: _mapAt,
      directionsLauncher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(byKey('exactPin_${cardId(1)}'));
    await settle(tester);
    expect(find.text('Itinéraire'), findsOneWidget);
    await tester.tap(byKey('directions'));
    await settle(tester);
    expect(opened, [
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=36.76%2C3.06',
      ),
    ]);

    await tester.tap(byKey('directionsMore'));
    await settle(tester);
    await tester.tap(byKey('directionsWaze'));
    await settle(tester);
    expect(
      opened.last,
      Uri.parse('https://waze.com/ul?ll=36.76,3.06&navigate=yes'),
    );
    await unmountLive(tester);
  });

  testWidgets('a failed launch says so', (tester) async {
    await pumpExplore(
      tester,
      explore: _repo(),
      location: _mapAt,
      directionsLauncher: (_) async => false,
    );
    await tester.tap(byKey('exactPin_${cardId(1)}'));
    await settle(tester);
    await tester.tap(byKey('directions'));
    await settle(tester);
    expect(find.text('Impossible d’ouvrir l’itinéraire.'), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('the profile opened from an exact pin offers directions', (
    tester,
  ) async {
    final opened = <Uri>[];
    final h = await pumpExplore(
      tester,
      explore: _repo(),
      pros: PublicProRepository(
        listed: {
          cardId(1): publicBarber(id: cardId(1)),
          cardId(2): publicBarber(id: cardId(2)),
        },
      ),
      location: _mapAt,
      directionsLauncher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(byKey('exactPin_${cardId(1)}'));
    await settle(tester);
    await tester.tap(byKey('proCard_${cardId(1)}'));
    await settle(tester);
    expect(h.location, '/pro/${cardId(1)}');
    await tester.ensureVisible(byKey('directions'));
    await tester.tap(byKey('directions'));
    await settle(tester);
    expect(opened.single.host, 'www.google.com');

    // An area pro's profile has none.
    h.router.pop();
    await settle(tester);
    await tester.tap(byKey('areaPin_${cardId(2)}'));
    await settle(tester);
    await tester.tap(byKey('proCard_${cardId(2)}'));
    await settle(tester);
    expect(h.location, '/pro/${cardId(2)}');
    expect(byKey('directions'), findsNothing);
    await unmountLive(tester);
  });

  testWidgets('a profile opened by link has no directions', (tester) async {
    await pumpExplore(
      tester,
      pros: PublicProRepository(
        listed: {cardId(1): publicBarber(id: cardId(1))},
      ),
      location: '/pro/${cardId(1)}',
    );
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(byKey('directions'), findsNothing);
    await unmountLive(tester);
  });
}
