import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/account_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/explore/presentation/explore_map_view.dart';
import '../../features/explore/presentation/pro_public_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/pro/data/pro_providers.dart';
import '../../features/pro/presentation/dashboard/pro_profile_preview_screen.dart';
import '../../features/pro/presentation/setup/pro_setup_flow.dart';
import '../../features/settings/presentation/map_licences_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/signup/data/signup_draft_store.dart';
import '../../features/signup/presentation/signup_wizard.dart';
import 'redirect.dart';

/// Re-runs the router redirect whenever the account, the draft or the pro
/// profile's setup routing ([proRoutingKey]) change.
///
/// Not on session events: the account rebuilds on every sign-in and sign-out,
/// and a session listener ran before that rebuild, showing the redirect a
/// stale "signed in, no account" that opened the wizard for a frame.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(accountProvider, (_, _) => notifyListeners());
    ref.listen(signupDraftProvider, (_, _) => notifyListeners());
    // Setup steps open once the profile has loaded and as its gaps close;
    // other profile writes leave routing alone.
    ref.listen(
      myProProvider.select(proRoutingKey),
      (_, _) => notifyListeners(),
    );
  }
}

/// What makes the router re-run its redirects; read by tests to check when
/// it fires.
final routerRefreshProvider = Provider<Listenable>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
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
      GoRoute(path: '/home', pageBuilder: (_, state) => _homePage(state)),
      // Explore's map view (`?view=map&lat=&lng=&z=`) on the same home page.
      GoRoute(path: '/explore', pageBuilder: (_, state) => _homePage(state)),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/map-data',
        builder: (_, _) => const MapLicencesScreen(),
      ),
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
          edit: state.uri.queryParameters['edit'] == '1',
        ),
      ),
      // Three segments, so neither `/pro/:id` nor `/pro/setup/:step` can
      // read it; declared before `/pro/:id` all the same.
      GoRoute(
        path: '/pro/me/preview',
        builder: (_, _) => const ProProfilePreviewScreen(),
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
  ref.onDispose(router.dispose);
  return router;
});

/// One page key for `/home` and `/explore`: switching between the list and
/// the map updates the page in place (no transition, the home keeps its
/// state) instead of replacing it.
const _homePageKey = ValueKey<String>('home');

Page<void> _homePage(GoRouterState state) => MaterialPage<void>(
  key: _homePageKey,
  child: ExploreLocationScope(
    location: ExploreLocation.fromUri(state.uri),
    child: const HomeScreen(),
  ),
);

bool _hasSession(Ref ref) => resolveHasSession(
  ref.read(sessionProvider),
  () => ref.read(authRepositoryProvider).currentSession,
);
