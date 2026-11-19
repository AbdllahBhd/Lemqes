import 'dart:ui';

import 'package:material_ui/material_ui.dart' show TimeOfDay;

import '../../account/data/account.dart';

enum ProKind {
  barber('barber'),
  homeArtist('home_artist');

  const ProKind(this._db);
  final String _db;

  String toDb() => _db;
  static ProKind fromDb(String v) => values.firstWhere((e) => e._db == v);

  AppRole get role => switch (this) {
    barber => AppRole.barber,
    homeArtist => AppRole.homeArtist,
  };

  static ProKind? forRole(AppRole role) => switch (role) {
    AppRole.barber => barber,
    AppRole.homeArtist => homeArtist,
    _ => null,
  };
}

enum WorkplaceType {
  salon('salon'),
  ownStudio('own_studio'),
  mobile('mobile');

  const WorkplaceType(this._db);
  final String _db;

  String toDb() => _db;
  static WorkplaceType fromDb(String v) => values.firstWhere((e) => e._db == v);
}

enum CustomerMix {
  adults('adults'),
  adultsAndKids('adults_and_kids'),
  kidsOnly('kids_only');

  const CustomerMix(this._db);
  final String _db;

  String toDb() => _db;
  static CustomerMix fromDb(String v) => values.firstWhere((e) => e._db == v);
}

enum PhoneVisibility {
  public('public'),
  followers('followers'),
  hidden('hidden');

  const PhoneVisibility(this._db);
  final String _db;

  String toDb() => _db;
  static PhoneVisibility fromDb(String v) =>
      values.firstWhere((e) => e._db == v);
}

enum ServiceCategory {
  hair('hair'),
  beard('beard'),
  coloring('coloring'),
  nails('nails'),
  skincare('skincare'),
  makeup('makeup'),
  spa('spa');

  const ServiceCategory(this._db);
  final String _db;

  String toDb() => _db;
  static ServiceCategory fromDb(String v) =>
      values.firstWhere((e) => e._db == v);
}

/// What still blocks publishing; [dbKey] is the token `publish_pro_profile`
/// puts in the error DETAIL.
enum ProfileGap {
  locality('locality'),
  customerMix('customer_mix'),
  services('services'),
  hours('hours');

  const ProfileGap(this.dbKey);
  final String dbKey;
}

class ServicePreset {
  const ServicePreset({
    required this.key,
    required this.space,
    required this.home,
    required this.category,
    required this.nameAr,
    required this.nameFr,
    required this.nameEn,
    required this.nameKab,
    required this.defaultPriceDzd,
    required this.defaultDurationMin,
    required this.sort,
  });

  factory ServicePreset.fromRow(Map<String, Object?> r) => ServicePreset(
    key: r['key']! as String,
    space: Space.fromDb(r['space']! as String),
    home: r['home']! as bool,
    category: ServiceCategory.fromDb(r['category']! as String),
    nameAr: r['name_ar']! as String,
    nameFr: r['name_fr']! as String,
    nameEn: r['name_en']! as String,
    nameKab: r['name_kab']! as String,
    defaultPriceDzd: r['default_price_dzd']! as int,
    defaultDurationMin: r['default_duration_min']! as int,
    sort: r['sort']! as int,
  );

  final String key;
  final Space space;
  final bool home;
  final ServiceCategory category;
  final String nameAr;
  final String nameFr;
  final String nameEn;
  final String nameKab;
  final int defaultPriceDzd;
  final int defaultDurationMin;
  final int sort;

  String name(Locale l) => switch (l.languageCode) {
    'ar' => nameAr,
    'en' => nameEn,
    'kab' => nameKab,
    _ => nameFr,
  };
}

class ProService {
  const ProService({
    required this.id,
    required this.category,
    required this.priceDzd,
    required this.durationMin,
    this.presetKey,
    this.customName,
    this.active = true,
    this.sort = 0,
  });

  factory ProService.fromRow(Map<String, Object?> r) => ProService(
    id: r['id']! as String,
    presetKey: r['preset_key'] as String?,
    customName: r['name'] as String?,
    category: ServiceCategory.fromDb(r['category']! as String),
    priceDzd: r['price_dzd'] as int?,
    durationMin: r['duration_min']! as int,
    // The customer RPC only returns active services and omits the flag.
    active: r['active'] as bool? ?? true,
    sort: r['sort'] as int? ?? 0,
  );

  final String id;
  final String? presetKey;
  final String? customName;
  final ServiceCategory category;

  /// Null only in a customer's view of a pro who hides prices.
  final int? priceDzd;
  final int durationMin;
  final bool active;
  final int sort;

