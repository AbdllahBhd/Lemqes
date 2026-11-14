import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/account_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/explore/presentation/pro_public_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/pro/data/pro_providers.dart';
import '../../features/pro/presentation/setup/pro_setup_flow.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/signup/data/signup_draft_store.dart';
import '../../features/signup/presentation/signup_wizard.dart';
import 'redirect.dart';

/// Re-runs the router redirect whenever account, draft or pro profile change.
///
/// Not on session events: the account rebuilds on every sign-in and sign-out,
/// and a session listener ran before that rebuild, showing the redirect a
/// stale "signed in, no account" that opened the wizard for a frame.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(accountProvider, (_, _) => notifyListeners());
    ref.listen(signupDraftProvider, (_, _) => notifyListeners());
    // Setup steps open once the profile has loaded and as its gaps close.
    ref.listen(myProProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      hasSession: _hasSession(ref),
      account: ref.read(accountProvider),
      draft: ref.read(signupDraftProvider),
      location: state.uri.path,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/auth/reset',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/signup/:step',
        redirect: (context, state) => signupStepRedirect(
          step: state.pathParameters['step']!,
          draft: ref.read(signupDraftProvider),
          hasSession: _hasSession(ref),
        ),
        builder: (context, state) =>
            SignupWizard(step: state.pathParameters['step']!),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/pro/setup',
        redirect: (context, state) => proSetupEntry(ref.read(myProProvider)),
        builder: (_, _) => const ProSetupEntryScreen(),
      ),
      GoRoute(
        path: '/pro/setup/:step',
        redirect: (context, state) => proSetupStepRedirect(
          step: state.pathParameters['step']!,
          profile: ref.read(myProProvider),
        ),
        builder: (context, state) => ProSetupScreen(
          step: state.pathParameters['step']!,
          incomplete: state.uri.queryParameters['incomplete'] == '1',
        ),
      ),
      // After the setup routes: go_router matches in order, and `setup`
      // would otherwise be read as a profile id.
      GoRoute(
        path: '/pro/:id',
        builder: (context, state) =>
            ProPublicProfileScreen(proId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

bool _hasSession(Ref ref) => resolveHasSession(
  ref.read(sessionProvider),
  () => ref.read(authRepositoryProvider).currentSession,
);
