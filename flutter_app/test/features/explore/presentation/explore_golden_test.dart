import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../live/presentation/customer/customer_live_harness.dart';
import 'explore_harness.dart';

const _variants = [
  (ThemeMode.light, Locale('fr')),
  (ThemeMode.light, Locale('ar')),
  (ThemeMode.dark, Locale('fr')),
  (ThemeMode.dark, Locale('ar')),
];

/// flutter_test flattens shadows by default; the soft shadow is the design.
/// Restored in `finally`: the binding checks painting debug vars before
/// tear-downs run.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final (mode, locale) in _variants) {
    final name = '${mode.name}_${locale.languageCode}';
    final arabic = locale.languageCode == 'ar';

    testWidgets('explore $name', (tester) async {
      await _withShadows(() async {
        // A place held at the first pro, then an open, a paused and a
        // closed pro.
        final live = CustomerLive()
          ..repo.ticket = ticketFor(
            proId: cardId(1),
            name: arabic ? 'أمين بن علي' : 'Amine Benali',
          );
        await pumpExplore(
          tester,
          explore: FakeExploreRepository(cards: threeLiveCards(arabic: arabic)),
          locale: locale,
          themeMode: mode,
          live: live,
          // Tall enough for the ticket and all three cards.
          size: const Size(390, 1300),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/explore_$name.png'),
        );
      });
      await unmountLive(tester);
    });

    testWidgets('pro_public_profile $name', (tester) async {
      await _withShadows(() async {
        final live = CustomerLive();
        live.repo.server[proUuid] = custSnap(proUuid);
        await pumpExplore(
          tester,
          pros: PublicProRepository(
            listed: {proUuid: publicBarber(arabic: arabic)},
            phones: {proUuid: '+213550123456'},
          ),
          location: '/pro/$proUuid',
          locale: locale,
          themeMode: mode,
          live: live,
          // Tall enough to show every section in one capture.
          size: const Size(390, 1900),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pro_public_profile_$name.png'),
        );
      });
      await unmountLive(tester);
    });

    testWidgets('pro_public_profile_ticket $name', (tester) async {
      await _withShadows(() async {
        // On break, with a place held here: the ticket replaces the join.
        final live = CustomerLive()..repo.ticket = ticketFor(proId: proUuid);
        live.repo.server[proUuid] = breakSnap(proUuid);
        await pumpExplore(
          tester,
          pros: PublicProRepository(
            listed: {proUuid: publicBarber(arabic: arabic)},
            phones: {proUuid: '+213550123456'},
          ),
          location: '/pro/$proUuid',
          locale: locale,
          themeMode: mode,
          live: live,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pro_public_profile_ticket_$name.png'),
        );
      });
      await unmountLive(tester);
    });

    testWidgets('join_sheet $name', (tester) async {
      await _withShadows(() async {
        await pumpJoinable(tester, locale: locale, themeMode: mode);
        await openJoinSheet(tester);
        await tester.tap(find.byKey(const Key('joinService_s1')));
        await settleLive(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/join_sheet_$name.png'),
        );
      });
      await unmountLive(tester);
    });
  }
}
