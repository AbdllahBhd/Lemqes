import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lemqes/features/explore/presentation/explore_map_view.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';

void main() {
  // About 300 m apart in Algiers: one cell at z12, far apart at z17.
  const a = LatLng(36.76, 3.0588);
  const b = LatLng(36.763, 3.0588);
  const far = LatLng(36.36, 6.61); // Constantine

  List<GridPoint<String>> points() => [
    const GridPoint(a, 'a'),
    const GridPoint(b, 'b', weight: 3),
    const GridPoint(far, 'far'),
  ];

  group('clusterByGrid', () {
    test('merges the points that fall in one cell', () {
      final clusters = clusterByGrid(points(), 12, 64);
      expect(clusters, hasLength(2));
      final algiers = clusters.firstWhere((c) => c.members.length == 2);
      expect(algiers.members.map((m) => m.item), ['a', 'b']);
      // Weighted: a commune pin of three pros counts three.
      expect(algiers.count, 4);
      expect(
        algiers.point.latitude,
        closeTo((a.latitude + 3 * b.latitude) / 4, 1e-9),
      );
    });

    test('splits them again when zoomed in', () {
      final clusters = clusterByGrid(points(), 17, 64);
      expect(clusters, hasLength(3));
      expect(clusters.every((c) => c.members.length == 1), isTrue);
      expect(clusters.map((c) => c.point), [a, b, far]);
    });

    test('a larger cell merges more', () {
      expect(clusterByGrid(points(), 17, 64), hasLength(3));
      expect(clusterByGrid(points(), 17, 4096), hasLength(2));
    });

    test('preserves the counts at every zoom', () {
      for (var z = 5.0; z <= 18; z++) {
        final clusters = clusterByGrid(points(), z, 64);
        expect(clusters.fold(0, (s, c) => s + c.count), 5, reason: 'z$z');
        expect(clusters.expand((c) => c.members).map((m) => m.item).toSet(), {
          'a',
          'b',
          'far',
        });
      }
    });

    test('no points, no clusters', () {
      expect(clusterByGrid<String>(const [], 12, 64), isEmpty);
    });
  });

  group('clampToSearchBox', () {
    test('keeps a box within 8 degrees as it is', () {
      const box = GeoBounds(2.9, 36.6, 3.2, 36.9);
      final (clamped, wasClamped) = clampToSearchBox(box);
      expect(clamped, box);
      expect(wasClamped, isFalse);
    });

    test('shrinks a wider box around its centre', () {
      const box = GeoBounds(-2, 30, 10, 40);
      final (clamped, wasClamped) = clampToSearchBox(box);
      expect(wasClamped, isTrue);
      expect(clamped.maxLng - clamped.minLng, lessThanOrEqualTo(8));
      expect(clamped.maxLat - clamped.minLat, lessThanOrEqualTo(8));
      expect((clamped.minLng + clamped.maxLng) / 2, closeTo(4, 1e-9));
      expect((clamped.minLat + clamped.maxLat) / 2, closeTo(35, 1e-9));
    });
  });

  group('ExploreLocation', () {
    test('round-trips the map camera through the location', () {
      const loc = ExploreLocation.map(GeoPoint(36.75, 3.05), 13.5);
      final back = ExploreLocation.fromUri(Uri.parse(loc.toLocation()));
      expect(back.view, ExploreView.map);
      expect(back.center, const GeoPoint(36.75, 3.05));
      expect(back.zoom, 13.5);
      expect(
        loc.toLocation(),
        '/explore?view=map&lat=36.75000&lng=3.05000&z=13.50',
      );
    });

    test('reads anything but view=map as the list', () {
      expect(
        ExploreLocation.fromUri(Uri.parse('/home')).view,
        ExploreView.list,
      );
      expect(
        ExploreLocation.fromUri(Uri.parse('/explore?view=grid')).view,
        ExploreView.list,
      );
      expect(ExploreLocation.list.toLocation(), '/home');
    });

    test('drops an unusable camera and clamps the zoom', () {
      final bad = ExploreLocation.fromUri(
        Uri.parse('/explore?view=map&lat=abc&lng=200&z=40'),
      );
      expect(bad.view, ExploreView.map);
      expect(bad.center, isNull);
      expect(bad.zoom, 18);
    });
  });
}
