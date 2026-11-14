import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/router/redirect.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';

const _account = Account(
  id: 'u1',
  fullName: 'Amine',
  customerSpace: Space.men,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: {AppRole.customer},
);

const _loading = AsyncValue<Account?>.loading();
const _none = AsyncValue<Account?>.data(null);
const _present = AsyncValue<Account?>.data(_account);
final _error = AsyncValue<Account?>.error(Exception('boom'), StackTrace.empty);

String? _go({
  bool hasSession = true,
  AsyncValue<Account?> account = _present,
  SignupDraft? draft,
  required String location,
}) => authRedirect(
  hasSession: hasSession,
  account: account,
  draft: draft,
  location: location,
);

void main() {
  group('no session', () {
    test('draft with phone at / resumes the code step', () {
      expect(
        _go(
          hasSession: false,
          draft: const SignupDraft(phone: '+213550000000'),
          location: '/',
        ),
        '/signup/code',
      );
    });

    test('draft with phone at /auth resumes the code step', () {
      expect(
        _go(
          hasSession: false,
          draft: const SignupDraft(phone: '+213550000000'),
          location: '/auth',
        ),
        '/signup/code',
      );
    });

    test('draft with phone inside the wizard stays put', () {
      expect(
        _go(
          hasSession: false,
          draft: const SignupDraft(phone: '+213550000000'),
          location: '/signup/role',
        ),
        isNull,
      );
    });

    test('no draft at /home goes to /auth', () {
      expect(_go(hasSession: false, location: '/home'), '/auth');
    });

    test('no draft at / goes to /auth', () {
      expect(_go(hasSession: false, location: '/'), '/auth');
    });

    test('/auth and /auth/reset stay put', () {
      expect(_go(hasSession: false, location: '/auth'), isNull);
      expect(_go(hasSession: false, location: '/auth/reset'), isNull);
    });

    test('/signup/* stays put', () {
      expect(_go(hasSession: false, location: '/signup/space'), isNull);
    });
  });

  group('session, account loading', () {
    test('at /signup/role goes to /home', () {
      expect(_go(account: _loading, location: '/signup/role'), '/home');
    });

    test('at /home stays put', () {
      expect(_go(account: _loading, location: '/home'), isNull);
    });
  });

  group('session, account error', () {
    test('at /signup/space goes to /home', () {
      expect(_go(account: _error, location: '/signup/space'), '/home');
    });

    test('at /home stays put', () {
      expect(_go(account: _error, location: '/home'), isNull);
    });
  });

  group('session, no account', () {
    test('no draft at /home goes to the space step', () {
      expect(_go(account: _none, location: '/home'), '/signup/space');
    });

    test('draft resumes at its resume step', () {
      expect(
        _go(
          account: _none,
          draft: const SignupDraft(space: Space.men),
          location: '/',
        ),
        '/signup/role',
      );
    });

    test('inside the wizard allows back navigation', () {
      expect(_go(account: _none, location: '/signup/role'), isNull);
    });
  });

  group('session, account present', () {
    test('/auth/reset stays put', () {
      expect(_go(location: '/auth/reset'), isNull);
    });

    test('/auth goes to /home', () {
      expect(_go(location: '/auth'), '/home');
    });

    test('/signup/credentials goes to /home', () {
      expect(_go(location: '/signup/credentials'), '/home');
    });

    test('/ goes to /home', () {
      expect(_go(location: '/'), '/home');
    });

    test('/settings stays put', () {
      expect(_go(location: '/settings'), isNull);
    });
  });
}
