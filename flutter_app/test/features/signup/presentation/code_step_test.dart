import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/presentation/signup_completion.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth/presentation/harness.dart';

const _phone = '+213550123456';
const _draft = SignupDraft(
  space: Space.women,
  role: AppRole.salonOwner,
  fullName: 'Lina Haddad',
  businessName: 'Institut Lina',
  phone: _phone,
);

void main() {
  late MockAuthRepository auth;
  late MockAccountRepository account;

  setUpAll(registerHarnessFallbacks);
  setUp(() {
    auth = MockAuthRepository();
    account = MockAccountRepository();
    when(() => account.fetchMine()).thenAnswer((_) async => null);
    when(
      () => account.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    ).thenAnswer((_) async => testAccount);
  });

  void stubVerify(Future<void> Function() answer) {
    when(
      () => auth.verifySignUpCode(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<Harness> pumpCode(WidgetTester tester) => pumpApp(
    tester,
    location: '/signup/code',
    auth: auth,
    account: account,
    draft: _draft,
  );

  testWidgets('pasting 123456 verifies once', (tester) async {
    stubVerify(() async {});
    await pumpCode(tester);
    await tester.enterText(byKey('codeField'), '123456');
    await tester.pump();

    verify(() => auth.verifySignUpCode(phone: _phone, code: '123456'))
        .called(1);
  });

  testWidgets('Eastern Arabic digits are accepted', (tester) async {
    stubVerify(() async {});
    await pumpCode(tester);
    await tester.enterText(byKey('codeField'), '١٢٣٤٥٦');
    await tester.pump();

    verify(() => auth.verifySignUpCode(phone: _phone, code: '123456'))
        .called(1);
  });

  testWidgets('InvalidOrExpiredCode shows a message and clears the field', (
    tester,
  ) async {
    stubVerify(() async => throw const InvalidOrExpiredCode());
    await pumpCode(tester);
    await tester.enterText(byKey('codeField'), '123456');
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Code incorrect ou expiré. Vérifiez-le ou demandez un nouveau code.',
      ),
      findsOneWidget,
    );
    expect(fieldText(tester, 'codeField'), isEmpty);
    verifyNever(
      () => account.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    );
  });

  testWidgets('resend is enabled only after 60 seconds', (tester) async {
    when(() => auth.resendSignUpCode(any())).thenAnswer((_) async {});
    await pumpCode(tester);

    expect(tester.widget<TextButton>(byKey('resendCode')).onPressed, isNull);
    await tester.pump(const Duration(seconds: 59));
    expect(tester.widget<TextButton>(byKey('resendCode')).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextButton>(byKey('resendCode')).onPressed, isNotNull);
    await tapKey(tester, 'resendCode');
    verify(() => auth.resendSignUpCode(_phone)).called(1);
    expect(tester.widget<TextButton>(byKey('resendCode')).onPressed, isNull);
  });

  testWidgets('success completes sign-up from the draft, then clears it', (
    tester,
  ) async {
    stubVerify(() async {});
    final h = await pumpCode(tester);
    await tester.enterText(byKey('codeField'), '123456');
    // The finishing spinner never settles; let the completion chain run.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Création de votre compte…'), findsOneWidget);

    verify(
      () => account.completeSignup(
        fullName: 'Lina Haddad',
        space: Space.women,
        role: AppRole.salonOwner,
        businessName: 'Institut Lina',
      ),
    ).called(1);
    expect(h.draft, isNull);
  });

  group('the password typed last wins', () {
    // GoTrue keeps the first password when an unconfirmed number signs up
    // again; the code step sets the last one once the code is verified.
    testWidgets('it is set after verification, before the profile', (
      tester,
    ) async {
      final calls = <String>[];
      stubVerify(() async => calls.add('verify'));
      when(() => auth.confirmSignUpPassword(any())).thenAnswer((_) async {
        calls.add('password');
      });
      when(
        () => account.completeSignup(
          fullName: any(named: 'fullName'),
          space: any(named: 'space'),
          role: any(named: 'role'),
          businessName: any(named: 'businessName'),
        ),
      ).thenAnswer((_) async {
        calls.add('profile');
        return testAccount;
      });
      final h = await pumpCode(tester);
      h.container.read(signupPasswordProvider.notifier).set('second-pass');
      await tester.enterText(byKey('codeField'), '123456');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      verify(() => auth.confirmSignUpPassword('second-pass')).called(1);
      expect(calls, ['verify', 'password', 'profile']);
      expect(h.container.read(signupPasswordProvider), isNull);
    });

    testWidgets('a failure to set it offers a retry', (tester) async {
      stubVerify(() async {});
      var fail = true;
      when(() => auth.confirmSignUpPassword(any())).thenAnswer((_) async {
        if (fail) throw const NetworkFailure();
      });
      final h = await pumpCode(tester);
      h.container.read(signupPasswordProvider.notifier).set('second-pass');
      await tester.enterText(byKey('codeField'), '123456');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.text('Réessayer'), findsOneWidget);
      verifyNever(
        () => account.completeSignup(
          fullName: any(named: 'fullName'),
          space: any(named: 'space'),
          role: any(named: 'role'),
          businessName: any(named: 'businessName'),
        ),
      );

      fail = false;
      await tester.tap(find.text('Réessayer'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      verify(() => auth.confirmSignUpPassword('second-pass')).called(2);
      expect(h.draft, isNull);
    });

    testWidgets('without one (a resumed sign-up) nothing is set', (
      tester,
    ) async {
      stubVerify(() async {});
      await pumpCode(tester);
      await tester.enterText(byKey('codeField'), '123456');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      verifyNever(() => auth.confirmSignUpPassword(any()));
    });
  });

  testWidgets('going back to edit the details forgets the sent number', (
    tester,
  ) async {
    final h = await pumpCode(tester);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(h.location, '/signup/credentials');
    // A later trip back to sign-in must not bounce to the code step.
    expect(h.draft?.phone, isNull);
    expect(h.draft?.fullName, 'Lina Haddad');
    expect(h.draft?.businessName, 'Institut Lina');
    expect(h.draft?.role, AppRole.salonOwner);
  });

  testWidgets('going back to edit the details forgets the typed password', (
    tester,
  ) async {
    final h = await pumpCode(tester);
    h.container.read(signupPasswordProvider.notifier).set('stale-pass');
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    // Otherwise a different account signing in later would receive it.
    expect(h.container.read(signupPasswordProvider), isNull);
  });

  testWidgets('back to sign-in clears the draft', (tester) async {
    final h = await pumpCode(tester);
    await tapKey(tester, 'backToLogin');
    await tester.pumpAndSettle();

    expect(h.draft, isNull);
    expect(h.location, '/auth');
  });

  testWidgets('signed in already: finishes the profile without a code', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      location: '/signup/code',
      auth: auth,
      account: account,
      session: testSession,
      draft: _draft,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(byKey('codeField'), findsNothing);
    verifyNever(
      () => auth.verifySignUpCode(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    );
    verify(
      () => account.completeSignup(
        fullName: 'Lina Haddad',
        space: Space.women,
        role: AppRole.salonOwner,
        businessName: 'Institut Lina',
      ),
    ).called(1);
    expect(h.draft, isNull);
  });

  testWidgets('a profile failure offers a retry, not an endless spinner', (
    tester,
  ) async {
    when(
      () => account.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    ).thenAnswer((_) async => throw const NetworkAccountFailure());
    await pumpApp(
      tester,
      location: '/signup/code',
      auth: auth,
      account: account,
      session: testSession,
      draft: _draft,
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Connexion impossible. Vérifiez votre réseau.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
