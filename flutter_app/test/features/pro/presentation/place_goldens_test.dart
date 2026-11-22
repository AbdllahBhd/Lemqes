import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/place/place_picker_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'dashboard/dashboard_harness.dart';

/// [barberProfile] in [space], named for the locale.
ProProfile _profile(Space space, {required bool arabic}) {
  final p = barberProfile(service: false, hours: false);
  return ProProfile(
    id: p.id,
    kind: p.kind,
    space: space,
    displayName: arabic ? 'أمينة' : 'Amina',
    workplaceType: p.workplaceType,
    phoneVisibility: p.phoneVisibility,
    showPrices: p.showPrices,
    isVerified: p.isVerified,
    localityId: p.localityId,
    customerMix: p.customerMix,
  );
}

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;
    final arabic = lang == 'ar';

    // Pin in the women's space, so the S1 warning is part of the capture.
    for (final (name, mode, space) in [
      ('pin', 'exact', Space.women),
      ('zone', 'area', Space.men),
      ('commune', 'none', Space.men),
    ]) {
      testWidgets('place_picker_${name}_$lang', (tester) async {
        debugDisableShadows = false;
        try {
          await pumpSetup(
            tester,
            account: proAccount(space: space),
            pros: FakeProRepository(
              profile: _profile(space, arabic: arabic),
              space: space,
            ),
            location: '/pro/setup/location',
            locale: locale,
          );
          await tapAndSettle(tester, 'placeMode_$mode');
          // The pin capture shows the end of the controls (preview line and
          // the S1 warning); the others their start.
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            Offset(0, mode == 'exact' ? -2000 : 2000),
          );
          await settle(tester);
          await expectLater(
            find.byType(PlacePickerScreen),
            matchesGoldenFile('goldens/place_picker_${name}_$lang.png'),
          );
        } finally {
          debugDisableShadows = true;
        }
      });
    }

    testWidgets('pro_dashboard_place_card_$lang', (tester) async {
      debugDisableShadows = false;
      try {
        await pumpDashboard(
          tester,
          account: proAccount(),
          // A listed salon that shows no place: the S2 nudge.
          profile: copyProfile(
            publishedBarber(name: arabic ? 'أمين بن علي' : 'Amine Benali'),
          ),
          locale: locale,
          size: const Size(390, 2000),
        );
        await expectLater(
          byKey('placeCard'),
          matchesGoldenFile('goldens/pro_dashboard_place_card_$lang.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
