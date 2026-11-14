import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'account.dart';
import 'account_api.dart';

sealed class AccountFailure implements Exception {
  const AccountFailure();
}

class SpaceLocked extends AccountFailure {
  const SpaceLocked();
}

class SpaceRequired extends AccountFailure {
  const SpaceRequired();
}

class RoleNotHeld extends AccountFailure {
  const RoleNotHeld();
}

class ProfileExists extends AccountFailure {
  const ProfileExists();
}

class ProfileMissing extends AccountFailure {
  const ProfileMissing();
}

class PhoneNotVerified extends AccountFailure {
  const PhoneNotVerified();
}

class NetworkAccountFailure extends AccountFailure {
  const NetworkAccountFailure();
}

class UnknownAccountFailure extends AccountFailure {
  const UnknownAccountFailure(this.debug);
  final String debug;
}

class AccountRepository {
  AccountRepository(this._api);

  final AccountApi _api;

  Future<Account?> fetchMine() => _guard(() async {
    final profile = await _api.myProfile();
    if (profile == null) return null;
    final rows = await _api.myRoles();
    final roles = {for (final r in rows) AppRole.fromDb(r['role']! as String)};
    String? businessName;
    for (final r in rows) {
      if (r['role'] == AppRole.salonOwner.toDb()) {
        businessName = r['business_name'] as String?;
      }
    }
    final proSpace = profile['pro_space'] as String?;
    return Account(
      id: profile['id']! as String,
      fullName: profile['full_name']! as String,
      customerSpace: Space.fromDb(profile['customer_space']! as String),
      proSpace: proSpace == null ? null : Space.fromDb(proSpace),
      activeRole: AppRole.fromDb(profile['active_role']! as String),
      roles: roles,
      businessName: businessName,
    );
  });

  Future<Account> completeSignup({
    required String fullName,
    required Space space,
    required AppRole role,
    String? businessName,
  }) async {
    await _guard(
      () => _api.rpc('complete_signup', {
        'p_full_name': fullName,
        'p_space': space.toDb(),
        'p_role': role.toDb(),
        'p_business_name': businessName,
      }),
    );
    final account = await fetchMine();
    if (account == null) throw const ProfileMissing();
    return account;
  }

  Future<void> addRole(AppRole role, {Space? space, String? businessName}) =>
      _guard(
        () => _api.rpc('add_role', {
          'p_role': role.toDb(),
          'p_space': space?.toDb(),
          'p_business_name': businessName,
        }),
      );

  Future<void> setActiveRole(AppRole role) =>
      _guard(() => _api.rpc('set_active_role', {'p_role': role.toDb()}));

  Future<void> setCustomerSpace(Space space) =>
      _guard(() => _api.rpc('set_customer_space', {'p_space': space.toDb()}));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AccountFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw _map(e);
    } on SocketException {
      throw const NetworkAccountFailure();
    } on TimeoutException {
      throw const NetworkAccountFailure();
    } on Object catch (e) {
      // package:http's ClientException is matched by name: http is not a
      // direct dependency of this package.
      if (e.runtimeType.toString() == 'ClientException') {
        throw const NetworkAccountFailure();
      }
      throw UnknownAccountFailure(e.toString());
    }
  }

  AccountFailure _map(PostgrestException e) {
    final m = e.message;
    if (m.contains('space_locked')) return const SpaceLocked();
    if (m.contains('space_required')) return const SpaceRequired();
    if (m.contains('role_not_held')) return const RoleNotHeld();
    if (m.contains('profile_exists')) return const ProfileExists();
    if (m.contains('profile_missing')) return const ProfileMissing();
    if (m.contains('phone_not_verified')) return const PhoneNotVerified();
    return UnknownAccountFailure(m);
  }
}
