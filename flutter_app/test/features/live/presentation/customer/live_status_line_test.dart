import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/live/presentation/customer/live_ring.dart';
import 'package:lemqes/features/live/presentation/customer/live_status_line.dart';
import 'package:material_ui/material_ui.dart';

import 'customer_live_harness.dart';

/// The status and queue lines of pro `p1`, fed by the real channels.
Future<(CustomerLive, ProviderContainer)> _pump(
  WidgetTester tester, {
  bool connected = true,
  Locale locale = const Locale('fr'),
}) async {
  final live = CustomerLive();
  addTearDown(live.dispose);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...live.overrides(connected: connected),
      customerAccountOverride(),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: lemqesTheme(Brightness.light),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appDelegates,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final view = ref.watch(proLiveProvider('p1')).value;
              if (view == null) return const SizedBox.shrink();
              return Column(
                children: [
                  LiveRing(
                    view: view,
                    child: const SizedBox.square(dimension: 56),
                  ),
                  LiveStatusLine(view: view),
                  LiveQueueLine(view: view),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  await container.read(accountProvider.future);
  return (live, container);
}

Future<void> _seed(
  WidgetTester tester,
  ProviderContainer c,
  LiveSnapshot s,
) async {
  c.read(liveChannelsProvider).seed(s);
  await settleLive(tester);
}

/// The status line's whole text (one rich text).
String _line(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('liveStatusLine')))
    .textSpan!
    .toPlainText(includePlaceholders: false)
    // Details are kept whole with no-break spaces.
    .replaceAll('\u00a0', ' ');

String? _queue(WidgetTester tester) {
  final f = find.byKey(const Key('liveQueueLine'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  testWidgets('open: word, age and queue; the live ring', (tester) async {
    final (_, c) = await _pump(tester);
    await _seed(tester, c, custSnap('p1'));

    expect(_line(tester), 'Ouvert · il y a 5 min');
    expect(_queue(tester), '3 en attente · ~40 min');
    expect(find.byKey(const Key('liveRing_open')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('break: return time, then "Pause prolongée" once it passes', (
    tester,
  ) async {
    final (live, c) = await _pump(tester);
    await _seed(tester, c, breakSnap('p1'));

    expect(_line(tester), 'En pause · retour \u206611:30\u2069 · il y a 5 min');
    expect(find.byKey(const Key('liveRing_onBreak')), findsOneWidget);
    expect(_queue(tester), '2 en attente · ~25 min');

    live.advanceTo(DateTime.utc(2026, 11, 20, 10, 40));
    await settleLive(tester);
    expect(_line(tester), startsWith('Pause prolongée · '));
    expect(_line(tester), isNot(contains('11:30')));
    await unmountLive(tester);
  });

  testWidgets('closed: no age, no ring, no queue line', (tester) async {
    final (_, c) = await _pump(tester);
    await _seed(tester, c, closedSnap('p1'));

    expect(_line(tester), 'Fermé');
    expect(_queue(tester), isNull);
    expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('a refused channel with a closed fetch reads "Fermé", for good', (
    tester,
  ) async {
    // A customer the pro blocked: the channel is refused and the fetch is
    // the closed shape (no times, age, queue or wait).
    final (live, _) = await _pump(tester);
    live.repo.server['p1'] = LiveSnapshot.fromJson({
      ...custLive('p1', status: 'closed', joinBlock: 'closed'),
      'auto_close_at': null,
      'status_age_from': null,
      'waiting_count': null,
      'wait_min': null,
      'ahead_minutes': null,
    });
    await settleLive(tester);
    live.factory.last('p1').refuse();
    await settleLive(tester);

    expect(_line(tester), 'Fermé');
    expect(_queue(tester), isNull);
    expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
    // Hours later, with no message: still a plain "Fermé" (no age, no
    // "Statut incertain"), as a closed pro reads.
    live.advanceTo(DateTime.utc(2026, 11, 20, 15));
    await settleLive(tester);
    expect(_line(tester), 'Fermé');
    expect(_queue(tester), isNull);
    await unmountLive(tester);
  });

  testWidgets('a refusal after an open message takes the closed fetch at '
      'the same version', (tester) async {
    // Open at version 3 on the channel; the barber blocks this customer; the
    // rejoined channel is refused and the closed fetch says version 3 too.
    final (live, _) = await _pump(tester);
    await settleLive(tester);
    live.broadcast('p1', custLive('p1'));
    await settleLive(tester);
    expect(_line(tester), startsWith('Ouvert'));
    live.repo.server['p1'] = LiveSnapshot.fromJson({
      ...custLive('p1', status: 'closed', joinBlock: 'closed'),
      'auto_close_at': null,
      'status_age_from': null,
      'waiting_count': null,
      'wait_min': null,
      'ahead_minutes': null,
    });
    live.factory.last('p1').refuse();
    await settleLive(tester);
    expect(_line(tester), 'Fermé');
    await unmountLive(tester);
  });

  testWidgets('no barber action for 2 h reads "Statut incertain", muted', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);
    await _seed(
      tester,
      c,
      custSnap('p1', ageFrom: DateTime.utc(2026, 11, 20, 7, 55)),
    );

    expect(_line(tester), 'Statut incertain · il y a 2 h');
    expect(_queue(tester), isNull);
    expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('the age runs on the server clock, not the device one', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);
    // The server is 10 min ahead of the device.
    await _seed(
      tester,
      c,
      custSnap('p1', serverNow: DateTime.utc(2026, 11, 20, 10, 10)),
    );

    expect(_line(tester), 'Ouvert · il y a 15 min');
    await unmountLive(tester);
  });

  testWidgets('a mounted line goes "Fermé" at auto-close with no message', (
    tester,
  ) async {
    final (live, c) = await _pump(tester);
    await _seed(tester, c, custSnap('p1'));
    expect(_line(tester), startsWith('Ouvert'));

    // 19:31 in Algiers: past auto_close_at (19:30), and nobody broadcast.
    live.advanceTo(DateTime.utc(2026, 11, 20, 18, 31));
    await settleLive(tester);

    expect(_line(tester), 'Fermé');
    expect(_queue(tester), isNull);
    expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('disconnected: only the age of the last update', (tester) async {
    final (live, c) = await _pump(tester, connected: false);
    await _seed(tester, c, custSnap('p1'));
    expect(_line(tester), 'Mis à jour à l’instant');

    live.advanceTo(DateTime.utc(2026, 11, 20, 10, 3));
    await settleLive(tester);
    expect(_line(tester), 'Mis à jour il y a 3 min');
    expect(_queue(tester), isNull);
    expect(find.byKey(const Key('liveRing_none')), findsOneWidget);
    await unmountLive(tester);
  });

  testWidgets('queue line variants: hidden count, paused, no wait', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);
    await _seed(tester, c, custSnap('p1', waiting: null));
    expect(_queue(tester), 'File ouverte · ~40 min');

    await _seed(tester, c, custSnap('p1', mode: 'paused', version: 4));
    expect(_queue(tester), 'File complète');

    await _seed(tester, c, custSnap('p1', waiting: 0, waitMin: 0, version: 5));
    expect(_queue(tester), 'Pas d’attente');
    await unmountLive(tester);
  });

  testWidgets('Arabic: approximate waits say حوالي, times stay LTR', (
    tester,
  ) async {
    final (_, c) = await _pump(tester, locale: const Locale('ar'));
    await _seed(tester, c, breakSnap('p1'));

    expect(_line(tester), contains('\u206611:30\u2069'));
    expect(_queue(tester), '2 في الانتظار · حوالي 25 دقيقة');
    expect(_queue(tester), isNot(contains('~')));
    await unmountLive(tester);
  });

  testWidgets('nobody waiting but someone in the chair: "Pas d’attente"', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);
    await _seed(tester, c, custSnap('p1', waiting: 0, waitMin: 10));
    expect(_queue(tester), 'Pas d’attente · ~10 min');
    await unmountLive(tester);
  });

  testWidgets('a wrap never leaves "·" dangling at a line end', (tester) async {
    final (_, c) = await _pump(tester);
    await _seed(tester, c, breakSnap('p1'));
    final spans = tester
        .widget<Text>(find.byKey(const Key('liveStatusLine')))
        .textSpan!
        .toPlainText(includePlaceholders: false);
    // No-break space before each separator, a breaking one after.
    expect(spans, contains(' · '));
    expect(spans, isNot(contains(' ·')));
    await unmountLive(tester);
  });

  testWidgets('Arabic break return agrees with the space', (tester) async {
    final live = CustomerLive();
    addTearDown(live.dispose);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...live.overrides(),
        customerAccountOverride(liveCustomer(space: Space.women)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: lemqesTheme(Brightness.light),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appDelegates,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final view = ref.watch(proLiveProvider('p1')).value;
                return view == null
                    ? const SizedBox.shrink()
                    : LiveStatusLine(view: view);
              },
            ),
          ),
        ),
      ),
    );
    await container.read(accountProvider.future);
    await _seed(tester, container, breakSnap('p1'));
    expect(_line(tester), contains('تعود'));
    await unmountLive(tester);
  });
}
