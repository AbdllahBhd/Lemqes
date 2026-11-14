import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'harness.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Future<void> fill(WidgetTester tester, String phone) async {
    await tester.enterText(byKey('phoneField'), phone);
    await tester.enterText(byKey('passwordField'), 'secret123');
  }

  void stubSignIn(Future<void> Function() answer) {
    when(
      () => auth.signIn(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  testWidgets('invalid phone shows a field error and does not sign in', (
    tester,
  ) async {
    await pumpApp(tester, location: '/auth', auth: auth);
    await fill(tester, '0123 45');
    await tapKey(tester, 'primaryAction');

    expect(
      find.text('Entrez un numéro mobile algérien valide (05, 06 ou 07).'),
      findsOneWidget,
    );
    verifyNever(
      () => auth.signIn(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('valid input signs in with the E.164 number', (tester) async {
    stubSignIn(() async {});
    await pumpApp(tester, location: '/auth', auth: auth);
    await fill(tester, '0550 12 34 56');
    await tapKey(tester, 'primaryAction');

    verify(() => auth.signIn(phone: '+213550123456', password: 'secret123'))
        .called(1);
  });

  testWidgets('InvalidCredentials shows the failure banner', (tester) async {
    stubSignIn(() async => throw const InvalidCredentials());
    await pumpApp(tester, location: '/auth', auth: auth);
    await fill(tester, '0550123456');
    await tapKey(tester, 'primaryAction');
    await tester.pump();

    expect(find.text('Numéro ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('RateLimited shows when to retry', (tester) async {
    stubSignIn(() async => throw const RateLimited(Duration(seconds: 45)));
    await pumpApp(tester, location: '/auth', auth: auth);
    await fill(tester, '0550123456');
    await tapKey(tester, 'primaryAction');
    await tester.pump();

    expect(
      find.text('Trop de tentatives. Réessayez dans 45 s.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a loading state while signing in and ignores re-taps', (
    tester,
  ) async {
    final request = pending<void>();
    stubSignIn(() => request.future);
    await pumpApp(tester, location: '/auth', auth: auth);
    await fill(tester, '0550123456');
    await tapKey(tester, 'primaryAction');

    expect(
      find.descendant(
        of: byKey('primaryAction'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'primaryAction');
    verify(
      () => auth.signIn(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).called(1);

    request.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('forgot password opens the reset screen', (tester) async {
    final h = await pumpApp(tester, location: '/auth', auth: auth);
    await tapKey(tester, 'forgotPassword');
    await tester.pumpAndSettle();

    expect(h.location, '/auth/reset');
  });

  testWidgets('the sign-up tab starts the wizard at the space step', (
    tester,
  ) async {
    final h = await pumpApp(tester, location: '/auth', auth: auth);
    await tapKey(tester, 'tab_signup');
    await tester.pumpAndSettle();

    expect(h.location, '/signup/space');
  });
}
