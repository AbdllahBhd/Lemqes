import 'dart:ui';

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

  String? regionName(Locale l) =>
      l.languageCode == 'ar' ? regionNameAr : regionNameFr;
  String? localityName(Locale l) =>
      l.languageCode == 'ar' ? localityNameAr : localityNameFr;
}
