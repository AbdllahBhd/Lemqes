import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/geo/data/geo_repository.dart';
import 'package:lemqes/features/geo/data/origin.dart';
import 'package:lemqes/features/geo/presentation/location_chip.dart';
import 'package:lemqes/features/geo/presentation/location_explainer_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fake_device_location.dart';

class _Geo extends Mock implements GeoRepository {}

const _alger = Locality(
  id: 1601,
  regionCode: '16',
  nameAr: 'الجزائر الوسطى',
  nameFr: 'Alger Centre',
  lat: 36.77,
  lng: 3.06,
);

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Widget body, {
  double height = 420,
}) async {
  tester.view.physicalSize = Size(390, height) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    originChoiceKey: jsonEncode({
      'kind': 'commune',
      'id': 1601,
      'lat': 36.77,
      'lng': 3.06,
    }),
  });
  final prefs = await SharedPreferences.getInstance();
  final geo = _Geo();
  when(() => geo.locality(1601)).thenAnswer((_) async => _alger);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        geoRepositoryProvider.overrideWithValue(geo),
        deviceLocationProvider.overrideWithValue(FakeDeviceLocation()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lemqesTheme(Brightness.light),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appDelegates,
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('location chip $lang', (tester) async {
      await _pump(
        tester,
        locale,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: LocationChip(),
          ),
        ),
        height: 96,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/location_chip_$lang.png'),
      );
    });

    testWidgets('location explainer $lang', (tester) async {
      await _pump(
        tester,
        locale,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showLocationExplainerSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/location_explainer_$lang.png'),
      );
    });
  }
}
