import 'dart:ui';

import '../../live/data/live_models.dart';
import '../../pro/data/pro_models.dart';

class ExploreQuery {
  const ExploreQuery({
    this.text,
    this.regionCode,
    this.localityId,
    this.kidsOnly = false,
    this.category,
  });

  final String? text;
  final String? regionCode;
  final int? localityId;
  final bool kidsOnly;
  final ServiceCategory? category;

  @override
  bool operator ==(Object other) =>
      other is ExploreQuery &&
      other.text == text &&
      other.regionCode == regionCode &&
      other.localityId == localityId &&
      other.kidsOnly == kidsOnly &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(text, regionCode, localityId, kidsOnly, category);
}

/// What location a pro shows (`public.place_mode`).
enum PlaceMode {
  none('none'),
  area('area'),
  exact('exact');

  const PlaceMode(this._db);
  final String _db;

  String toDb() => _db;
  static PlaceMode fromDb(String v) => values.firstWhere((e) => e._db == v);
}

/// One `search_pros` row.
class ProCard {
  const ProCard({
    required this.proId,
    required this.kind,
    required this.displayName,
    required this.workplaceType,
    required this.isVerified,
    this.avatarPath,
    this.workplaceName,
    this.regionCode,
    this.regionNameAr,
    this.regionNameFr,
    this.localityNameAr,
    this.localityNameFr,
    this.customerMix,
    this.minPriceDzd,
    this.live,
    this.distanceM,
    this.placeMode,
    this.lat,
    this.lng,
    this.areaRadiusM,
    this.landmark,
    this.localityId,
    this.comesToYou,
  });

  factory ProCard.fromRow(Map<String, Object?> r) => ProCard(
    proId: r['pro_id']! as String,
    kind: ProKind.fromDb(r['kind']! as String),
    displayName: r['display_name']! as String,
    avatarPath: r['avatar_path'] as String?,
    workplaceType: WorkplaceType.fromDb(r['workplace_type']! as String),
    workplaceName: r['workplace_name'] as String?,
    regionCode: r['region_code'] as String?,
    regionNameAr: r['region_name_ar'] as String?,
    regionNameFr: r['region_name_fr'] as String?,
    localityNameAr: r['locality_name_ar'] as String?,
    localityNameFr: r['locality_name_fr'] as String?,
    customerMix: r['customer_mix'] == null
        ? null
        : CustomerMix.fromDb(r['customer_mix']! as String),
    minPriceDzd: r['min_price_dzd'] as int?,
    isVerified: r['is_verified']! as bool,
    live: r['live'] == null
        ? null
        : LiveSnapshot.fromJson(r['live']! as Map<String, Object?>),
    distanceM: r['distance_m'] as int?,
    placeMode: r['place_mode'] == null
        ? null
        : PlaceMode.fromDb(r['place_mode']! as String),
    // JSON drops the fraction of a whole number, so 3.0 can arrive as 3.
    lat: (r['lat'] as num?)?.toDouble(),
    lng: (r['lng'] as num?)?.toDouble(),
    areaRadiusM: r['area_radius_m'] as int?,
    landmark: r['landmark'] as String?,
    localityId: r['locality_id'] as int?,
    comesToYou: r['comes_to_you'] as bool?,
  );

  final String proId;
  final ProKind kind;
  final String displayName;
  final String? avatarPath;
  final WorkplaceType workplaceType;
  final String? workplaceName;
  final String? regionCode;
  final String? regionNameAr;
  final String? regionNameFr;
  final String? localityNameAr;
  final String? localityNameFr;
  final CustomerMix? customerMix;

  /// Null when the pro hides prices or has no service yet.
  final int? minPriceDzd;
  final bool isVerified;

  /// The pro's live state when the page was searched; the card follows
  /// `proLiveProvider`, which this seeds.
  final LiveSnapshot? live;

  /// Display-rounded metres from the search origin; null without an origin,
  /// for a pro with no point, or for a pro that blocked the reader.
  final int? distanceM;

  /// Null when the reader cannot see the pro's place (blocked).
  final PlaceMode? placeMode;

  /// The shown point (pin or area centre); null for [PlaceMode.none].
  final double? lat;
  final double? lng;
  final int? areaRadiusM;
  final String? landmark;
  final int? localityId;

  /// A mobile pro whose service radius reaches the search origin.
  final bool? comesToYou;

  String? regionName(Locale l) =>
      l.languageCode == 'ar' ? regionNameAr : regionNameFr;
  String? localityName(Locale l) =>
      l.languageCode == 'ar' ? localityNameAr : localityNameFr;
}
