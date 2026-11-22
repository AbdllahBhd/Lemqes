import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:lemqes/core/router/redirect.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _account = Account(
  id: 'u1',
  fullName: 'Amine',
  customerSpace: Space.men,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: {AppRole.customer},
);

final _session = Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
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

// Riverpod 3 keeps the previous value while rebuilding: when the session
// arrives, accountProvider goes from AsyncData(null) to a loading state that
// still has the value null. Produced by a real container, not hand-built, so
// the tests track Riverpod's actual behaviour.
Future<AsyncValue<Account?>> _reloadingFrom(Account? previous) async {
  var builds = 0;
  final provider = FutureProvider<Account?>(
    (ref) =>
        builds++ == 0 ? Future.value(previous) : Completer<Account?>().future,
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(provider, (_, _) {});
  await container.read(provider.future);
  container.invalidate(provider);
  return container.read(provider);
}

class _Failing extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() async => _account;

  void fail() =>
      state = AsyncError<Account?>(Exception('boom'), StackTrace.empty);
}

/// The state a failed switch leaves, as the real notifier produces it.
Future<AsyncValue<Account?>> _failedSwitch() async {
  final provider = AsyncNotifierProvider<_Failing, Account?>(_Failing.new);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(provider, (_, _) {});
  await container.read(provider.future);
  container.read(provider.notifier).fail();
  return container.read(provider);
}

Account _as(AppRole role) => Account(
  id: 'u1',
  fullName: 'Amine',
  customerSpace: Space.men,
  proSpace: role.isPro ? Space.men : null,
  activeRole: role,
  roles: {AppRole.customer, role},
);

