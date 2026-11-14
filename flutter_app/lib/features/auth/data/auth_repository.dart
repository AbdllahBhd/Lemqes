import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

sealed class AuthFailure implements Exception {
  const AuthFailure();
}

class InvalidCredentials extends AuthFailure {
  const InvalidCredentials();
}

class PhoneAlreadyRegistered extends AuthFailure {
  const PhoneAlreadyRegistered();
}

class PhoneNotRegistered extends AuthFailure {
  const PhoneNotRegistered();
}

class InvalidOrExpiredCode extends AuthFailure {
  const InvalidOrExpiredCode();
}

class RateLimited extends AuthFailure {
  const RateLimited(this.retryAfter);
  final Duration? retryAfter;
}

class WeakPassword extends AuthFailure {
  const WeakPassword();
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(this.debug);
  final String debug;
}

/// Phone/password auth over GoTrue. Phones must already be E.164.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  Future<void> signUp({required String phone, required String password}) =>
      _guard(() async {
        final res = await _auth.signUp(phone: phone, password: password);
        final identities = res.user?.identities;
        if (identities != null && identities.isEmpty) {
          throw const PhoneAlreadyRegistered();
        }
      });

  Future<void> verifySignUpCode({
    required String phone,
    required String code,
  }) => _guard(
    () => _auth.verifyOTP(phone: phone, token: code, type: OtpType.sms),
  );

  Future<void> resendSignUpCode(String phone) =>
      _guard(() => _auth.resend(type: OtpType.sms, phone: phone));

  Future<void> signIn({required String phone, required String password}) =>
      _guard(() => _auth.signInWithPassword(phone: phone, password: password));

  Future<void> sendResetCode(String phone) =>
      _guard(() => _auth.signInWithOtp(phone: phone, shouldCreateUser: false));

  Future<void> verifyResetCode({required String phone, required String code}) =>
      verifySignUpCode(phone: phone, code: code);

  Future<void> setNewPassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => _guard(() => _auth.signOut());

  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw _map(e);
    }
  }

  AuthFailure _map(Object e) {
    if (e is SocketException || e is AuthRetryableFetchException) {
      return const NetworkFailure();
    }
    if (e is AuthException) {
      switch (e.code) {
        case 'user_already_exists':
          return const PhoneAlreadyRegistered();
        case 'otp_expired':
          return const InvalidOrExpiredCode();
        case 'invalid_credentials':
          return const InvalidCredentials();
        case 'weak_password':
          return const WeakPassword();
        case 'otp_disabled':
          return const PhoneNotRegistered();
        case 'over_sms_send_rate_limit':
          return RateLimited(_retryAfter(e.message));
      }
      if (e.statusCode == '429') return RateLimited(_retryAfter(e.message));
    }
    return UnknownAuthFailure(e.toString());
  }

  Duration? _retryAfter(String message) {
    final m = RegExp(r'after (\d+) seconds?').firstMatch(message);
    final seconds = m == null ? null : int.tryParse(m.group(1)!);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