  String displayName(Locale l, Map<String, ServicePreset> presets) {
    final custom = customName;
    if (custom != null) return custom;
    final preset = presets[presetKey];
    return preset?.name(l) ?? presetKey ?? '';
  }
}

class ProServiceDraft {
  const ProServiceDraft({
    required this.category,
    required this.priceDzd,
    required this.durationMin,
    this.id,
    this.presetKey,
    this.customName,
    this.active = true,
    this.sort,
  });

  final String? id;
  final String? presetKey;
  final String? customName;
  final ServiceCategory category;
  final int priceDzd;
  final int durationMin;
  final bool active;

  /// The place in the list; null keeps the stored one.
  final int? sort;

  ProServiceDraft placedAt(int sort) => ProServiceDraft(
    id: id,
    presetKey: presetKey,
    customName: customName,
    category: category,
    priceDzd: priceDzd,
    durationMin: durationMin,
    active: active,
    sort: sort,
  );

  Map<String, Object?> toDb() => {
    'preset_key': presetKey,
    'name': customName,
    'category': category.toDb(),
    'price_dzd': priceDzd,
    'duration_min': durationMin,
    'active': active,
    'sort': ?sort,
  };
}

class DayHours {
  const DayHours({
    required this.weekday,
    required this.opens,
    required this.closes,
    this.breakStart,
    this.breakEnd,
  });

  factory DayHours.fromRow(Map<String, Object?> r) => DayHours(
    weekday: r['weekday']! as int,
    opens: _parseTime(r['opens']! as String),
    closes: _parseTime(r['closes']! as String),
    breakStart: _parseTimeOrNull(r['break_start']),
    breakEnd: _parseTimeOrNull(r['break_end']),
  );

  /// ISO weekday, 1 = Monday .. 7 = Sunday.
  final int weekday;
  final TimeOfDay opens;
  final TimeOfDay closes;
  final TimeOfDay? breakStart;
  final TimeOfDay? breakEnd;

  bool get pastMidnight =>
      closes.hour * 60 + closes.minute < opens.hour * 60 + opens.minute;

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'opens': _fmt(opens),
    'closes': _fmt(closes),
    if (breakStart != null && breakEnd != null) ...{
      'break_start': _fmt(breakStart!),
      'break_end': _fmt(breakEnd!),
    },
  };
}

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

TimeOfDay? _parseTimeOrNull(Object? v) =>
    v == null ? null : _parseTime(v as String);

class ProPhoto {
  const ProPhoto({required this.id, required this.path, required this.sort});

  factory ProPhoto.fromRow(Map<String, Object?> r) => ProPhoto(
    id: r['id']! as String,
    path: r['path']! as String,
    sort: r['sort']! as int,
  );

  final String id;
  final String path;
  final int sort;
}

class ProProfile {
  const ProProfile({
    required this.id,
    required this.kind,
    required this.space,
    required this.displayName,
    required this.workplaceType,
    required this.phoneVisibility,
    required this.showPrices,
    required this.isVerified,
    this.ownerId,
    this.bio,
    this.experienceYears,
    this.workplaceName,
    this.localityId,
    this.customerMix,
    this.serviceRadiusKm,
    this.travelFeeDzd,
    this.avatarPath,
    this.contactPhone,
    this.publishedAt,
    this.services = const [],
    this.hours = const [],
    this.photos = const [],
  });

  /// [services] come from the row's embedded `pro_services` unless given
  /// (the customer view reads them through an RPC instead).
  factory ProProfile.fromRow(
    Map<String, Object?> r, {
    List<ProService>? services,
  }) {
    List<Map<String, Object?>> children(String key) => [
      for (final c in (r[key] as List<Object?>? ?? const []))
        c! as Map<String, Object?>,
    ];
    final published = r['published_at'] as String?;
    return ProProfile(
      id: r['id']! as String,
      // Not selectable by clients; only create_pro_profile returns it.
      ownerId: r['owner_id'] as String?,
      kind: ProKind.fromDb(r['kind']! as String),
      space: Space.fromDb(r['space']! as String),
      displayName: r['display_name']! as String,
      bio: r['bio'] as String?,
      experienceYears: r['experience_years'] as int?,
      workplaceType: WorkplaceType.fromDb(r['workplace_type']! as String),
      workplaceName: r['workplace_name'] as String?,
      localityId: r['locality_id'] as int?,
      customerMix: r['customer_mix'] == null
          ? null
          : CustomerMix.fromDb(r['customer_mix']! as String),
      serviceRadiusKm: r['service_radius_km'] as int?,
      travelFeeDzd: r['travel_fee_dzd'] as int?,
      avatarPath: r['avatar_path'] as String?,
      contactPhone: r['contact_phone'] as String?,
      phoneVisibility: PhoneVisibility.fromDb(r['phone_visibility']! as String),
      showPrices: r['show_prices']! as bool,
      isVerified: r['is_verified']! as bool,
      publishedAt: published == null ? null : DateTime.parse(published).toUtc(),
      services:
          services ??
                [
                  for (final s in children('pro_services'))
                    if (s['archived_at'] == null) ProService.fromRow(s),
                ]
            ..sort((a, b) => a.sort.compareTo(b.sort)),
      hours: [for (final h in children('pro_hours')) DayHours.fromRow(h)]
        ..sort((a, b) => a.weekday.compareTo(b.weekday)),
      photos: [for (final p in children('pro_photos')) ProPhoto.fromRow(p)]
        ..sort((a, b) => a.sort.compareTo(b.sort)),
    );
  }

