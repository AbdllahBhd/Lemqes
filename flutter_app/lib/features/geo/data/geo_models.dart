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
  });

  factory Locality.fromRow(Map<String, Object?> row) => Locality(
    id: row['id']! as int,
    regionCode: row['region_code']! as String,
    nameAr: row['name_ar']! as String,
    nameFr: row['name_fr']! as String,
  );

  final int id;
  final String regionCode;
  final String nameAr;
  final String nameFr;

  String name(Locale l) => _pick(l, nameAr, nameFr);
}
