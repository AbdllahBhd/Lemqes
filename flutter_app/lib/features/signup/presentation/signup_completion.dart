import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../account/data/account_repository.dart';
import '../data/signup_draft_store.dart';

/// Whether the user is signed in right now. While the session stream has not
/// emitted, the stored session answers synchronously.
bool watchHasSession(WidgetRef ref) =>
    _hasSession(ref, ref.watch(sessionProvider));

bool readHasSession(WidgetRef ref) =>
    _hasSession(ref, ref.read(sessionProvider));

bool _hasSession(WidgetRef ref, AsyncValue<Session?> session) {
  if (session.hasValue) return session.value != null;
  return ref.read(authRepositoryProvider).currentSession != null;
}

final signupCompletionProvider = NotifierProvider<SignupCompletion, void>(
  SignupCompletion.new,
);

/// Creates the profile from the draft once the phone is verified.
///
/// Lives outside the widgets: verification changes the session, the router
/// may rebuild the wizard mid-call, and the call must neither stop nor run
/// twice.
class SignupCompletion extends Notifier<void> {
  Future<void>? _running;

  @override
  void build() {}

  Future<void> finish() =>
      _running ??= _finish().whenComplete(() => _running = null);

  Future<void> _finish() async {
    final draft = ref.read(signupDraftProvider);
    final space = draft?.space;
    final role = draft?.role;
    final fullName = draft?.fullName;
    if (space == null || role == null || fullName == null) {
      throw StateError('Sign-up draft is incomplete: ${draft?.toJson()}');
    }
    try {
      await ref
          .read(accountRepositoryProvider)
          .completeSignup(
            fullName: fullName,
            space: space,
            role: role,
            businessName: role == AppRole.salonOwner
                ? draft?.businessName
                : null,
          );
    } on ProfileExists {
      // A retry after a lost response: the profile is already there.
    }
    ref.invalidate(accountProvider);
    // Listened, not just read: an unlistened provider would not rebuild when
    // the session arrives, and its future would never resolve.
    final account = ref.listen(accountProvider, (_, _) {});
    try {
      // Keep the draft until the account has loaded, so the router never sees
      // "signed in, no account, no draft" in between.
      await ref.read(accountProvider.future);
    } finally {
      account.close();
      ref.read(signupDraftProvider.notifier).clear();
    }
  }
}
