import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lemqes/bootstrap.dart';
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test OTP numbers only (supabase/config.toml): the code is always 123456.
const _phone = '0550000001';
const _code = '123456';
const _typoPassword = 'lemqes-typo-0';
const _firstPassword = 'lemqes-test-1';
const _newPassword = 'lemqes-test-2';

/// Local GoTrue sends at most one SMS per number every 5 seconds.
const _smsInterval = Duration(seconds: 6);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // This binding leaves the real (GTK) text input attached so a person can
  // type; the test types through `enterText`, so the input is the test's.
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  final fr = lookupAppLocalizations(const Locale('fr'));

  testWidgets('sign up, switch role and space, log in, reset password', (
    tester,
  ) async {
    // `supabase db reset` leaves the previous run's session on disk. Cleared
    // before Supabase starts: its session recovery runs unawaited after
    // `initialize` and would restore a session read before a later clear.
    await (await SharedPreferences.getInstance()).clear();
    final prefs = await bootstrap();
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await prefs.setString(LocaleController.prefsKey, 'fr');

    await tester.pumpWidget(lemqesRoot(prefs));

    // Sign up: men's space, barber, Amine.
    await _tap(tester, find.byKey(const Key('tab_signup')));
    await _tap(tester, find.byKey(const Key('space_men')));
    await _tap(tester, find.byKey(const Key('primaryAction')));
    await _tap(tester, find.byKey(const Key('role_barber')));
    await _tap(tester, find.byKey(const Key('primaryAction')));
    await _enter(tester, const Key('nameField'), 'Amine');
    await _enter(tester, const Key('phoneField'), _phone);
    await _enter(tester, const Key('passwordField'), _typoPassword);
    await _enter(tester, const Key('confirmField'), _typoPassword);
    await _tap(tester, find.byKey(const Key('primaryAction')));
    await _waitFor(tester, find.byKey(const Key('codeField')));
    final typoCodeSentAt = DateTime.now();

    // Back from the code step to fix the password, then sign up again: the
    // password typed last must be the one that works (GoTrue keeps the first
    // for an unconfirmed number; the app sets the last after verification).
    await _tap(tester, find.byTooltip('Retour'));
    await _enter(tester, const Key('phoneField'), _phone);
    await _enter(tester, const Key('passwordField'), _firstPassword);
    await _enter(tester, const Key('confirmField'), _firstPassword);
    await _waitSmsInterval(typoCodeSentAt);
    await _tap(tester, find.byKey(const Key('primaryAction')));
    // Taken once the code step shows, so after GoTrue has sent the SMS.
    await _waitFor(tester, find.byKey(const Key('codeField')));
    final signupCodeSentAt = DateTime.now();
    await _enterCode(tester);

    // A new pro carries on into the profile setup (steps 5-7 of 7); leaving
    // it lands on the dashboard, which asks for the missing profile.
    await _waitFor(tester, find.byKey(const Key('displayNameField')));
    expect(find.text(fr.setupProfileTitle), findsOneWidget);
    await _tap(tester, find.byTooltip('Retour'));
    await _waitFor(tester, find.text(fr.homeProEmptyTitle));
    // The setup page leaves with a transition; its name field holds "Amine".
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (find.byKey(const Key('displayNameField')).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('dashComplete')), findsOneWidget);
    expect(find.text('Amine'), findsOneWidget);
    expect(find.text(fr.homeSpaceLabel('men')), findsOneWidget);

    // Every account holds the customer role too.
    await _tap(tester, find.byKey(const Key('roleSwitch')));
    await _tap(tester, find.byKey(const Key('role_customer')));
    await _waitFor(tester, find.byKey(const Key('spaceSwitch_women')));
    expect(find.text(fr.homeSpaceLabel('men')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('spaceSwitch_women')));
    await _waitFor(tester, find.text(fr.homeSpaceLabel('women')));
    expect(find.text(fr.homeSpaceLabel('men')), findsNothing);

    // RLS from the real client: own row only, server-side role checks.
    final profiles = await client.from('profiles').select();
    expect(profiles, hasLength(1));
    await expectLater(
      client.rpc<void>('set_active_role', params: {'p_role': 'home_artist'}),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('role_not_held'),
        ),
      ),
    );

    await _signOut(tester);

    // Log in with phone and password.
    await _logIn(tester, _firstPassword);
    await _waitFor(tester, find.text(fr.homeSpaceLabel('women')));
    await _signOut(tester);

    // Reset the password with an SMS code.
    await _tap(tester, find.byKey(const Key('forgotPassword')));
    await _enter(tester, const Key('phoneField'), _phone);
    await _waitSmsInterval(signupCodeSentAt);
    await _tap(tester, find.byKey(const Key('primaryAction')));
    await _enterCode(tester);
    await _waitFor(tester, find.byKey(const Key('confirmField')));
    await _enter(tester, const Key('passwordField'), _newPassword);
    await _enter(tester, const Key('confirmField'), _newPassword);
    await _tap(tester, find.byKey(const Key('primaryAction')));
    await _waitFor(tester, find.text(fr.homeSpaceLabel('women')));
    await _signOut(tester);

    // The old password no longer works.
    await _logIn(tester, _firstPassword);
    await _waitFor(tester, find.text(fr.errorInvalidCredentials));
    expect(find.byKey(const Key('tab_login')), findsOneWidget);
  });
}

