import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_en.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lemqes/features/explore/presentation/pro_labels.dart';

ProCard _c(int? m, [PlaceMode mode = PlaceMode.exact]) => ProCard(
  proId: 'p',
  kind: ProKind.barber,
  displayName: 'x',
  workplaceType: WorkplaceType.salon,
  isVerified: false,
  distanceM: m,
  placeMode: mode,
);

void main() {
  group('distanceLabel', () {
    final en = AppLocalizationsEn();
    const enL = Locale('en');

    test('metres under a kilometre, kilometres above', () {
      expect(distanceLabel(en, enL, _c(700)), '700 m');
      expect(distanceLabel(en, enL, _c(999)), '999 m');
      expect(distanceLabel(en, enL, _c(1000)), '1 km');
      expect(distanceLabel(en, enL, _c(1500)), '1.5 km');
    });

    test('commune-only pros read in whole kilometres with a tilde', () {
      expect(distanceLabel(en, enL, _c(3000, PlaceMode.none)), '≈ 3 km');
      expect(distanceLabel(en, enL, _c(500, PlaceMode.none)), '≈ 1 km');
    });

    test('no distance without one', () {
      expect(distanceLabel(en, enL, _c(null)), isNull);
    });

    test('keeps Latin digits in Arabic and a comma separator', () {
      final ar = AppLocalizationsAr();
      expect(distanceLabel(ar, const Locale('ar'), _c(1500)), '1,5 كم');
    });
  });

  group('placeLine', () {
    test('joins the commune and the wilaya', () {
      expect(placeLine('Hydra', 'Alger'), 'Hydra · Alger');
    });

    test('names a commune once when the wilaya carries its name', () {
      // Seen in the M2 review: "بوسعادة · بوسعادة", "Bou Saada · Bou Saâda".
      expect(placeLine('بوسعادة', 'بوسعادة'), 'بوسعادة');
      expect(placeLine('Bou Saada', 'Bou Saâda'), 'Bou Saada');
    });

    test('keeps whichever part is known', () {
      expect(placeLine(null, 'Alger'), 'Alger');
      expect(placeLine('Hydra', ''), 'Hydra');
      expect(placeLine(null, null), isNull);
    });
  });
}
