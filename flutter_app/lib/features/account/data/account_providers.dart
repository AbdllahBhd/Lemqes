import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import 'account.dart';
import 'account_api.dart';
import 'account_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) =>
      AccountRepository(SupabaseAccountApi(ref.watch(supabaseClientProvider))),
);

final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentSession;
  yield* repo.authStateChanges().map((s) => s.session);
});

final accountProvider = AsyncNotifierProvider<AccountController, Account?>(
  AccountController.new,
);

class AccountController extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() async {
    // Only the user id matters (token refreshes must not refetch), but stay
    // loading until the session resolves so routing never sees a false null.
    final (:loading, :userId) = ref.watch(
      sessionProvider.select(
        (s) => (loading: !s.hasValue && !s.hasError, userId: s.value?.user.id),
      ),
    );
    if (loading) return Completer<Account?>().future;
    if (userId == null) return null;
    return ref.read(accountRepositoryProvider).fetchMine();
  }

  Future<void> refresh() => _run(() async {});

  Future<void> switchRole(AppRole role) =>
      _run(() => ref.read(accountRepositoryProvider).setActiveRole(role));

  Future<void> addRole(AppRole role, {Space? space, String? businessName}) =>
      _run(
        () => ref
            .read(accountRepositoryProvider)
            .addRole(role, space: space, businessName: businessName),
      );

  Future<void> switchSpace(Space space) =>
      _run(() => ref.read(accountRepositoryProvider).setCustomerSpace(space));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      final fresh = await ref.read(accountRepositoryProvider).fetchMine();
      if (!ref.mounted) return;
      state = AsyncData(fresh);
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError<Account?>(e, st);
    }
  }
}
