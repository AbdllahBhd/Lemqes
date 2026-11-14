import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/account_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/signup/data/signup_draft.dart';
import '../../features/signup/data/signup_draft_store.dart';
import '../../features/signup/presentation/signup_wizard.dart';
import 'placeholder_screen.dart';
import 'redirect.dart';

/// Re-runs the router redirect whenever session, account or draft change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(accountProvider, (_, _) => notifyListeners());
    ref.listen(signupDraftProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.uri.path;
      final hasSession = _hasSession(ref);
      final account = ref.read(accountProvider);
      // The reset code signs the user in before the new password is set:
      // the screen must survive the session (and any profile state) arriving.
      if (location == '/auth/reset') return null;
      // Verification just signed the user in; the code step shows its own
      // progress while the profile is created, instead of a detour via home.
      if (hasSession &&
          location == '/signup/code' &&
          account.isLoading &&
          !account.hasValue) {
        return null;
      }
      return authRedirect(
        hasSession: hasSession,
        account: account,
        draft: ref.read(signupDraftProvider),
        location: location,
      );
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => null, builder: _page('/')),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/auth/reset',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/signup/:step',
        redirect: (context, state) => _signupStepGuard(
          step: state.pathParameters['step']!,
          draft: ref.read(signupDraftProvider) ?? const SignupDraft(),
          hasSession: _hasSession(ref),
        ),
        builder: (context, state) =>
            SignupWizard(step: state.pathParameters['step']!),
      ),
      GoRoute(path: '/home', builder: _page('/home')),
      GoRoute(path: '/settings', builder: _page('/settings')),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// While the session stream has not emitted (cold start), the stored session
/// answers synchronously, so a signed-in user never sees a frame of /auth.
bool _hasSession(Ref ref) {
  final session = ref.read(sessionProvider);
  if (session.hasValue) return session.value != null;
  return ref.read(authRepositoryProvider).currentSession != null;
}

/// Keeps the wizard from opening a step whose earlier answers are missing.
String? _signupStepGuard({
  required String step,
  required SignupDraft draft,
  required bool hasSession,
}) {
  final index = signupSteps.indexOf(step);
  if (index < 0) return '/signup/space';
  var reachable = draft.resumeStep;
  // Signed in, the code is already verified; it only finishes the profile,
  // which needs the names from the credentials step.
  if (hasSession && reachable == 'code' && draft.fullName == null) {
    reachable = 'credentials';
  }
  if (index > signupSteps.indexOf(reachable)) return '/signup/$reachable';
  return null;
}

GoRouterWidgetBuilder _page(String name) =>
    (context, state) => PlaceholderScreen(name);
