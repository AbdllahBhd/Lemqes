import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_api.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockApi extends Mock implements AccountApi {}

void main() {
  late _MockApi api;
  late AccountRepository repo;

  setUp(() {
    api = _MockApi();
    repo = AccountRepository(api);
  });

  test('completeSignup calls the RPC with exact params', () async {
    when(() => api.rpc(any(), any())).thenAnswer((_) async => null);
    when(() => api.myProfile()).thenAnswer(
      (_) async => {
        'id': 'u1',
        'full_name': 'Salon Lina owner',
        'pro_space': 'women',
        'customer_space': 'women',
        'active_role': 'salon_owner',
      },
    );
    when(() => api.myRoles()).thenAnswer(
      (_) async => [
        {'role': 'salon_owner', 'business_name': 'Salon Lina'},
      ],
    );
    final account = await repo.completeSignup(
      fullName: 'Salon Lina owner',
      space: Space.women,
      role: AppRole.salonOwner,
      businessName: 'Salon Lina',
    );
    verify(
      () => api.rpc('complete_signup', {
        'p_full_name': 'Salon Lina owner',
        'p_space': 'women',
        'p_role': 'salon_owner',
        'p_business_name': 'Salon Lina',
      }),
    ).called(1);
    expect(account.displayName, 'Salon Lina');
  });

  final failures = <String, Matcher>{
    'space_locked': isA<SpaceLocked>(),
    'space_required': isA<SpaceRequired>(),
    'role_not_held': isA<RoleNotHeld>(),
    'profile_exists': isA<ProfileExists>(),
    'phone_not_verified': isA<PhoneNotVerified>(),
    'profile_missing': isA<ProfileMissing>(),
    'something else': isA<UnknownAccountFailure>(),
  };
  failures.forEach((message, matcher) {
    test('maps "$message"', () {
      when(() => api.rpc(any(), any()))
          .thenThrow(PostgrestException(message: message));
      expect(repo.setActiveRole(AppRole.barber), throwsA(matcher));
    });
  });

  test('fetchMine returns null with no profile', () async {
    when(() => api.myProfile()).thenAnswer((_) async => null);
    expect(await repo.fetchMine(), isNull);
  });

  test('fetchMine builds roles, space and displayName', () async {
    when(() => api.myProfile()).thenAnswer(
      (_) async => {
        'id': 'u1',
        'full_name': 'Lina B',
        'pro_space': 'women',
        'customer_space': 'men',
        'active_role': 'customer',
      },
    );
    when(() => api.myRoles()).thenAnswer(
      (_) async => [
        {'role': 'customer', 'business_name': null},
        {'role': 'salon_owner', 'business_name': 'Salon Lina'},
      ],
    );
    final a = (await repo.fetchMine())!;
    expect(a.roles, {AppRole.customer, AppRole.salonOwner});
    expect(a.currentSpace, Space.men);
    expect(a.displayName, 'Lina B');
    expect(a.businessName, 'Salon Lina');
  });

  test('pro active role uses pro space and business displayName', () async {
    when(() => api.myProfile()).thenAnswer(
      (_) async => {
        'id': 'u1',
        'full_name': 'Lina B',
        'pro_space': 'women',
        'customer_space': 'men',
        'active_role': 'salon_owner',
      },
    );
    when(() => api.myRoles()).thenAnswer(
      (_) async => [
        {'role': 'salon_owner', 'business_name': 'Salon Lina'},
      ],
    );
    final a = (await repo.fetchMine())!;
    expect(a.currentSpace, Space.women);
    expect(a.displayName, 'Salon Lina');
  });
}
