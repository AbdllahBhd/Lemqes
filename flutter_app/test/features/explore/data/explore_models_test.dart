import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_api.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';

Map<String, Object?> _row([Map<String, Object?> extra = const {}]) => {
  'pro_id': 'p1',
  'kind': 'barber',
  'display_name': 'Salon Amine',
  'workplace_type': 'salon',
  'is_verified': false,
  ...extra,
};

void main() {
  group('ProCard.fromRow near-me columns', () {
    test('distance_m', () {
      expect(ProCard.fromRow(_row({'distance_m': 1500})).distanceM, 1500);
    });

    test('place_mode', () {
      expect(
        ProCard.fromRow(_row({'place_mode': 'none'})).placeMode,
        PlaceMode.none,
      );
      expect(
        ProCard.fromRow(_row({'place_mode': 'area'})).placeMode,
        PlaceMode.area,
      );
      expect(
        ProCard.fromRow(_row({'place_mode': 'exact'})).placeMode,
        PlaceMode.exact,
      );
    });

    test('lat and lng, whole numbers included', () {
      final card = ProCard.fromRow(_row({'lat': 36.76846, 'lng': 3}));
      expect(card.lat, 36.76846);
      expect(card.lng, 3.0);
    });

    test('area_radius_m', () {
      expect(ProCard.fromRow(_row({'area_radius_m': 1000})).areaRadiusM, 1000);
    });

    test('landmark', () {
      expect(
        ProCard.fromRow(_row({'landmark': 'Face à la poste'})).landmark,
        'Face à la poste',
      );
    });

    test('locality_id', () {
      expect(ProCard.fromRow(_row({'locality_id': 1601})).localityId, 1601);
    });

    test('comes_to_you', () {
      expect(ProCard.fromRow(_row({'comes_to_you': true})).comesToYou, true);
      expect(ProCard.fromRow(_row({'comes_to_you': false})).comesToYou, false);
    });

    test('absent or null columns read as null', () {
      for (final row in [
        _row(),
        _row({
          'distance_m': null,
          'place_mode': null,
          'lat': null,
          'lng': null,
          'area_radius_m': null,
          'landmark': null,
          'locality_id': null,
          'comes_to_you': null,
        }),
      ]) {
        final card = ProCard.fromRow(row);
        expect(card.distanceM, isNull);
        expect(card.placeMode, isNull);
        expect(card.lat, isNull);
        expect(card.lng, isNull);
        expect(card.areaRadiusM, isNull);
        expect(card.landmark, isNull);
        expect(card.localityId, isNull);
        expect(card.comesToYou, isNull);
      }
    });
  });

  group('SupabaseExploreApi.rpcParams', () {
    test('leaves the near-me arguments out when unset', () {
      expect(
        SupabaseExploreApi.rpcParams({
          'p_query': null,
          'p_limit': 30,
          'p_origin_lat': null,
          'p_origin_lng': null,
          'p_bbox': null,
        }),
        {'p_query': null, 'p_limit': 30},
      );
    });

    test('sends them when set', () {
      expect(
        SupabaseExploreApi.rpcParams({
          'p_origin_lat': 36.768,
          'p_origin_lng': 3.091,
          'p_bbox': [3.0, 36.74, 3.2, 36.8],
        }),
        {
          'p_origin_lat': 36.768,
          'p_origin_lng': 3.091,
          'p_bbox': [3.0, 36.74, 3.2, 36.8],
        },
      );
    });
  });
}