ProProfile _pro({
  int? localityId = 1601,
  CustomerMix? mix = CustomerMix.adults,
  bool service = true,
  bool hours = true,
}) => ProProfile(
  id: 'p1',
  kind: ProKind.barber,
  space: Space.men,
  displayName: 'Amine',
  workplaceType: WorkplaceType.salon,
  phoneVisibility: PhoneVisibility.hidden,
  showPrices: true,
  isVerified: false,
  localityId: localityId,
  customerMix: mix,
  services: [
    if (service)
      const ProService(
        id: 's1',
        presetKey: 'men_cut',
        category: ServiceCategory.hair,
        priceDzd: 600,
        durationMin: 30,
      ),
  ],
  hours: [
    if (hours)
      const DayHours(
        weekday: 6,
        opens: TimeOfDay(hour: 9, minute: 0),
        closes: TimeOfDay(hour: 19, minute: 0),
      ),
  ],
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

  group('session, account error that still holds the account', () {
    late AsyncValue<Account?> failed;

    setUp(() async {
      failed = await _failedSwitch();
      expect(failed.hasError, isTrue);
      expect(failed.value, _account);
    });

    test('at /settings stays put', () {
      expect(_go(account: failed, location: '/settings'), isNull);
    });

    test('at /home stays put', () {
      expect(_go(account: failed, location: '/home'), isNull);
    });

    test('at /auth goes to /home', () {
      expect(_go(account: failed, location: '/auth'), '/home');
    });
  });

  group('sign-in: the account loads with a previous null value', () {
    test('at /auth goes to /home, not the wizard', () async {
      final reloading = await _reloadingFrom(null);
      expect(_go(account: reloading, location: '/auth'), '/home');
    });

    test('at /home stays put', () async {
      final reloading = await _reloadingFrom(null);
      expect(_go(account: reloading, location: '/home'), isNull);
    });
  });

  group('cold start with a session and a draft waiting for its code', () {
    const pending = SignupDraft(
      space: Space.men,
      role: AppRole.customer,
      fullName: 'Amine',
      phone: '+213550000000',
    );

    test('a first load at / opens the code step, not home', () {
      expect(
        _go(account: _loading, draft: pending, location: '/'),
        '/signup/code',
      );
    });

    test('a draft without its name keeps waiting on home', () {
      expect(
        _go(
          account: _loading,
          draft: const SignupDraft(
            space: Space.men,
            role: AppRole.customer,
            phone: '+213550000000',
          ),
          location: '/',
        ),
        '/home',
      );
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

  group('reset', () {
    test('stays put in every session and account state', () {
      for (final hasSession in [false, true]) {
        for (final account in [_loading, _none, _present, _error]) {
          expect(
            _go(
              hasSession: hasSession,
              account: account,
              draft: const SignupDraft(phone: '+213550000000'),
              location: '/auth/reset',
            ),
            isNull,
            reason: 'session $hasSession, account $account',
          );
        }
      }
    });
  });

  group('code step while the account loads after verification', () {
    final reloadingFrom = _reloadingFrom;

    test('the reloading state still has its previous null value', () async {
      final reloading = await reloadingFrom(null);
      expect(reloading.isLoading, isTrue);
      expect(reloading.hasValue, isTrue);
      expect(reloading.value, isNull);
    });

    test('first load: stays on the code step', () {
      expect(_go(account: _loading, location: '/signup/code'), isNull);
    });

    test('reload with a previous null: stays on the code step', () async {
      final reloading = await reloadingFrom(null);
      expect(_go(account: reloading, location: '/signup/code'), isNull);
    });

    test('reload with a previous account: stays on the code step', () async {
      final withAccount = await reloadingFrom(_account);
      expect(_go(account: withAccount, location: '/signup/code'), isNull);
    });

    test('once the account exists, the code step goes home', () {
      expect(_go(account: _present, location: '/signup/code'), '/home');
    });

    test('other wizard steps still wait on home during a first load', () {
      expect(_go(account: _loading, location: '/signup/credentials'), '/home');
    });
  });

  group('signupStepRedirect', () {
    String? step(String s, {SignupDraft? draft, bool hasSession = false}) =>
        signupStepRedirect(step: s, draft: draft, hasSession: hasSession);

    const full = SignupDraft(
      space: Space.men,
      role: AppRole.customer,
      fullName: 'Amine',
      phone: '+213550000000',
    );

    test('an unknown step opens the space step', () {
      expect(step('bogus'), '/signup/space');
    });

    test('no draft: only the space step is open', () {
      expect(step('space'), isNull);
      expect(step('role'), '/signup/space');
      expect(step('code'), '/signup/space');
    });

    test('a step beyond the answers goes to the resume step', () {
      expect(
        step('credentials', draft: const SignupDraft(space: Space.men)),
        '/signup/role',
      );
      expect(
        step(
          'code',
          draft: const SignupDraft(space: Space.men, role: AppRole.barber),
        ),
        '/signup/credentials',
      );
    });

    test('earlier steps stay open for going back', () {
      expect(step('space', draft: full), isNull);
      expect(step('credentials', draft: full), isNull);
      expect(step('code', draft: full), isNull);
    });

    test('signed in without a saved name, the code step asks for it', () {
      const noName = SignupDraft(
        space: Space.men,
        role: AppRole.customer,
        phone: '+213550000000',
      );
      expect(
        step('code', draft: noName, hasSession: true),
        '/signup/credentials',
      );
      expect(step('code', draft: noName), isNull);
      expect(step('code', draft: full, hasSession: true), isNull);
    });
  });

  group('resolveHasSession', () {
    test('a loading stream falls back to the stored session', () {
      expect(
        resolveHasSession(const AsyncValue.loading(), () => _session),
        isTrue,
      );
      expect(
        resolveHasSession(const AsyncValue.loading(), () => null),
        isFalse,
      );
    });

    test('an emitted value wins over the stored session', () {
      expect(
        resolveHasSession(const AsyncValue.data(null), () => _session),
        isFalse,
      );
      expect(resolveHasSession(AsyncValue.data(_session), () => null), isTrue);
    });
  });
  group('pro setup', () {
    test('a barber who just signed up goes to the profile step', () {
      expect(
        _go(account: AsyncData(_as(AppRole.barber)), location: '/signup/code'),
        '/pro/setup/profile',
      );
    });

    test('a home artist who just signed up goes to the profile step', () {
      expect(
        _go(
          account: AsyncData(_as(AppRole.homeArtist)),
          location: '/signup/code',
        ),
        '/pro/setup/profile',
      );
    });

    test('a customer who just signed up goes home', () {
      expect(_go(location: '/signup/code'), '/home');
    });

    test('a salon owner has no setup yet and goes home', () {
      expect(
        _go(
          account: AsyncData(_as(AppRole.salonOwner)),
          location: '/signup/code',
        ),
        '/home',
      );
    });

    test('a pro opening home later is not forced into setup', () {
      expect(
        _go(account: AsyncData(_as(AppRole.barber)), location: '/home'),
        isNull,
      );
    });

    test('a pro may open a setup step', () {
      expect(
        _go(
          account: AsyncData(_as(AppRole.barber)),
          location: '/pro/setup/services',
        ),
        isNull,
      );
    });

    test('a customer opening setup goes home', () {
      expect(_go(location: '/pro/setup/profile'), '/home');
      expect(_go(location: '/pro/setup'), '/home');
    });
  });

  group('proSetupStepRedirect', () {
    String? step(String s, AsyncValue<ProProfile?> pro) =>
        proSetupStepRedirect(step: s, profile: pro);

    test('an unknown step opens the profile step', () {
      expect(step('photos', const AsyncData(null)), '/pro/setup/profile');
    });

    test('waits while the profile loads', () {
      expect(step('hours', const AsyncLoading()), isNull);
    });

    test('without a profile only the profile step is open', () {
      expect(step('profile', const AsyncData(null)), isNull);
      expect(step('services', const AsyncData(null)), '/pro/setup/profile');
      expect(step('hours', const AsyncData(null)), '/pro/setup/profile');
    });

    test('a profile missing its commune keeps the later steps closed', () {
      expect(
        step('services', AsyncData(_pro(localityId: null))),
        '/pro/setup/profile',
      );
      expect(step('hours', AsyncData(_pro(mix: null))), '/pro/setup/profile');
    });

    test('no active service keeps the hours step closed', () {
      expect(step('services', AsyncData(_pro(service: false))), isNull);
      expect(
        step('hours', AsyncData(_pro(service: false))),
        '/pro/setup/services',
      );
    });

    test('the location step follows the profile and is never a gap', () {
      expect(proSetupSteps, ['profile', 'location', 'services', 'hours']);
      expect(step('location', const AsyncData(null)), '/pro/setup/profile');
      expect(
        step('location', AsyncData(_pro(localityId: null))),
        '/pro/setup/profile',
      );
      expect(step('location', AsyncData(_pro(service: false))), isNull);
      expect(step('location', AsyncData(_pro())), isNull);
    });

    test('earlier steps stay open for going back', () {
      expect(step('profile', AsyncData(_pro(hours: false))), isNull);
      expect(step('hours', AsyncData(_pro(hours: false))), isNull);
      expect(step('profile', AsyncData(_pro())), isNull);
    });
  });

  group('proSetupEntry', () {
    test('waits while the profile loads', () {
      expect(proSetupEntry(const AsyncLoading()), isNull);
    });

    test('resumes at the first step with a gap', () {
      expect(proSetupEntry(const AsyncData(null)), '/pro/setup/profile');
      expect(
        proSetupEntry(AsyncData(_pro(mix: null, service: false))),
        '/pro/setup/profile',
      );
      expect(
        proSetupEntry(AsyncData(_pro(service: false, hours: false))),
        '/pro/setup/services',
      );
      expect(proSetupEntry(AsyncData(_pro(hours: false))), '/pro/setup/hours');
    });

    test('an interrupted setup never resumes at the location step', () {
      for (final pro in [
        _pro(service: false),
        _pro(hours: false),
        _pro(service: false, hours: false),
      ]) {
        expect(proSetupEntry(AsyncData(pro)), isNot('/pro/setup/location'));
      }
      expect(setupStepForGaps(ProfileGap.values.toSet()), 'profile');
      expect(setupStepForGaps({ProfileGap.services}), 'services');
    });

    test('a complete profile goes home', () {
      expect(proSetupEntry(AsyncData(_pro())), '/home');
    });
  });
}
