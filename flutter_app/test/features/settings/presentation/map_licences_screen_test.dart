import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/core/l10n/locale_controller.dart' show supportedLocales;
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/map/presentation/lemqes_base_map.dart';
import 'package:lemqes/features/settings/presentation/map_licences_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final fr = AppLocalizationsFr();

  Future<List<Uri>> pump(
    WidgetTester tester, {
    Locale? locale,
    double textScale = 1,
  }) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          theme: lemqesTheme(Brightness.light),
          locale: locale ?? const Locale('fr'),
          localizationsDelegates: appDelegates,
          supportedLocales: supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const MapLicencesScreen(),
        ),
      ),
    );
    await tester.pump();
    return opened;
  }

  testWidgets('credits OpenStreetMap (ODbL), OpenMapTiles and OpenFreeMap', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(fr.settingsMapData), findsOneWidget);
    for (final name in ['OpenStreetMap', 'OpenMapTiles', 'OpenFreeMap']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text(fr.mapLicenceOsm), findsOneWidget);
    expect(find.text(fr.mapLicenceOpenMapTiles), findsOneWidget);
    expect(find.text(fr.mapLicenceOpenFreeMap), findsOneWidget);
  });

  testWidgets('the OpenStreetMap link opens the copyright page', (
    tester,
  ) async {
    final opened = await pump(tester);
    await tester.tap(find.byKey(const Key('licence_osm')));
    expect(opened, [Uri.parse(osmCopyrightUrl)]);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester, locale: const Locale('ar'), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
