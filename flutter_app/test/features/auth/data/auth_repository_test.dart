import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

const _phone = '+213550123456';

void main() {
  setUpAll(() {
    registerFallbackValue(OtpType.sms);
    registerFallbackValue(UserAttributes());
  });

  late _MockAuth auth;
  late AuthRepository repo;

  setUp(() {
    auth = _MockAuth();
    repo = AuthRepository(auth);
  });

  void stubSignUpThrows(Object e) => when(
    () => auth.signUp(
      phone: any(named: 'phone'),
      password: any(named: 'password'),
    ),
  ).thenThrow(e);

  Future<void> signUp() => repo.signUp(phone: _phone, password: 'secret123');

  test('signUp maps user_already_exists to PhoneAlreadyRegistered', () {
    stubSignUpThrows(
      const AuthException(
        'User already registered',
        statusCode: '422',
        code: 'user_already_exists',
      ),
    );
    expect(signUp(), throwsA(isA<PhoneAlreadyRegistered>()));
  });

  test('signUp with empty identities is PhoneAlreadyRegistered', () {
    when(
      () => auth.signUp(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => AuthResponse(
        user: User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
          identities: const [],
        ),
      ),
    );
    expect(signUp(), throwsA(isA<PhoneAlreadyRegistered>()));
  });

  test('signUp succeeds for a new number', () async {
    when(
      () => auth.signUp(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => AuthResponse(
        user: User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
          identities: [
            UserIdentity(
              id: 'i',
              userId: 'u',
              identityData: const {},
              identityId: 'i',
              provider: 'phone',
              createdAt: '2026-01-01T00:00:00Z',
              lastSignInAt: '2026-01-01T00:00:00Z',
            ),
          ],
        ),
      ),
    );
    await signUp();
  });

  test('verify maps otp_expired to InvalidOrExpiredCode', () {
    when(
      () => auth.verifyOTP(
        phone: any(named: 'phone'),
        token: any(named: 'token'),
        type: any(named: 'type'),
      ),
    ).thenThrow(
      const AuthException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      ),
    );
    expect(
      repo.verifySignUpCode(phone: _phone, code: '000000'),
      throwsA(isA<InvalidOrExpiredCode>()),
    );
  });

  test('signIn maps invalid_credentials', () {
    when(
      () => auth.signInWithPassword(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      ),
    );
    expect(
      repo.signIn(phone: _phone, password: 'x'),
      throwsA(isA<InvalidCredentials>()),
    );
  });

  test('429 over_sms_send_rate_limit parses retry seconds', () async {
    when(() => auth.resend(type: OtpType.sms, phone: _phone)).thenThrow(
      const AuthException(
        'For security purposes, you can only request this after 42 seconds.',
        statusCode: '429',
        code: 'over_sms_send_rate_limit',
      ),
    );
    await expectLater(
      repo.resendSignUpCode(_phone),
      throwsA(
        isA<RateLimited>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 42),
        ),
      ),
    );
  });

  test('429 without seconds gives null retryAfter', () {
    when(() => auth.resend(type: OtpType.sms, phone: _phone))
        .thenThrow(const AuthException('slow down', statusCode: '429'));
    expect(
      repo.resendSignUpCode(_phone),
      throwsA(isA<RateLimited>().having((e) => e.retryAfter, 'r', isNull)),
    );
  });

  test('weak_password maps to WeakPassword', () {
    stubSignUpThrows(
      const AuthException('weak', statusCode: '422', code: 'weak_password'),
    );
    expect(signUp(), throwsA(isA<WeakPassword>()));
  });

  test('SocketException maps to NetworkFailure', () {
    stubSignUpThrows(const SocketException('offline'));
    expect(signUp(), throwsA(isA<NetworkFailure>()));
  });

  test('AuthRetryableFetchException maps to NetworkFailure', () {
    stubSignUpThrows(AuthRetryableFetchException());
    expect(signUp(), throwsA(isA<NetworkFailure>()));
  });

  test('unknown errors map to UnknownAuthFailure', () {
    stubSignUpThrows(StateError('boom'));
    expect(signUp(), throwsA(isA<UnknownAuthFailure>()));
  });

  test('sendResetCode uses signInWithOtp without creating a user', () async {
    when(
      () => auth.signInWithOtp(
        phone: any(named: 'phone'),
        shouldCreateUser: any(named: 'shouldCreateUser'),
      ),
    ).thenAnswer((_) async {});
    await repo.sendResetCode(_phone);
    verify(() => auth.signInWithOtp(phone: _phone, shouldCreateUser: false))
        .called(1);
  });

  test('sendResetCode maps otp_disabled to PhoneNotRegistered', () {
    when(
      () => auth.signInWithOtp(
        phone: any(named: 'phone'),
        shouldCreateUser: any(named: 'shouldCreateUser'),
      ),
    ).thenThrow(
      const AuthException(
        'Signups not allowed for otp',
        statusCode: '422',
        code: 'otp_disabled',
      ),
    );
    expect(repo.sendResetCode(_phone), throwsA(isA<PhoneNotRegistered>()));
  });

  group('confirmSignUpPassword', () {
    UserAttributes? sent;

    void stubUpdate(Future<UserResponse> Function() answer) =>
        when(() => auth.updateUser(any())).thenAnswer((inv) {
          sent = inv.positionalArguments.first as UserAttributes;
          return answer();
        });

    test('sets the password typed last', () async {
      stubUpdate(() async => UserResponse.fromJson({}));
      await repo.confirmSignUpPassword('second-pass');
      expect(sent?.password, 'second-pass');
    });

    test('the same password as the first sign-up is already set', () async {
      stubUpdate(
        () async => throw const AuthException(
          'New password should be different from the old password.',
          statusCode: '422',
          code: 'same_password',
        ),
      );
      await expectLater(repo.confirmSignUpPassword('secret123'), completes);
    });

    test('any other failure is mapped', () {
      stubUpdate(() async => throw const SocketException('offline'));
      expect(
        repo.confirmSignUpPassword('secret123'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
