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
import 'package:lemqes/features/map/presentation/lemqes_base_map.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/features/geo/data/fake_device_location.dart';
import 'live_helpers.dart';

const _proPhone = '0550000007';

/// Alger, Sidi M'hamed (supabase/migrations/..._geo_dz_seed.sql).
const _region = '16';
const _sidiMhamed = 1602;

/// The women's-space pro picks a 1 km area during setup (the S1 warning
/// must be acknowledged first), then hides it from the dashboard; a women
/// customer (a raw client) reads the point before and none after. No seed:
/// the pro signs up through the app.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  const locale = Locale('fr');
  final l10n = lookupAppLocalizations(locale);

  testWidgets('a women pro shows a 1 km area, then hides it', (tester) async {
    await (await SharedPreferences.getInstance()).clear();
    final prefs = await bootstrap();
    final app = Supabase.instance.client;
    await app.auth.signOut();
    await prefs.setString(LocaleController.prefsKey, locale.languageCode);
    await prefs.setString(ThemeModeController.prefsKey, ThemeMode.light.name);
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocationProvider.overrideWithValue(FakeDeviceLocation()),
          mapBaseLayerProvider.overrideWithValue(
            (_) => const MapPlainBackground(),
          ),
        ],
        child: const LemqesApp(),
      ),
    );

    await signUpInApp(
      tester,
      space: 'women',
      role: 'barber',
      name: 'Lina',
      phone: _proPhone,
    );

    // Setup 1/4: the profile, in Sidi M'hamed.
    await waitFor(tester, find.byKey(const Key('displayNameField')));
    await tap(tester, find.byKey(const Key('pickRegion')));
    await enter(tester, const Key('pickerSearch'), _region);
    await tap(tester, find.byKey(const Key('option_$_region')));
    await waitForGone(tester, find.byKey(const Key('option_$_region')));
    await enter(tester, const Key('pickerSearch'), 'Sidi M');
    await tap(tester, find.byKey(const Key('option_$_sidiMhamed')));
    await waitForGone(tester, find.byKey(const Key('pickerSearch')));
    await tap(tester, find.byKey(const Key('mix_adults')));
    await tap(tester, find.byKey(const Key('setupContinue')));

    // Setup 2/4: a 1 km area. In the women's space saving waits for the
    // exposure warning to be acknowledged.
    await tap(tester, find.byKey(const Key('placeMode_area')));
    await tap(tester, find.byKey(const Key('placeRadius_1000')));
    final warning = find.byKey(const Key('placeWarning'));
    await waitFor(tester, warning);
    expect(
      find.descendant(of: warning, matching: find.text(l10n.placeWarningTitle)),
      findsOneWidget,
    );
    LemqesPrimaryButton save() =>
        tester.widget<LemqesPrimaryButton>(find.byKey(const Key('placeSave')));
    expect(save().onPressed, isNull, reason: 'save waits for the warning');
    await tap(tester, find.byKey(const Key('placeWarningAck')));
    await waitUntil(
      tester,
      () => save().onPressed != null,
      'save enabled once acknowledged',
    );
    await tap(tester, find.byKey(const Key('placeSave')));

    // Setup 3/4 and 4/4: one service, the offered week, published.
    await tap(tester, find.byKey(const Key('preset_women_salon_cut_blowdry')));
    await waitFor(tester, find.byKey(const Key('serviceSave')));
    await tap(tester, find.byKey(const Key('serviceSave')));
    await waitForGone(tester, find.byKey(const Key('serviceSave')));
    await waitForGone(tester, find.byType(LinearProgressIndicator));
    await tap(tester, find.byKey(const Key('setupContinue')));
    await tap(tester, find.byKey(const Key('setupPublish')));

    final proId =
        (await app.from('pro_profiles').select('id')).single['id'] as String;
    final own = (await app.from('pro_places').select()).single;
    expect(own['place_mode'], 'area');
    expect(own['area_radius_m'], 1000);
    expect(own['lat'], isNotNull);

    // A women customer reads the area (the positive control)...
    final customer = await signedUp(
      womenCustomerPhone,
      name: 'Nour',
      space: 'women',
    );
    addTearDown(customer.dispose);
    Future<Map<String, Object?>> seen() async {
      final rows = await customer.rpc<List<dynamic>>(
        'search_pros',
        params: {'p_origin_lat': 36.7538, 'p_origin_lng': 3.0588},
      );
      return Map.of(
        rows.cast<Map<String, Object?>>().singleWhere(
          (r) => r['pro_id'] == proId,
        ),
      );
    }

    final before = await seen();
    expect(before['place_mode'], 'area');
    expect(before['lat'], isNotNull);
    expect(before['area_radius_m'], 1000);

    // ... then the pro hides it from the dashboard.
    await tap(tester, find.byKey(const Key('proNavProfile')));
    await waitFor(tester, find.byKey(const Key('placeCard')));
    final hide = find.byKey(const Key('dashHidePlace'));
    await waitFor(tester, hide);
    expect(
      find.descendant(of: hide, matching: find.text(l10n.placeHide)),
      findsOneWidget,
    );
    await tap(tester, hide);
    await waitFor(tester, find.text(l10n.placeHidden));
    await waitForGone(tester, hide);

    // No point left anywhere a customer reads it.
    final after = await seen();
    expect(after['place_mode'], 'none');
    expect(after['lat'], isNull);
    expect(after['lng'], isNull);
    expect(after['area_radius_m'], isNull);
    final place = await customer
        .from('pro_places')
        .select('place_mode, lat, lng')
        .eq('pro_id', proId)
        .single();
    expect(place, {'place_mode': 'none', 'lat': null, 'lng': null});
  });
}
