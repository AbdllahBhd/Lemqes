import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/redirect.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../account/data/account_repository.dart';
import '../data/signup_draft_store.dart';

/// Whether the user is signed in right now. While the session stream has not
/// emitted, the stored session answers synchronously.
bool watchHasSession(WidgetRef ref) => resolveHasSession(
  ref.watch(sessionProvider),
  () => ref.read(authRepositoryProvider).currentSession,
);

bool readHasSession(WidgetRef ref) => resolveHasSession(
  ref.read(sessionProvider),
  () => ref.read(authRepositoryProvider).currentSession,
);

/// The draft lacks an answer the profile needs (space, role or name).
class IncompleteSignupDraft implements Exception {
  const IncompleteSignupDraft(this.missing);

  /// Names of the missing fields only: the draft holds personal data.
  final List<String> missing;

  @override
  String toString() => 'IncompleteSignupDraft(missing: $missing)';
}

/// The password typed at the last sign-up request, in memory only: it must
/// never reach the draft or any other storage. Lost on restart, which only
/// matters if the user signed up twice before verifying.
final signupPasswordProvider = NotifierProvider<SignupPassword, String?>(
  SignupPassword.new,
);

class SignupPassword extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String password) => state = password;

  void clear() => state = null;
}

final signupCompletionProvider = NotifierProvider<SignupCompletion, void>(
  SignupCompletion.new,
);

/// Creates the profile from the draft once the phone is verified, after
/// applying the password typed last (see [signupPasswordProvider]).
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
    final password = ref.read(signupPasswordProvider);
    if (password != null) {
      await ref.read(authRepositoryProvider).confirmSignUpPassword(password);
      ref.read(signupPasswordProvider.notifier).clear();
    }
    final draft = ref.read(signupDraftProvider);
    final space = draft?.space;
    final role = draft?.role;
    final fullName = draft?.fullName;
    if (space == null || role == null || fullName == null) {
      throw IncompleteSignupDraft([
        if (space == null) 'space',
        if (role == null) 'role',
        if (fullName == null) 'fullName',
      ]);
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
