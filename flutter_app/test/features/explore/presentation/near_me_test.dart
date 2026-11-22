import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/origin.dart';
import 'package:material_ui/material_ui.dart';

import '../../geo/data/fake_device_location.dart';
import '../../live/presentation/customer/customer_live_harness.dart';
import 'explore_harness.dart';

/// Alger Centre with its centre, as the real seed carries it.
class _CentresGeo extends FakeGeoRepository {
  @override
  Future<Locality?> locality(int id) async => id == 1601
      ? const Locality(
          id: 1601,
          regionCode: '16',
          nameAr: 'الجزائر الوسطى',
          nameFr: 'Alger Centre',
          lat: 36.77,
          lng: 3.06,
        )
      : null;
}

Future<void> _openChip(WidgetTester tester) async {
  await tester.tap(byKey('locationChip'));
  await settle(tester);
}

Future<void> _tapDeviceOption(WidgetTester tester) async {
  await _openChip(tester);
  await tester.tap(byKey('locationOptionDevice'));
  await settle(tester);
}

void main() {
  setUpAll(registerHarnessFallbacks);

  Future<ExploreHarness> pump(
    WidgetTester tester, {
    FakeDeviceLocation? device,
    List<ProCard>? cards,
    Locale locale = const Locale('fr'),
  }) => pumpExplore(
    tester,
    explore: FakeExploreRepository(cards: cards ?? [card(1), card(2)]),
    deviceLocation: device ?? FakeDeviceLocation(),
    geo: _CentresGeo(),
    locale: locale,
  );

  group('location chip', () {
    testWidgets('opening Explore never asks for permission', (tester) async {
      final device = FakeDeviceLocation();
      await pump(tester, device: device);

      expect(device.requests, isEmpty);
      expect(byKey('locationExplainerAllow'), findsNothing);
      expect(byKey('locationChip'), findsOneWidget);
    });

    testWidgets('"Ma position" shows the explainer before the OS prompt', (
      tester,
    ) async {
      final device = FakeDeviceLocation();
      final h = await pump(tester, device: device);

      await _tapDeviceOption(tester);

      expect(byKey('locationExplainerAllow'), findsOneWidget);
      expect(device.requests, isEmpty);

      await tester.tap(byKey('locationExplainerAllow'));
      await settle(tester);

      expect(device.requests, [false]);
      expect(h.container.read(originProvider), isA<DeviceOrigin>());
      expect(byKey('locationExplainerAllow'), findsNothing);
    });

    testWidgets('"Plus tard" closes the explainer without asking', (
      tester,
    ) async {
      final device = FakeDeviceLocation();
      final h = await pump(tester, device: device);

      await _tapDeviceOption(tester);
      await tester.tap(byKey('locationExplainerBack'));
      await settle(tester);

      expect(device.requests, isEmpty);
      expect(h.container.read(originProvider), isA<NoOrigin>());
      expect(byKey('locationExplainerAllow'), findsNothing);
    });

    testWidgets('a refused OS prompt falls back to the commune picker', (
      tester,
    ) async {
      final device = FakeDeviceLocation(onRequest: DevicePermission.denied);
      await pump(tester, device: device);

      await _tapDeviceOption(tester);
      await tester.tap(byKey('locationExplainerAllow'));
      await settle(tester);

      expect(byKey('pickRegion'), findsOneWidget);
    });

    for (final status in [
      DevicePermission.denied,
      DevicePermission.deniedForever,
      DevicePermission.serviceOff,
    ]) {
      testWidgets('$status goes straight to the commune picker', (
        tester,
      ) async {
        final device = FakeDeviceLocation(status: status);
        await pump(tester, device: device);

        await _tapDeviceOption(tester);

        expect(byKey('locationExplainerAllow'), findsNothing);
        expect(byKey('pickRegion'), findsOneWidget);
        expect(device.requests, isEmpty);
      });
    }

    testWidgets('a granted permission takes the fix without an explainer', (
      tester,
    ) async {
      final device = FakeDeviceLocation(status: DevicePermission.approximate);
      final h = await pump(tester, device: device);

      await _tapDeviceOption(tester);

      expect(byKey('locationExplainerAllow'), findsNothing);
      expect(h.container.read(originProvider), isA<DeviceOrigin>());
      expect(find.text('Ma position'), findsWidgets);
    });

    testWidgets('picking a commune sets the origin and names the chip', (
      tester,
    ) async {
      final h = await pump(tester);

      await _openChip(tester);
      await tester.tap(byKey('locationOptionCommune'));
      await settle(tester);
      await tester.tap(byKey('pickRegion'));
      await settle(tester);
      await tester.tap(byKey('option_16'));
      await settle(tester);
      await tester.tap(byKey('option_1601'));
      await settle(tester);

      final origin = h.container.read(originProvider);
      expect(origin, isA<CommuneOrigin>());
      expect((origin as CommuneOrigin).localityId, 1601);
      expect(h.query.origin, const GeoPoint(36.77, 3.06));
      expect(
        find.descendant(
          of: byKey('locationChip'),
          matching: find.text('Alger Centre'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the chip sets the origin, the place filter keeps filtering', (
      tester,
    ) async {
      final h = await pump(tester);

      await _openChip(tester);
      await tester.tap(byKey('locationOptionCommune'));
      await settle(tester);
      await tester.tap(byKey('pickRegion'));
      await settle(tester);
      await tester.tap(byKey('option_16'));
      await settle(tester);
      await tester.tap(byKey('option_1601'));
      await settle(tester);

      expect(h.query.regionCode, isNull);
      expect(h.query.localityId, isNull);

      h.container.read(exploreQueryProvider.notifier).setRegion('31');
      await settle(tester);

      expect(h.query.regionCode, '31');
      expect(h.query.origin, const GeoPoint(36.77, 3.06));
      expect(h.explore.queries.last.regionCode, '31');
      expect(h.explore.queries.last.origin, const GeoPoint(36.77, 3.06));
    });
  });

  group('rows', () {
    testWidgets('show the distance by the rounding rulings', (tester) async {
      await pump(
        tester,
        cards: [
          card(1, distanceM: 700, placeMode: PlaceMode.exact),
          card(2, distanceM: 1500, placeMode: PlaceMode.area),
          card(3, distanceM: 3000, placeMode: PlaceMode.none),
          card(4, distanceM: 2000, placeMode: PlaceMode.exact),
        ],
      );

      expect(find.text('700 m'), findsOneWidget);
      expect(find.text('1,5 km'), findsOneWidget);
      expect(find.text('≈ 3 km'), findsOneWidget);
      expect(find.text('2 km'), findsOneWidget);
    });

    testWidgets('say when a home artist comes to the customer', (tester) async {
      await pump(
        tester,
        cards: [
          card(1, distanceM: 900, comesToYou: true, placeMode: PlaceMode.area),
          card(2, distanceM: 900, comesToYou: false),
        ],
      );

      expect(find.text('Se déplace jusqu’à vous'), findsOneWidget);
    });

    testWidgets('without an origin there is no distance and the order holds', (
      tester,
    ) async {
      await pump(tester, cards: threeCards());

      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining(RegExp(r'\d m$')), findsNothing);
      expect(find.textContaining('Rien à moins de 10 km'), findsNothing);
      final top = [
        for (final n in ['Amine Benali', 'Yacine Mourad', 'Karim Saadi'])
          tester.getTopLeft(find.text(n)).dy,
      ];
      expect(top, [...top]..sort());
    });

    testWidgets('a blocked viewer reads closed and gets no distance', (
      tester,
    ) async {
      final live = CustomerLive();
      await pumpExplore(
        tester,
        explore: FakeExploreRepository(
          cards: [
            card(
              1,
              live: closedSnap(cardId(1)),
              placeMode: PlaceMode.none,
              distanceM: null,
            ),
          ],
        ),
        deviceLocation: FakeDeviceLocation(),
        geo: _CentresGeo(),
        live: live,
      );

      expect(find.text('Pro 1'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining('≈'), findsNothing);
    });
  });

  group('far notice', () {
    const notice = 'Rien à moins de 10 km — voici les plus proches';

    testWidgets('shows when the nearest pro is over 10 km away', (
      tester,
    ) async {
      await pump(
        tester,
        cards: [
          card(1, distanceM: 12500, placeMode: PlaceMode.exact),
          card(2, distanceM: 20000, placeMode: PlaceMode.exact),
        ],
      );

      expect(find.text(notice), findsOneWidget);
    });

    testWidgets('shows for a result set of commune-only pros', (tester) async {
      await pump(
        tester,
        cards: [
          card(1, distanceM: 15000, placeMode: PlaceMode.none),
          card(2, distanceM: 40000, placeMode: PlaceMode.none),
        ],
      );

      expect(find.text(notice), findsOneWidget);
      expect(find.text('≈ 15 km'), findsOneWidget);
    });

    testWidgets('stays hidden at exactly 10 km and below', (tester) async {
      await pump(
        tester,
        cards: [
          card(1, distanceM: 10000, placeMode: PlaceMode.exact),
          card(2, distanceM: 30000, placeMode: PlaceMode.exact),
        ],
      );

      expect(find.text(notice), findsNothing);
    });
  });
}
