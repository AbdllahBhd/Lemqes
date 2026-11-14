import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart';

const _customer = SignupDraft(space: Space.men, role: AppRole.customer);

void main() {
  late MockAuthRepository auth;

  setUpAll(registerHarnessFallbacks);
  setUp(() => auth = MockAuthRepository());

  void stubSignUp(Future<void> Function() answer) {
    when(
      () => auth.signUp(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> fill(
    WidgetTester tester, {
    String password = 'secret123',
    String confirm = 'secret123',
  }) async {
    await tester.enterText(byKey('nameField'), 'Amine Benali');
    await tester.enterText(byKey('phoneField'), '0550 12 34 56');
    await tester.enterText(byKey('passwordField'), password);
    await tester.enterText(byKey('confirmField'), confirm);
    await tester.pump();
  }

  testWidgets('business name is asked only of a salon owner', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: const SignupDraft(space: Space.men, role: AppRole.salonOwner),
    );
    expect(byKey('businessNameField'), findsOneWidget);
    expect(byKey('nameField'), findsOneWidget);
  });

  testWidgets('business name is not asked of a barber', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: const SignupDraft(space: Space.men, role: AppRole.barber),
    );
    expect(byKey('businessNameField'), findsNothing);
  });

  testWidgets('a 7-character password is refused', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: _customer,
    );
    await fill(tester, password: '1234567', confirm: '1234567');
    await tapKey(tester, 'primaryAction');

    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    verifyNever(
      () => auth.signUp(
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('a mismatching confirmation shows a live hint', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: _customer,
    );
    await fill(tester, confirm: 'secret12');
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );

    await tester.enterText(byKey('confirmField'), 'secret123');
    await tester.pump();
    expect(find.text('Les mots de passe correspondent.'), findsOneWidget);
  });

  testWidgets('saves the phone before signing up, then opens the code step', (
    tester,
  ) async {
    final request = pending<void>();
    stubSignUp(() => request.future);
    final h = await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: _customer,
    );
    await fill(tester);
    await tapKey(tester, 'primaryAction');

    verify(() => auth.signUp(phone: '+213550123456', password: 'secret123'))
        .called(1);
    expect(h.draft!.phone, '+213550123456');
    expect(h.draft!.fullName, 'Amine Benali');

    request.complete();
    await tester.pumpAndSettle();
    expect(h.location, '/signup/code');
  });

  testWidgets('PhoneAlreadyRegistered offers sign-in and reset', (
    tester,
  ) async {
    stubSignUp(() async => throw const PhoneAlreadyRegistered());
    final h = await pumpApp(
      tester,
      location: '/signup/credentials',
      auth: auth,
      draft: _customer,
    );
    await fill(tester);
    await tapKey(tester, 'primaryAction');
    await tester.pump();

    expect(
      find.text(
        'Ce numéro a déjà un compte LEMQES. Connectez-vous ou '
        'réinitialisez votre mot de passe.',
      ),
      findsOneWidget,
    );
    expect(byKey('alreadyRegisteredSignIn'), findsOneWidget);
    expect(byKey('alreadyRegisteredReset'), findsOneWidget);
    expect(find.textContaining('créé'), findsNothing);
    // A refused number must not resume at the code step on restart.
    expect(h.draft!.phone, isNull);
    expect(h.location, '/signup/credentials');

    await tapKey(tester, 'alreadyRegisteredReset');
    await tester.pumpAndSettle();
    expect(h.location, '/auth/reset');
  });

  testWidgets(
    'with a session and no profile: names only, completeSignup, no signUp',
    (tester) async {
      final account = MockAccountRepository();
      when(() => account.fetchMine()).thenAnswer((_) async => null);
      when(
        () => account.completeSignup(
          fullName: any(named: 'fullName'),
          space: any(named: 'space'),
          role: any(named: 'role'),
          businessName: any(named: 'businessName'),
        ),
      ).thenAnswer((_) async => testAccount);
      final h = await pumpApp(
        tester,
        location: '/signup/credentials',
        auth: auth,
        account: account,
        session: testSession,
        draft: _customer,
      );
      await tester.pump();

      expect(byKey('phoneField'), findsNothing);
      expect(byKey('passwordField'), findsNothing);
      expect(byKey('confirmField'), findsNothing);

      await tester.enterText(byKey('nameField'), 'Amine Benali');
      await tapKey(tester, 'primaryAction');
      await tester.pumpAndSettle();

      verify(
        () => account.completeSignup(
          fullName: 'Amine Benali',
          space: Space.men,
          role: AppRole.customer,
        ),
      ).called(1);
      verifyNever(
        () => auth.signUp(
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      );
      expect(h.draft, isNull);
    },
  );
}