Future<void> _waitSmsInterval(DateTime sentAt) async {
  final wait = _smsInterval - DateTime.now().difference(sentAt);
  if (wait > Duration.zero) await Future<void>.delayed(wait);
}

/// Pumps real frames until [finder] matches; the backend answers in real time
/// and spinners never settle, so `pumpAndSettle` cannot be used.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder; on screen: ${_texts()}',
  );
}

/// The visible texts, to say where a timed-out wait was stuck.
String _texts() => [
  for (final e in find.byType(Text).hitTestable().evaluate())
    (e.widget as Text).data ?? '',
].where((t) => t.isNotEmpty).join(' | ');

/// Waits until [finder]'s route has finished its transition. Mid-transition
/// the outgoing page can still take a tap meant for the incoming one: a
/// field then never gets focus and the text typed into it is lost (the form
/// later refuses to submit, seen as a sign-up that never reaches the code).
Future<void> _waitForSettledRoute(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  bool settled() {
    final route = ModalRoute.of(finder.evaluate().first);
    return route == null ||
        (route.isCurrent &&
            (route.animation?.isCompleted ?? true) &&
            (route.secondaryAnimation?.isDismissed ?? true));
  }

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!settled()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Route of $finder never settled');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitForSettledRoute(tester, finder);
  await tester.ensureVisible(finder.first);
  await _waitFor(tester, finder.hitTestable());
  await tester.tap(finder.hitTestable().first);
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await _waitForSettledRoute(tester, finder);
  // A route sliding in over one with the same field (login -> reset) keeps
  // both onstage until the transition ends.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().length > 1 && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
  // Fail here, not 30 s later at a form that never submits.
  final field = tester.widget<EditableText>(
    find.descendant(of: finder, matching: find.byType(EditableText)).first,
  );
  expect(field.controller.text, text, reason: 'text typed into $key');
}

Future<void> _enterCode(WidgetTester tester) async {
  final field = find.descendant(
    of: find.byKey(const Key('codeField')),
    matching: find.byType(EditableText),
  );
  await _waitForSettledRoute(tester, field);
  await tester.enterText(field, _code);
  await tester.pump();
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('settings')));
  await _tap(tester, find.byKey(const Key('signOut')));
  await _tap(tester, find.byKey(const Key('confirmSignOut')));
  await _waitFor(tester, find.byKey(const Key('tab_login')));
}

Future<void> _logIn(WidgetTester tester, String password) async {
  await _enter(tester, const Key('phoneField'), _phone);
  await _enter(tester, const Key('passwordField'), password);
  await _tap(tester, find.byKey(const Key('primaryAction')));
}
