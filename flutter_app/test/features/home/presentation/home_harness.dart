import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/features/settings/presentation/map_licences_screen.dart';
import 'package:lemqes/features/settings/presentation/settings_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/harness.dart';
import '../../live/presentation/today/today_harness.dart'
    show quietLiveOverrides;
import '../../explore/presentation/explore_harness.dart'
    show
        FakeExploreRepository,
        FakeGeoRepository,
        FakePhotoUploader,
        PublicProRepository;

export '../../auth/presentation/harness.dart'
    show MockAccountRepository, MockAuthRepository, registerHarnessFallbacks;

const pro = Account(
  id: 'u1',
  fullName: 'Amine Benali',
  customerSpace: Space.men,
  proSpace: Space.men,
  activeRole: AppRole.barber,
  roles: {AppRole.customer, AppRole.barber},
);

class HomeHarness {
  HomeHarness(this.container, this.account, this.auth);

  final ProviderContainer container;
  final MockAccountRepository account;
  final MockAuthRepository auth;
}

/// Pumps [home] with a real accountProvider over a mocked repository.
///
/// [fetch] answers `fetchMine`; the default returns [account] every time.
/// The customer home's explore list searches an empty fake backend.
Future<HomeHarness> pumpHome(
  WidgetTester tester, {
  required Widget home,
  Account? account,
  Future<Account?> Function()? fetch,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    LocaleController.prefsKey: locale.languageCode,
    ThemeModeController.prefsKey: themeMode.name,
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = MockAuthRepository();
  when(() => auth.currentSession).thenReturn(testSession);
  when(() => auth.signOut()).thenAnswer((_) async {});
  final repo = MockAccountRepository();
  when(() => repo.fetchMine()).thenAnswer(
    (_) => fetch != null ? fetch() : Future<Account?>.value(account),
  );
  when(() => repo.setActiveRole(any())).thenAnswer((_) async {});
  when(() => repo.setCustomerSpace(any())).thenAnswer((_) async {});
  when(
    () => repo.addRole(
      any(),
      space: any(named: 'space'),
      businessName: any(named: 'businessName'),
    ),
  ).thenAnswer((_) async {});

  final container = ProviderContainer(
    // No automatic retry: the screen's own retry button is under test.
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      accountRepositoryProvider.overrideWithValue(repo),
      sessionProvider.overrideWith((ref) => Stream.value(testSession)),
      exploreRepositoryProvider.overrideWithValue(FakeExploreRepository()),
      exploreDebounceProvider.overrideWithValue(Duration.zero),
      proRepositoryProvider.overrideWithValue(PublicProRepository()),
      photoUploaderProvider.overrideWithValue(FakePhotoUploader()),
      geoRepositoryProvider.overrideWithValue(FakeGeoRepository()),
      // A pro lands on the Today tab, which reads live state.
      ...quietLiveOverrides(),
    ],
  );
  addTearDown(container.dispose);
  // Keeps the notifier alive: Riverpod 3 pauses unlistened providers.
  container.listen(accountProvider, (_, _) {});

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/map-data',
        builder: (_, _) => const MapLicencesScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('route:/auth')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: lemqesTheme(Brightness.light),
          darkTheme: lemqesTheme(Brightness.dark),
          themeMode: ref.watch(themeModeProvider),
          locale: ref.watch(localeProvider),
          localizationsDelegates: appDelegates,
          supportedLocales: supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  // Session, then account, then their listeners: each lands a frame later.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  return HomeHarness(container, repo, auth);
}

Completer<T> never<T>() => Completer<T>();
