import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/account_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
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
    redirect: (context, state) => authRedirect(
      hasSession: _hasSession(ref),
      account: ref.read(accountProvider),
      draft: ref.read(signupDraftProvider),
      location: state.uri.path,
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => null, builder: _page('/')),
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

bool _hasSession(Ref ref) => resolveHasSession(
  ref.read(sessionProvider),
  () => ref.read(authRepositoryProvider).currentSession,
);

GoRouterWidgetBuilder _page(String name) =>
    (context, state) => PlaceholderScreen(name);