  final String id;
  final String? ownerId;
  final ProKind kind;
  final Space space;
  final String displayName;
  final String? bio;
  final int? experienceYears;
  final WorkplaceType workplaceType;
  final String? workplaceName;
  final int? localityId;
  final CustomerMix? customerMix;
  final int? serviceRadiusKm;
  final int? travelFeeDzd;
  final String? avatarPath;

  /// The number customers call when [phoneVisibility] is public (E.164),
  /// never the login number. Only the owner's own profile carries it.
  final String? contactPhone;
  final PhoneVisibility phoneVisibility;
  final bool showPrices;
  final bool isVerified;
  final DateTime? publishedAt;
  final List<ProService> services;
  final List<DayHours> hours;
  final List<ProPhoto> photos;

  bool get isPublished => publishedAt != null;

  /// Mirrors `pro_missing_fields` in the database.
  Set<ProfileGap> get gaps => {
    if (localityId == null) ProfileGap.locality,
    if (customerMix == null) ProfileGap.customerMix,
    if (!services.any((s) => s.active)) ProfileGap.services,
    if (hours.isEmpty) ProfileGap.hours,
  };
}

/// Columns of [ProProfile] that can be set back to null by a patch.
enum PatchField {
  bio('bio'),
  experienceYears('experience_years'),
  workplaceName('workplace_name'),
  localityId('locality_id'),
  customerMix('customer_mix'),
  serviceRadiusKm('service_radius_km'),
  travelFeeDzd('travel_fee_dzd'),
  avatarPath('avatar_path');

  const PatchField(this.column);
  final String column;
}

/// A partial update: only fields that are set (or listed in [clear]) are sent.
class ProProfilePatch {
  const ProProfilePatch({
    this.displayName,
    this.bio,
    this.experienceYears,
    this.workplaceType,
    this.workplaceName,
    this.localityId,
    this.customerMix,
    this.serviceRadiusKm,
    this.travelFeeDzd,
    this.avatarPath,
    this.phoneVisibility,
    this.contactPhone,
    this.showPrices,
    this.clear = const {},
  });

  final String? displayName;
  final String? bio;
  final int? experienceYears;
  final WorkplaceType? workplaceType;
  final String? workplaceName;
  final int? localityId;
  final CustomerMix? customerMix;
  final int? serviceRadiusKm;
  final int? travelFeeDzd;
  final String? avatarPath;
  final PhoneVisibility? phoneVisibility;

  /// E.164; sent with a public [phoneVisibility] in one write, since the
  /// database refuses a public phone without a number.
  final String? contactPhone;
  final bool? showPrices;

  /// Nullable columns to reset to null (a null field alone means "unchanged").
  final Set<PatchField> clear;

  Map<String, Object?> toDb() => {
    for (final f in clear) f.column: null,
    if (displayName != null) 'display_name': displayName,
    if (bio != null) 'bio': bio,
    if (experienceYears != null) 'experience_years': experienceYears,
    if (workplaceType != null) 'workplace_type': workplaceType!.toDb(),
    if (workplaceName != null) 'workplace_name': workplaceName,
    if (localityId != null) 'locality_id': localityId,
    if (customerMix != null) 'customer_mix': customerMix!.toDb(),
    if (serviceRadiusKm != null) 'service_radius_km': serviceRadiusKm,
    if (travelFeeDzd != null) 'travel_fee_dzd': travelFeeDzd,
    if (avatarPath != null) 'avatar_path': avatarPath,
    if (phoneVisibility != null) 'phone_visibility': phoneVisibility!.toDb(),
    if (contactPhone != null) 'contact_phone': contactPhone,
    if (showPrices != null) 'show_prices': showPrices,
  };
}
