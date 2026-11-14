import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/router/app_router.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:lemqes/features/auth/presentation/auth_screen.dart';
import 'package:lemqes/features/settings/presentation/settings_screen.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/data/signup_draft_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/harness.dart';

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required Session? currentSession,
  required Stream<Session?> sessions,
  MockAuthRepository? auth,
  MockAccountRepository? account,
  SignupDraft? draft,
  void Function(ProviderContainer)? onContainer,
}) async {
  SharedPreferences.setMockInitialValues({
    LocaleController.prefsKey: 'fr',
    if (draft != null) SignupDraftStore.prefsKey: jsonEncode(draft.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final authRepo = auth ?? MockAuthRepository();
  when(() => authRepo.currentSession).thenReturn(currentSession);
  final accountRepo = account ?? MockAccountRepository();
  if (account == null) {
    when(() => accountRepo.fetchMine()).thenAnswer((_) async => null);
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountRepositoryProvider.overrideWithValue(accountRepo),
      sessionProvider.overrideWith((ref) => sessions),
    ],
  );
  addTearDown(container.dispose);
  onContainer?.call(container);
  // Listened like LemqesApp watches it: Riverpod 3 pauses unlistened
  // providers, which would hold back the session stream.
  final router = container.listen(routerProvider, (_, _) {}).read();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: lemqesTheme(Brightness.light),
        locale: const Locale('fr'),
        localizationsDelegates: appDelegates,
        supportedLocales: supportedLocales,
      ),
    ),
  );
  return router;
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('a stored session skips /auth while the session stream loads', (
    tester,
  ) async {
    final never = StreamController<Session?>();
    addTearDown(never.close);
    final router = await _pumpRouter(
      tester,
      currentSession: testSession,
      sessions: never.stream,
    );

    expect(_path(router), '/home');
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('no stored session goes to /auth while the stream loads', (
    tester,
  ) async {
    final never = StreamController<Session?>();
    addTearDown(never.close);
    final router = await _pumpRouter(
      tester,
      currentSession: null,
      sessions: never.stream,
    );
    await tester.pump();

    expect(_path(router), '/auth');
  });

  testWidgets('reset stays put once its code signs the user in', (
    tester,
  ) async {
    final sessions = StreamController<Session?>();
    addTearDown(sessions.close);
    final router = await _pumpRouter(
      tester,
      currentSession: null,
      sessions: sessions.stream,
    );
    sessions.add(null);
    await tester.pump();
    router.go('/auth/reset');
    await tester.pump();

    sessions.add(testSession);
    await tester.pump();
    await tester.pump();

    expect(_path(router), '/auth/reset');
  });

  testWidgets('signing in goes straight home, never through the wizard', (
    tester,
  ) async {
    final sessions = StreamController<Session?>.broadcast();
    addTearDown(sessions.close);
    final auth = MockAuthRepository();
    final account = MockAccountRepository();
    var signedIn = false;
    final profile = Completer<Account?>();
    when(() => account.fetchMine())
        .thenAnswer((_) => signedIn ? profile.future : Future.value(null));
    final router = await _pumpRouter(
      tester,
      currentSession: null,
      sessions: sessions.stream,
      auth: auth,
      account: account,
    );
    sessions.add(null);
    await tester.pump();
    expect(_path(router), '/auth');
    final paths = <String>[_path(router)];
    void listener() {
      final p = _path(router);
      if (paths.last != p) paths.add(p);
    }

    router.routerDelegate.addListener(listener);
    addTearDown(() => router.routerDelegate.removeListener(listener));

    signedIn = true;
    when(() => auth.currentSession).thenReturn(testSession);
    sessions.add(testSession);
    await tester.pump();
    await tester.pump();
    profile.complete(testAccount);
    await tester.pump();
    await tester.pump();

    expect(paths, ['/auth', '/home']);
  });

  testWidgets('a failed switch leaves settings reachable', (tester) async {
    final sessions = StreamController<Session?>.broadcast();
    addTearDown(sessions.close);
    final account = MockAccountRepository();
    when(() => account.fetchMine()).thenAnswer((_) async => testAccount);
    when(() => account.setActiveRole(AppRole.barber))
        .thenThrow(const NetworkAccountFailure());
    late ProviderContainer container;
    final router = await _pumpRouter(
      tester,
      currentSession: testSession,
      sessions: sessions.stream,
      account: account,
      onContainer: (c) => container = c,
    );
    sessions.add(testSession);
    await tester.pump();
    await tester.pump();
    expect(_path(router), '/home');

    await container.read(accountProvider.notifier).switchRole(AppRole.barber);
    await tester.pump();
    expect(container.read(accountProvider).hasError, isTrue);
    router.push('/settings');
    await tester.pump();
    await tester.pump();

    // A push keeps the base location; the top route is the pushed one.
    expect(router.state.uri.path, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('sign-up completion through the real router', () {
    const draft = SignupDraft(
      space: Space.men,
      role: AppRole.barber,
      fullName: 'Amine Benali',
      phone: '+213550123456',
    );

    late MockAuthRepository auth;
    late MockAccountRepository account;
    late StreamController<Session?> sessions;
    late bool profileCreated;

    setUpAll(registerHarnessFallbacks);

    setUp(() {
      auth = MockAuthRepository();
      account = MockAccountRepository();
      sessions = StreamController<Session?>.broadcast();
      addTearDown(sessions.close);
      profileCreated = false;
      when(() => account.fetchMine())
          .thenAnswer((_) async => profileCreated ? testAccount : null);
      when(
        () => account.completeSignup(
          fullName: any(named: 'fullName'),
          space: any(named: 'space'),
          role: any(named: 'role'),
          businessName: any(named: 'businessName'),
        ),
      ).thenAnswer((_) async {
        profileCreated = true;
        return testAccount;
      });
    });

    /// Records every location the router shows.
    List<String> track(GoRouter router) {
      final paths = <String>[_path(router)];
      void listener() {
        final p = _path(router);
        if (paths.last != p) paths.add(p);
      }

      router.routerDelegate.addListener(listener);
      addTearDown(() => router.routerDelegate.removeListener(listener));
      return paths;
    }

    Future<void> settle(WidgetTester tester) async {
      // The code step's countdown and spinner never settle; step time instead.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
      'verify signs in with no profile: stays on the code step, then home',
      (tester) async {
        when(
          () => auth.verifySignUpCode(
            phone: any(named: 'phone'),
            code: any(named: 'code'),
          ),
        ).thenAnswer((_) async {
          when(() => auth.currentSession).thenReturn(testSession);
          sessions.add(testSession);
        });
        late ProviderContainer container;
        final router = await _pumpRouter(
          tester,
          currentSession: null,
          sessions: sessions.stream,
          auth: auth,
          account: account,
          draft: draft,
          onContainer: (c) => container = c,
        );
        sessions.add(null);
        await settle(tester);
        expect(_path(router), '/signup/code');
        final paths = track(router);

        await tester.enterText(byKey('codeField'), '123456');
        await settle(tester);

        verify(
          () => account.completeSignup(
            fullName: 'Amine Benali',
            space: Space.men,
            role: AppRole.barber,
            businessName: null,
          ),
        ).called(1);
        expect(paths, ['/signup/code', '/home']);
        expect(container.read(signupDraftProvider), isNull);
      },
    );

    testWidgets('cold start with a session and a draft finishes at home', (
      tester,
    ) async {
      late ProviderContainer container;
      final router = await _pumpRouter(
        tester,
        currentSession: testSession,
        sessions: sessions.stream,
        auth: auth,
        account: account,
        draft: draft,
        onContainer: (c) => container = c,
      );
      final paths = track(router);
      sessions.add(testSession);
      await settle(tester);

      // No detour via home: the code step resumes the profile creation.
      expect(paths, ['/signup/code', '/home']);
      verifyNever(
        () => auth.verifySignUpCode(
          phone: any(named: 'phone'),
          code: any(named: 'code'),
        ),
      );
      verify(
        () => account.completeSignup(
          fullName: any(named: 'fullName'),
          space: any(named: 'space'),
          role: any(named: 'role'),
          businessName: any(named: 'businessName'),
        ),
      ).called(1);
      expect(container.read(signupDraftProvider), isNull);
    });
  });
}
