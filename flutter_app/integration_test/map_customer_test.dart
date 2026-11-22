import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/bootstrap.dart';
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:lemqes/features/map/presentation/lemqes_base_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/features/geo/data/fake_device_location.dart';
import 'live_helpers.dart';

/// The seed's map accounts (supabase/fixtures/map_seed.sql).
const _linaPhone = '0550000007';
const _blockedPhone = '0550000008';
const _linaId = 'b0000000-0000-4000-8000-000000000007';
const _amelId = 'b0000000-0000-4000-8000-000000000015';
const _amineId = 'b0000000-0000-4000-8000-000000000019';
const _yacineId = 'b0000000-0000-4000-8000-000000000020';

/// Lina's commune (Sidi M'hamed): a commune pin there would place her too.
const _linaLocality = 1602;

/// Near-me and the map against the local stack, with a scripted device
/// position (Sidi M'hamed) and the plain map background (no network tiles).
/// Run by scripts/integration.sh after map_seed.sql.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  const locale = Locale('fr');
  final l10n = lookupAppLocalizations(locale);

  testWidgets('near me, the map, both spaces, a block and the Arabic search', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).clear();
    final prefs = await bootstrap();
    await Supabase.instance.client.auth.signOut();
    await prefs.setString(LocaleController.prefsKey, locale.languageCode);
    await prefs.setString(ThemeModeController.prefsKey, ThemeMode.light.name);
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // Lina is open, so the blocked customer's "closed" is the block's.
    final lina = await signedIn(_linaPhone);
    addTearDown(lina.dispose);
    await lina.rpc<Object?>(
      'set_live_status',
      params: {
        'p_pro_id': _linaId,
        'p_request_id': newRequestId(),
        'p_status': 'open',
        'p_break_until': null,
      },
    );

    final device = FakeDeviceLocation();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocationProvider.overrideWithValue(device),
          mapBaseLayerProvider.overrideWithValue(
            (_) => const MapPlainBackground(),
          ),
        ],
        child: const LemqesApp(),
      ),
    );

    Finder card(String id) => find.byKey(Key('proCard_$id'));
    Finder onCard(String id, Finder f) =>
        find.descendant(of: card(id), matching: f);
    final distance = find.byKey(const Key('proDistance'));
    final map = find.byKey(const Key('exploreMap'));
    Finder areaPin(String id) => find.byKey(Key('areaPin_$id'));
    Finder exactPin(String id) => find.byKey(Key('exactPin_$id'));

    Future<void> useDevice() async {
      await tap(tester, find.byKey(const Key('locationChip')));
      await tap(tester, find.byKey(const Key('locationOptionDevice')));
    }

    // --- (b) A women customer: near me, nearest first, her space only ----
    await signUpInApp(
      tester,
      space: 'women',
      role: 'customer',
      name: 'Nour',
      phone: womenCustomerPhone,
    );
    await waitFor(tester, card(_linaId));
    await waitFor(tester, card(_amelId));
    expect(card(_amineId), findsNothing);
    expect(card(_yacineId), findsNothing);
    await waitFor(
      tester,
      onCard(_linaId, find.textContaining(l10n.liveStatusOpen)),
    );

    // "Ma position" explains first, then asks the OS for approximate only.
    await useDevice();
    await tap(tester, find.byKey(const Key('locationExplainerAllow')));
    expect(device.requests, [false]);
    await waitFor(tester, onCard(_linaId, distance));
    await waitFor(tester, onCard(_amelId, distance));
    expect(
      tester.getTopLeft(card(_linaId)).dy,
      lessThan(tester.getTopLeft(card(_amelId)).dy),
      reason: 'the studio (~250 m) lists before Salon Amel (~1.8 km)',
    );

    await tap(tester, find.byKey(const Key('exploreViewToggle')));
    await waitFor(tester, map);
    await waitFor(tester, areaPin(_linaId));
    await waitFor(tester, exactPin(_amelId));
    expect(exactPin(_amineId), findsNothing);

    // --- The men's space: its pro (the positive control), no women's -----
    await tap(tester, find.byKey(const Key('spaceSwitch_men')));
    await waitFor(tester, exactPin(_amineId));
    expect(areaPin(_linaId), findsNothing);
    expect(exactPin(_amelId), findsNothing);

    // --- (d) "Amine" finds أمين, not the other men's pro -----------------
    await tap(tester, find.byKey(const Key('exploreViewToggle')));
    await waitFor(tester, card(_yacineId));
    await waitFor(tester, card(_amineId));
    await enter(tester, const Key('exploreSearch'), 'Amine');
    await waitForGone(tester, card(_yacineId));
    await waitFor(tester, onCard(_amineId, find.text('أمين')));
    expect(card(_linaId), findsNothing);
    await tap(tester, find.byKey(const Key('exploreSearchClear')));
    await waitFor(tester, card(_yacineId));

    await tap(tester, find.byKey(const Key('settings')));
    await tap(tester, find.byKey(const Key('signOut')));
    await tap(tester, find.byKey(const Key('confirmSignOut')));
    await waitFor(tester, find.byKey(const Key('tab_login')));

    // --- (c) The customer Lina blocked: closed, no distance, not mapped ---
    await logInInApp(tester, _blockedPhone);
    await waitFor(tester, card(_linaId));
    // Permission is already granted: no explainer this time.
    await useDevice();
    expect(find.byKey(const Key('locationExplainerAllow')), findsNothing);
    await waitFor(tester, onCard(_amelId, distance));
    await waitFor(
      tester,
      onCard(_linaId, find.textContaining(l10n.liveStatusClosed)),
    );
    expect(
      onCard(_linaId, find.textContaining(l10n.liveStatusOpen)),
      findsNothing,
    );
    expect(onCard(_linaId, distance), findsNothing);
    expect(
      tester.getTopLeft(card(_amelId)).dy,
      lessThan(tester.getTopLeft(card(_linaId)).dy),
      reason: 'with no point to measure, Lina sorts after every distance',
    );

    await tap(tester, find.byKey(const Key('exploreViewToggle')));
    await waitFor(tester, map);
    await waitFor(tester, exactPin(_amelId));
    // Settled: Amel's pin came from the same answer Lina is missing from.
    await pumpFor(tester, const Duration(seconds: 1));
    expect(areaPin(_linaId), findsNothing);
    expect(exactPin(_linaId), findsNothing);
    expect(find.byKey(const Key('communePin_$_linaLocality')), findsNothing);
  });
}
