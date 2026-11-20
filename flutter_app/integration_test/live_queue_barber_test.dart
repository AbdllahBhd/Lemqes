import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/bootstrap.dart';
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_helpers.dart';

/// The barber side of the live queue against the local stack: the app is the
/// seeded men barber; the customers are raw clients (other devices). Run by
/// scripts/integration.sh after live_seed.sql.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  final locale = Locale(shots.startsWith('ar') ? 'ar' : 'fr');
  final dark = shots.endsWith('dark');
  final l10n = lookupAppLocalizations(locale);
  final shotKey = GlobalKey();

  testWidgets('a barber runs the queue; remote customers follow it', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).clear();
    final prefs = await bootstrap();
    final app = Supabase.instance.client;
    await app.auth.signOut();
    await prefs.setString(LocaleController.prefsKey, locale.languageCode);
    await prefs.setString(
      ThemeModeController.prefsKey,
      dark ? ThemeMode.dark.name : ThemeMode.light.name,
    );
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final karim = await signedUp(menCustomerPhone, name: 'Karim', space: 'men');
    final walid = await signedIn(controlPhone);
    addTearDown(karim.dispose);
    addTearDown(walid.dispose);
    // Both RPCs return one row: an object, or a one-row (maybe empty) list.
    Map<String, dynamic>? row(Object? raw) => switch (raw) {
      final List<dynamic> l =>
        l.isEmpty ? null : l.single as Map<String, dynamic>,
      final Map<String, dynamic> m => m['entry_id'] == null ? null : m,
      _ => null,
    };
    Future<Map<String, dynamic>> join(SupabaseClient c) async => row(
      await c.rpc<Object?>(
        'join_queue',
        params: {
          'p_pro_id': menProId,
          'p_service_id': cutServiceId,
          'p_request_id': newRequestId(),
        },
      ),
    )!;
    Future<String?> ticketState(SupabaseClient c) async =>
        row(await c.rpc<Object?>('my_ticket'))?['state'] as String?;

    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const LemqesApp(),
        ),
      ),
    );
    Future<void> shot(String name) => capture(tester, shotKey, name);

    await logInInApp(tester, barberPhone);

    // --- Today opens on the pro shell: open, then one walk-in -----------
    await waitFor(tester, find.byKey(const Key('proNavToday')));
    // The status control takes taps once the pro's snapshot is in, which is
    // also when "Appeler le suivant" shows.
    final callNext = find.byKey(const Key('callNext'));
    await waitFor(tester, callNext);
    await tap(tester, find.byKey(const Key('status_open')));
    // Shown once the server has the status (and the snapshot is back).
    await waitFor(tester, find.byKey(const Key('extendAutoClose')));
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('queueRow_'),
    );
    await tap(tester, find.byKey(const Key('walkInAdd')));
    await waitFor(tester, rows);
    expect(rows, findsOneWidget);

    // --- Two remote customers join from their phones --------------------
    final karimEntry = await join(karim);
    final walidEntry = await join(walid);
    final karimRow = find.byKey(Key('queueRow_${karimEntry['entry_id']}'));
    final walidRow = find.byKey(Key('queueRow_${walidEntry['entry_id']}'));
    await waitFor(
      tester,
      find.descendant(of: karimRow, matching: find.text('Karim')),
      timeout: liveDeadline,
    );
    await waitFor(
      tester,
      find.descendant(of: walidRow, matching: find.text('Walid')),
      timeout: liveDeadline,
    );
    await shot('today');

    // --- Call next twice: the walk-in, then Karim, who sees it ----------
    await tap(tester, callNext);
    await waitUntil(
      tester,
      () => rows.evaluate().length == 2,
      'the walk-in to leave the waiting list',
    );
    await tap(tester, callNext);
    await waitForGone(tester, karimRow);
    expect(await ticketState(karim), 'serving');
    await shot('today_serving');

    // --- Walid did not come: absent ---------------------------------------
    await tap(tester, walidRow);
    await tap(tester, find.byKey(const Key('entryAbsent')));
    await tap(tester, find.byKey(const Key('confirmAction')));
    await waitForGone(tester, walidRow);
    expect(await ticketState(walid), 'absent');

    // --- Offline: the banner shows and "call next" waits for the network --
    await tap(tester, find.byKey(const Key('walkInAdd')));
    await waitFor(tester, rows);
    bool canCallNext() =>
        tester.widget<LemqesPrimaryButton>(callNext).onPressed != null;
    await waitUntil(tester, canCallNext, 'call next to be enabled');

    await app.realtime.disconnect();
    // "Hors ligne" once the socket has been down for 5 s.
    await waitFor(tester, find.byKey(const Key('offlineBanner')));
    expect(find.text(l10n.todayOffline), findsOneWidget);
    expect(canCallNext(), isFalse);
    await shot('today_offline');

    // supabase_flutter's own resume path calls it the same way.
    // ignore: invalid_use_of_internal_member
    await app.realtime.connect();
    await waitForGone(tester, find.byKey(const Key('offlineBanner')));
    await waitUntil(tester, canCallNext, 'call next to come back');
  });
}
