enum Space {
  men,
  women;

  String toDb() => name;

  static Space fromDb(String value) =>
      Space.values.firstWhere((s) => s.name == value);
}

enum AppRole {
  customer('customer'),
  barber('barber'),
  homeArtist('home_artist'),
  salonOwner('salon_owner');

  const AppRole(this._db);
  final String _db;

  String toDb() => _db;

  static AppRole fromDb(String value) =>
      AppRole.values.firstWhere((r) => r._db == value);

  bool get isPro => this != AppRole.customer;
}

class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.customerSpace,
    required this.proSpace,
    required this.activeRole,
    required this.roles,
    this.businessName,
  });

  final String id;
  final String fullName;
  final Space customerSpace;
  final Space? proSpace;
  final AppRole activeRole;
  final Set<AppRole> roles;
  final String? businessName;

  Space get currentSpace =>
      activeRole.isPro ? (proSpace ?? customerSpace) : customerSpace;

  String get displayName =>
      activeRole == AppRole.salonOwner && businessName != null
      ? businessName!
      : fullName;
}
