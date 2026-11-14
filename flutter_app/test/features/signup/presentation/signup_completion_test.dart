import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/data/signup_draft_store.dart';
import 'package:lemqes/features/signup/presentation/signup_completion.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/harness.dart';

const _draft = SignupDraft(
  space: Space.men,
  role: AppRole.barber,
  fullName: 'Amine Benali',
  businessName: 'Stale salon name',
  phone: '+213550123456',
);

void main() {
  late MockAccountRepository repo;

  setUpAll(registerHarnessFallbacks);

  Future<ProviderContainer> container(SignupDraft draft) async {
    SharedPreferences.setMockInitialValues({
      SignupDraftStore.prefsKey: jsonEncode(draft.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => Stream.value(testSession)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void stubComplete(Future<Account> Function() answer) {
    when(
      () => repo.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repo = MockAccountRepository();
    when(() => repo.fetchMine()).thenAnswer((_) async => testAccount);
  });

  test('concurrent finish() calls complete sign-up exactly once', () async {
    final request = Completer<Account>();
    stubComplete(() => request.future);
    final c = await container(_draft);
    final completion = c.read(signupCompletionProvider.notifier);

    final first = completion.finish();
    final second = completion.finish();
    request.complete(testAccount);
    await Future.wait([first, second]);

    verify(
      () => repo.completeSignup(
        fullName: 'Amine Benali',
        space: Space.men,
        role: AppRole.barber,
        // Only a salon owner sends a business name.
        businessName: null,
      ),
    ).called(1);
    expect(c.read(signupDraftProvider), isNull);
    expect(c.read(accountProvider).value, testAccount);
  });

  test('a finished call can run again later', () async {
    stubComplete(() async => testAccount);
    final c = await container(_draft);
    await c.read(signupCompletionProvider.notifier).finish();
    c.read(signupDraftProvider.notifier).update((_) => _draft);
    await c.read(signupCompletionProvider.notifier).finish();

    verify(
      () => repo.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    ).called(2);
  });

  test('ProfileExists counts as done: no error, draft cleared', () async {
    stubComplete(() async => throw const ProfileExists());
    final c = await container(_draft);

    await expectLater(
      c.read(signupCompletionProvider.notifier).finish(),
      completes,
    );
    expect(c.read(signupDraftProvider), isNull);
    expect(c.read(accountProvider).value, testAccount);
  });

  test('another failure propagates and keeps the draft', () async {
    stubComplete(() async => throw const NetworkAccountFailure());
    final c = await container(_draft);

    await expectLater(
      c.read(signupCompletionProvider.notifier).finish(),
      throwsA(isA<NetworkAccountFailure>()),
    );
    expect(c.read(signupDraftProvider)?.phone, _draft.phone);
  });

  test('an incomplete draft names the missing fields, not the data', () async {
    final c = await container(
      const SignupDraft(space: Space.men, phone: '+213550123456'),
    );

    await expectLater(
      c.read(signupCompletionProvider.notifier).finish(),
      throwsA(
        isA<IncompleteSignupDraft>()
            .having((e) => e.missing, 'missing', ['role', 'fullName'])
            .having((e) => e.toString(), 'message', isNot(contains('213'))),
      ),
    );
    verifyNever(
      () => repo.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    );
  });
}
