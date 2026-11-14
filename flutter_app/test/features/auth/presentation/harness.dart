import 'dart:async';
import 'dart:convert';

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
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:lemqes/features/auth/presentation/auth_screen.dart';
import 'package:lemqes/features/auth/presentation/reset_password_screen.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/data/signup_draft_store.dart';
import 'package:lemqes/features/signup/presentation/signup_wizard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

final testSession = Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

const testAccount = Account(
  id: 'u1',
  fullName: 'Amine Benali',
  customerSpace: Space.men,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: {AppRole.customer},
);

void registerHarnessFallbacks() {
  registerFallbackValue(Space.men);
  registerFallbackValue(AppRole.customer);
}

class Harness {
  Harness(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;

  String get location => router.routerDelegate.currentConfiguration.uri.path;

  SignupDraft? get draft => container.read(signupDraftProvider);
}

/// Pumps the real auth and wizard screens behind a router without the
/// session redirect, so each screen is exercised on its own.
Future<Harness> pumpApp(
  WidgetTester tester, {
  required String location,
  required MockAuthRepository auth,
  MockAccountRepository? account,
  Session? session,
  SignupDraft? draft,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    LocaleController.prefsKey: locale.languageCode,
    ThemeModeController.prefsKey: themeMode.name,
    if (draft != null) SignupDraftStore.prefsKey: jsonEncode(draft.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  when(() => auth.currentSession).thenReturn(session);
  final accountRepo = account ?? MockAccountRepository();
  if (account == null) {
    when(() => accountRepo.fetchMine()).thenAnswer((_) async => null);
  }

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      accountRepositoryProvider.overrideWithValue(accountRepo),
      sessionProvider.overrideWith((ref) => Stream.value(session)),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/auth/reset',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/signup/:step',
        builder: (_, state) =>
            SignupWizard(step: state.pathParameters['step']!),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('route:/home')),
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
  await tester.pump();
  return Harness(router, container);
}

/// A future that only resolves when the test says so.
Completer<T> pending<T>() => Completer<T>();

Finder byKey(String key) => find.byKey(Key(key));

/// The text currently in a field found by [key].
String fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: byKey(key), matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pump();
}
