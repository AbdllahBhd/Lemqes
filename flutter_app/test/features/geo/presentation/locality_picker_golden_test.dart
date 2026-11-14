import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/geo/presentation/locality_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/golden_host.dart';
import 'geo_fixture.dart';

void main() {
  final seed = loadSeed();
  for (final v in goldenVariants) {
    testWidgets('LocalityPicker sheet ${goldenName(v)}', (tester) async {
      tester.view.physicalSize = const Size(390, 760) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final ar = v.locale.languageCode == 'ar';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            regionsProvider.overrideWith((ref, c) async => seed.regions),
            localitiesProvider.overrideWith((ref, k) async => seed.localities),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lemqesTheme(v.brightness),
            locale: v.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appDelegates,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LocalityPicker(
                  country: 'DZ',
                  regionCode: '35',
                  onChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickRegion')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pickerSearch')),
        ar ? 'بو' : 'bou',
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/locality_picker_sheet_${goldenName(v)}.png'),
      );
    });
  }
}
