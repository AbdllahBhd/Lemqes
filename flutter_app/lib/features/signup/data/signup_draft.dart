import '../../account/data/account.dart';

/// Wizard answers kept on the device so sign-up survives an app restart.
/// The password is deliberately not a field: it must never be persisted.
class SignupDraft {
  const SignupDraft({
    this.space,
    this.role,
    this.fullName,
    this.businessName,
    this.phone,
  });

  factory SignupDraft.fromJson(Map<String, Object?> json) {
    final space = json['space'] as String?;
    final role = json['role'] as String?;
    return SignupDraft(
      space: space == null ? null : Space.fromDb(space),
      role: role == null ? null : AppRole.fromDb(role),
      fullName: json['fullName'] as String?,
      businessName: json['businessName'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final Space? space;
  final AppRole? role;
  final String? fullName;
  final String? businessName;
  final String? phone;

  String get resumeStep {
    if (space == null) return 'space';
    if (role == null) return 'role';
    if (phone == null) return 'credentials';
    return 'code';
  }

  /// The draft before any code was sent: the answers without the phone.
  SignupDraft withoutPhone() => SignupDraft(
    space: space,
    role: role,
    fullName: fullName,
    businessName: businessName,
  );

  Map<String, Object?> toJson() => {
    'space': space?.toDb(),
    'role': role?.toDb(),
    'fullName': fullName,
    'businessName': businessName,
    'phone': phone,
  };

  SignupDraft copyWith({
    Space? space,
    AppRole? role,
    String? fullName,
    String? businessName,
    String? phone,
  }) => SignupDraft(
    space: space ?? this.space,
    role: role ?? this.role,
    fullName: fullName ?? this.fullName,
    businessName: businessName ?? this.businessName,
    phone: phone ?? this.phone,
  );
}
