import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/data/signup_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const full = SignupDraft(
    space: Space.women,
    role: AppRole.salonOwner,
    fullName: 'Lina',
    businessName: 'Salon Lina',
    phone: '+213550000000',
  );

  test('write then read returns the same draft', () async {
    final c = await _container();
    final store = c.read(signupDraftStoreProvider);
    store.write(full);
    final back = store.read()!;
    expect(back.space, Space.women);
    expect(back.role, AppRole.salonOwner);
    expect(back.fullName, 'Lina');
    expect(back.businessName, 'Salon Lina');
    expect(back.phone, '+213550000000');
  });

  test('stored JSON has no password key', () async {
    final c = await _container();
    c.read(signupDraftStoreProvider).write(full);
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(prefs.getString('signup_draft')!) as Map;
    expect(json.containsKey('password'), isFalse);
    expect(full.toJson().containsKey('password'), isFalse);
  });

  test('clear then read returns null', () async {
    final c = await _container();
    final store = c.read(signupDraftStoreProvider);
    store.write(full);
    store.clear();
    expect(store.read(), isNull);
  });

  test('corrupt stored value reads as null', () async {
    SharedPreferences.setMockInitialValues({'signup_draft': 'not json'});
    final c = await _container();
    expect(c.read(signupDraftStoreProvider).read(), isNull);
  });

  test('resumeStep for each stage', () {
    expect(const SignupDraft().resumeStep, 'space');
    expect(const SignupDraft(space: Space.men).resumeStep, 'role');
    expect(
      const SignupDraft(space: Space.men, role: AppRole.barber).resumeStep,
      'credentials',
    );
    expect(full.resumeStep, 'code');
  });

  test(
    'controller starts from stored draft, update and clear persist',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      expect(c.read(signupDraftProvider), isNull);
      c
          .read(signupDraftProvider.notifier)
          .update((d) => d.copyWith(space: Space.men));
      expect(c.read(signupDraftProvider)?.space, Space.men);
      expect(c.read(signupDraftStoreProvider).read()?.space, Space.men);

      final fresh = await _container();
      expect(fresh.read(signupDraftProvider)?.space, Space.men);

      c.read(signupDraftProvider.notifier).clear();
      expect(c.read(signupDraftProvider), isNull);
      expect(c.read(signupDraftStoreProvider).read(), isNull);
    },
  );
}
