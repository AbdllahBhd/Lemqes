import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'harness.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  testWidgets('phone, code, then new password, in order', (tester) async {
    when(() => auth.sendResetCode(any())).thenAnswer((_) async {});
    when(
      () => auth.verifyResetCode(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async {});
    when(() => auth.setNewPassword(any())).thenAnswer((_) async {});
    final h = await pumpApp(tester, location: '/auth/reset', auth: auth);

    expect(byKey('codeField'), findsNothing);
    expect(byKey('passwordField'), findsNothing);
    await tester.enterText(byKey('phoneField'), '0550 12 34 56');
    await tapKey(tester, 'primaryAction');
    await tester.pump();
    verify(() => auth.sendResetCode('+213550123456')).called(1);

    expect(byKey('phoneField'), findsNothing);
    await tester.enterText(byKey('codeField'), '654321');
    await tester.pump();
    await tester.pump();
    verify(() => auth.verifyResetCode(phone: '+213550123456', code: '654321'))
        .called(1);

    expect(byKey('codeField'), findsNothing);
    await tester.enterText(byKey('passwordField'), 'newpass123');
    await tester.enterText(byKey('confirmField'), 'newpass123');
    await tapKey(tester, 'primaryAction');
    await tester.pump();
    verify(() => auth.setNewPassword('newpass123')).called(1);

    await tester.pump();
    expect(find.text('Mot de passe modifié.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(h.location, '/home');
  });

  testWidgets('an unknown number says so and links to sign-up', (tester) async {
    when(() => auth.sendResetCode(any()))
        .thenAnswer((_) async => throw const PhoneNotRegistered());
    final h = await pumpApp(tester, location: '/auth/reset', auth: auth);
    await tester.enterText(byKey('phoneField'), '0550123456');
    await tapKey(tester, 'primaryAction');
    await tester.pump();

    expect(
      find.text('Aucun compte n’est associé à ce numéro.'),
      findsOneWidget,
    );
    await tapKey(tester, 'resetCreateAccount');
    await tester.pumpAndSettle();
    expect(h.location, '/signup/space');
  });

  testWidgets('a mismatching new password is refused', (tester) async {
    when(() => auth.sendResetCode(any())).thenAnswer((_) async {});
    when(
      () => auth.verifyResetCode(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async {});
    await pumpApp(tester, location: '/auth/reset', auth: auth);
    await tester.enterText(byKey('phoneField'), '0550123456');
    await tapKey(tester, 'primaryAction');
    await tester.pump();
    await tester.enterText(byKey('codeField'), '654321');
    await tester.pump();
    await tester.pump();

    await tester.enterText(byKey('passwordField'), 'newpass123');
    await tester.enterText(byKey('confirmField'), 'newpass12');
    await tapKey(tester, 'primaryAction');
    verifyNever(() => auth.setNewPassword(any()));
  });
}
