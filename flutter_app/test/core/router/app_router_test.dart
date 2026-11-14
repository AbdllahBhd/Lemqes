import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/router/app_router.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/auth/presentation/auth_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/harness.dart';

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required Session? currentSession,
  required Stream<Session?> sessions,
}) async {
  SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'fr'});
  final prefs = await SharedPreferences.getInstance();
  final auth = MockAuthRepository();
  when(() => auth.currentSession).thenReturn(currentSession);
  final account = MockAccountRepository();
  when(() => account.fetchMine()).thenAnswer((_) async => null);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      accountRepositoryProvider.overrideWithValue(account),
      sessionProvider.overrideWith((ref) => sessions),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
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
}
