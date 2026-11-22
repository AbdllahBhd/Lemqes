import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';

import '../../auth/presentation/harness.dart';

const _proKeys = ['role_barber', 'role_home_artist', 'role_salon_owner'];

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  testWidgets('women space shows the women wording', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/role',
      auth: auth,
      draft: const SignupDraft(space: Space.women),
    );

    expect(find.text('Je suis cliente'), findsOneWidget);
    expect(find.text('Coiffeuse / Esthéticienne'), findsOneWidget);
    expect(find.text('Beauté à domicile'), findsOneWidget);
    expect(find.text('Propriétaire d’institut ou de salon'), findsOneWidget);
    expect(find.text('Je suis client'), findsNothing);
    expect(find.text('Coiffeur / Barbier'), findsNothing);
  });

  testWidgets('men space shows the men wording', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/role',
      auth: auth,
      draft: const SignupDraft(space: Space.men),
    );

    expect(find.text('Je suis client'), findsOneWidget);
    expect(find.text('Coiffeur / Barbier'), findsOneWidget);
    expect(find.text('Barbier à domicile'), findsOneWidget);
    expect(find.text('Propriétaire de barber shop'), findsOneWidget);
  });

  testWidgets('only the customer card carries the free badge', (tester) async {
    await pumpApp(
      tester,
      location: '/signup/role',
      auth: auth,
      draft: const SignupDraft(space: Space.men),
    );

    expect(
      find.descendant(
        of: byKey('role_customer'),
        matching: find.text('Gratuit'),
      ),
      findsOneWidget,
    );
    for (final key in _proKeys) {
      expect(
        find.descendant(
          of: byKey(key),
          matching: find.textContaining('Gratuit'),
        ),
        findsNothing,
        reason: key,
      );
      expect(
        find.descendant(of: byKey(key), matching: find.textContaining('mois')),
        findsNothing,
        reason: key,
      );
    }
  });

  testWidgets('choosing a role saves it and continues to credentials', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      location: '/signup/role',
      auth: auth,
      draft: const SignupDraft(space: Space.men),
    );
    await tapKey(tester, 'role_barber');
    expect(h.draft!.role, AppRole.barber);

    await tapKey(tester, 'primaryAction');
    await tester.pumpAndSettle();
    expect(h.location, '/signup/credentials');
  });

  testWidgets('a pro with a profile counts seven steps, others four', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/signup/role',
      auth: auth,
      draft: const SignupDraft(space: Space.men, role: AppRole.customer),
    );
    expect(find.text('Étape 2 sur 4'), findsOneWidget);

    // Space, role, credentials, code, then profile, location, services and
    // hours.
    await tapKey(tester, 'role_barber');
    expect(find.text('Étape 2 sur 8'), findsOneWidget);
    await tapKey(tester, 'role_home_artist');
    expect(find.text('Étape 2 sur 8'), findsOneWidget);

    // Salon setup comes with salons (M7): no extra steps yet.
    await tapKey(tester, 'role_salon_owner');
    expect(find.text('Étape 2 sur 4'), findsOneWidget);
  });
}
