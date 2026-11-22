import 'dart:ui';

// Arabic UI shows Arabic names; every other locale (fr, en, kab) shows French.
String _pick(Locale l, String ar, String fr) =>
    l.languageCode == 'ar' ? ar : fr;

class Region {
  const Region({
    required this.countryCode,
    required this.code,
    required this.nameAr,
    required this.nameFr,
    this.parentCode,
  });

  factory Region.fromRow(Map<String, Object?> row) => Region(
    countryCode: row['country_code']! as String,
    code: row['code']! as String,
    parentCode: row['parent_code'] as String?,
    nameAr: row['name_ar']! as String,
    nameFr: row['name_fr']! as String,
  );

  final String countryCode;
  final String code;
  final String? parentCode;
  final String nameAr;
  final String nameFr;

  String name(Locale l) => _pick(l, nameAr, nameFr);
}

class Locality {
  const Locality({
    required this.id,
    required this.regionCode,
    required this.nameAr,
    required this.nameFr,
    this.lat,
    this.lng,
  });

  factory Locality.fromRow(Map<String, Object?> row) => Locality(
    id: row['id']! as int,
    regionCode: row['region_code']! as String,
    nameAr: row['name_ar']! as String,
    nameFr: row['name_fr']! as String,
    // JSON drops the fraction of a whole number, so 3.0 can arrive as 3.
    lat: (row['lat'] as num?)?.toDouble(),
    lng: (row['lng'] as num?)?.toDouble(),
  );

  final int id;
  final String regionCode;
  final String nameAr;
  final String nameFr;

  /// The commune centre; null for a row without coordinates.
  final double? lat;
  final double? lng;

  String name(Locale l) => _pick(l, nameAr, nameFr);
}

/// A WGS84 point in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// A map view's box, in the order `search_pros` takes it.
class GeoBounds {
  const GeoBounds(this.minLng, this.minLat, this.maxLng, this.maxLat);

  final double minLng;
  final double minLat;
  final double maxLng;
  final double maxLat;

  /// `p_bbox`: `[min_lng, min_lat, max_lng, max_lat]`.
  List<double> toRpc() => [minLng, minLat, maxLng, maxLat];

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.minLng == minLng &&
      other.minLat == minLat &&
      other.maxLng == maxLng &&
      other.maxLat == maxLat;

  @override
  int get hashCode => Object.hash(minLng, minLat, maxLng, maxLat);
}
