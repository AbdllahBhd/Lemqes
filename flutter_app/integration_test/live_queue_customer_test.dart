import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/bootstrap.dart';
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_helpers.dart';

/// The customer side of the live queue against the local stack: the app is a
/// men customer; the seeded barber and the other customers are raw clients
/// (other devices). Run by scripts/integration.sh after live_seed.sql.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  final locale = Locale(shots.startsWith('ar') ? 'ar' : 'fr');
  final dark = shots.endsWith('dark');
  final l10n = lookupAppLocalizations(locale);
  final shotKey = GlobalKey();

  testWidgets('a customer follows a live queue, only in its own space', (
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

    final barber = await signedIn(barberPhone);
    final control = await signedIn(controlPhone);
    addTearDown(barber.dispose);
    addTearDown(control.dispose);
    Future<void> owner(String fn, [Map<String, Object?> params = const {}]) =>
        barber.rpc<Object?>(
          fn,
          params: {'p_pro_id': menProId, 'p_request_id': newRequestId()}
            ..addAll(params),
        );

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

    await signUpInApp(
      tester,
      space: 'men',
      role: 'customer',
      name: 'Karim',
      phone: menCustomerPhone,
    );

    // --- The card follows the barber with no user action ----------------
    final card = find.byKey(const Key('proCard_$menProId'));
    Finder onCard(Finder f) => find.descendant(of: card, matching: f);
    await waitFor(tester, card);
    await waitFor(tester, onCard(find.textContaining(l10n.liveStatusClosed)));
    expect(onCard(find.byKey(const Key('liveQueueLine'))), findsNothing);

    await owner('set_live_status', {'p_status': 'open', 'p_break_until': null});
    await owner('queue_add_walk_in');
    await owner('queue_add_walk_in');
    await waitFor(
      tester,
      onCard(find.textContaining(l10n.liveStatusOpen)),
      timeout: liveDeadline,
    );
    await waitFor(
      tester,
      onCard(find.textContaining(l10n.liveQueueCount(2))),
      timeout: liveDeadline,
    );
    await shot('explore');

    // --- Join from the profile: third in line ---------------------------
    await tap(tester, card);
    final block = find.byKey(const Key('liveBlock'));
    Finder inBlock(Finder f) => find.descendant(of: block, matching: f);
    await tap(tester, inBlock(find.byKey(const Key('liveJoin'))));
    await tap(tester, find.byKey(const Key('joinService_$cutServiceId')));
    await shot('join_sheet');
    await tap(tester, find.byKey(const Key('joinConfirm')));
    await waitForGone(tester, find.byKey(const Key('joinSheet')));
    await waitFor(
      tester,
      inBlock(
        find.textContaining(l10n.ticketYouAre(l10n.ticketPlace(3, 'men'))),
      ),
    );
    await scrollToTop(tester);
    await shot('profile');

    // Two walk-ins called ahead: first, then the turn, each pushed live.
    await owner('queue_call_next');
    await owner('queue_call_next');
    await waitFor(
      tester,
      inBlock(
        find.textContaining(l10n.ticketYouAre(l10n.ticketPlace(1, 'men'))),
      ),
      timeout: liveDeadline,
    );
    await owner('queue_call_next');
    await waitFor(
      tester,
      inBlock(find.text(l10n.ticketYourTurn)),
      timeout: liveDeadline,
    );

    // The count hidden: the line says the queue is open, never a number.
    await owner('set_queue_settings', {'p_mode': 'open', 'p_hide_count': true});
    await waitFor(
      tester,
      inBlock(find.textContaining(l10n.liveQueueOpen)),
      timeout: liveDeadline,
    );

    await tap(tester, find.byKey(const Key('proBack')));
    final ticket = find.byKey(const Key('ticketCard'));
    await waitFor(
      tester,
      find.descendant(of: ticket, matching: find.text(l10n.ticketYourTurn)),
    );
    await shot('ticket');

    // --- Leak check, with a positive control -----------------------------
    // A women customer is refused the men barber's topic (~5 s, spike c)
    // while a men customer on the same topic receives the next message.
    final women = await signedUp(
      womenCustomerPhone,
      name: 'Lina',
      space: 'women',
    );
    addTearDown(women.dispose);
    final refused = RawChannel(women, menProId);
    final controlChannel = RawChannel(control, menProId);
    final (controlStatus, _) = await controlChannel.joined(
      const Duration(seconds: 10),
    );
    expect(controlStatus, RealtimeSubscribeStatus.subscribed);
    final (womenStatus, womenError) = await refused.joined(
      const Duration(seconds: 10),
    );
    expect(womenStatus, RealtimeSubscribeStatus.channelError);
    expect('$womenError', contains('Unauthorized'));
    await owner('set_queue_settings', {
      'p_mode': 'open',
      'p_hide_count': false,
    });
    final received = await controlChannel.next(liveDeadline);
    expect(received['pro_id'], menProId);
    expect(refused.messages, isEmpty);

    // --- Switch to Femmes: the men channel is closed, nothing arrives ----
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LemqesApp)),
    );
    final channels = container.read(liveChannelsProvider);
    // realtime_client marks `topic` internal; the test reads it only to see
    // which channels the app's socket still holds.
    bool menTopicOpen() => app.realtime.getChannels().any(
      // ignore: invalid_use_of_internal_member
      (c) => c.topic.endsWith(menProId),
    );
    expect(menTopicOpen(), isTrue);

    await tap(tester, find.byKey(const Key('spaceSwitch_women')));
    await waitFor(tester, find.byKey(const Key('proCard_$womenProId')));
    expect(card, findsNothing);
    expect(ticket, findsNothing);
    await waitUntil(tester, () => !menTopicOpen(), 'the men channel to close');

    await owner('queue_add_walk_in');
    // The control proves the message went out; the app had no channel left.
    expect((await controlChannel.next(liveDeadline))['waiting_count'], 1);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(menTopicOpen(), isFalse);
    expect(channels.latest(menProId), isNull);
    expect(ticket, findsNothing);

    // --- Back to Hommes, then a socket drop -------------------------------
    // The card first shows the search's snapshot; a count that moves after
    // that came through the rejoined channel (a message, or the fetch its
    // subscribe triggers), so the socket drop below hits a joined channel.
    await tap(tester, find.byKey(const Key('spaceSwitch_men')));
    await waitFor(tester, onCard(find.textContaining(l10n.liveQueueCount(1))));
    await waitFor(tester, ticket);
    await owner('queue_add_walk_in');
    await waitFor(
      tester,
      onCard(find.textContaining(l10n.liveQueueCount(2))),
      timeout: liveDeadline,
    );

    // A disconnect() tells no channel and a connect() rejoins none: the app
    // must join again by itself and fetch what it missed.
    await app.realtime.disconnect();
    await owner('queue_add_walk_in');
    // supabase_flutter's own resume path calls it the same way.
    // ignore: invalid_use_of_internal_member
    await app.realtime.connect();
    await waitFor(
      tester,
      onCard(find.textContaining(l10n.liveQueueCount(3))),
      timeout: liveDeadline,
    );
  });
}
