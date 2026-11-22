import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/locale_controller.dart' show supportedLocales;
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/map/presentation/commune_pin.dart';
import 'package:lemqes/features/map/presentation/lemqes_base_map.dart';
import 'package:lemqes/features/map/presentation/pro_markers.dart';
import 'package:material_ui/material_ui.dart';

const _alger = LatLng(36.7731, 3.0588);

Future<List<Uri>> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  List<Polygon> polygons = const [],
  List<Marker> markers = const [],
}) async {
  tester.view.physicalSize = const Size(390, 400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapBaseLayerProvider.overrideWithValue(
          (_) => const MapPlainBackground(),
        ),
        mapLinkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(
        theme: lemqesTheme(Brightness.light),
        locale: locale,
        localizationsDelegates: appDelegates,
        supportedLocales: supportedLocales,
        home: Scaffold(
          body: LemqesBaseMap(
            initialCenter: _alger,
            initialZoom: 14,
            polygons: polygons,
            markers: markers,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return opened;
}

Map<String, dynamic> _style() => {
  'version': 8,
  'id': 'liberty',
  'sources': {
    'openmaptiles': {'type': 'vector', 'url': 'https://tiles.test/planet'},
  },
  'layers': [
    {'id': 'background', 'type': 'background'},
    {
      'id': 'place_city',
      'type': 'symbol',
      'layout': {
        'text-field': [
          'coalesce',
          ['get', 'name:en'],
          ['get', 'name'],
        ],
      },
    },
    {
      'id': 'road_label',
      'type': 'symbol',
      'layout': {'text-field': '{name}'},
    },
    {
      'id': 'highway-shield',
      'type': 'symbol',
      'layout': {'text-field': '{ref}'},
    },
    {
      'id': 'poi_icon_only',
      'type': 'symbol',
      'layout': {'icon-image': 'shop'},
    },
  ],
};

List<dynamic> _layers(Map<String, dynamic> style) =>
    style['layers'] as List<dynamic>;

Object? _textField(Map<String, dynamic> style, String id) {
  final layer = _layers(style)
      .cast<Map<String, dynamic>>()
      .firstWhere((l) => l['id'] == id);
  return (layer['layout'] as Map?)?['text-field'];
}

void main() {
  group('the base layer', () {
    testWidgets('comes from the provider: a plain background in tests', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapPlainBackground), findsOneWidget);
    });
  });

  group('attribution', () {
    for (final locale in const [Locale('fr'), Locale('ar')]) {
      testWidgets('is reachable and left-to-right in ${locale.languageCode}', (
        tester,
      ) async {
        final opened = await _pump(tester, locale: locale);
        final widget = tester.widget<RichAttributionWidget>(
          find.byType(RichAttributionWidget),
        );
        expect(widget.showFlutterMapAttribution, isFalse);
        final dir = tester.widget<Directionality>(
          find
              .ancestor(
                of: find.byType(RichAttributionWidget),
                matching: find.byType(Directionality),
              )
              .first,
        );
        expect(dir.textDirection, TextDirection.ltr);

        final texts = widget.attributions
            .whereType<TextSourceAttribution>()
            .map((a) => a.text)
            .toList();
        expect(texts, ['OpenMapTiles', 'OpenStreetMap contributors']);
        // The widget prepends its own "©"; a written one would double it.
        expect(texts.any((t) => t.contains('©')), isFalse);

        await tester.tap(
          find.descendant(
            of: find.byType(RichAttributionWidget),
            matching: find.byIcon(Icons.info_outlined),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('OpenStreetMap contributors'));
        expect(opened, [Uri.parse(osmCopyrightUrl)]);
      });
    }
  });

  group('labels per locale', () {
    test('Arabic reads name:ar, every other locale the Latin name', () {
      expect(mapLabelScriptFor(const Locale('ar')), MapLabelScript.arabic);
      for (final code in ['fr', 'en', 'kab']) {
        expect(mapLabelScriptFor(Locale(code)), MapLabelScript.latin);
      }
    });

    test('each script gets its own style id', () {
      final ar = localizeMapStyle(_style(), MapLabelScript.arabic);
      final latin = localizeMapStyle(_style(), MapLabelScript.latin);
      expect(ar['id'], 'liberty-ar');
      expect(latin['id'], 'liberty-latin');
    });

    test('name labels are rewritten; shields and icons are left alone', () {
      final ar = localizeMapStyle(_style(), MapLabelScript.arabic);
      const arField = [
        'coalesce',
        ['get', 'name:ar'],
        ['get', 'name'],
      ];
      expect(_textField(ar, 'place_city'), arField);
      expect(_textField(ar, 'road_label'), arField);
      expect(_textField(ar, 'highway-shield'), '{ref}');
      expect(_textField(ar, 'poi_icon_only'), isNull);

      final latin = localizeMapStyle(_style(), MapLabelScript.latin);
      expect(_textField(latin, 'place_city'), const [
        'coalesce',
        ['get', 'name:latin'],
        ['get', 'name'],
      ]);
    });

    test('the fetched style is never mutated', () {
      final raw = _style();
      localizeMapStyle(raw, MapLabelScript.arabic);
      expect(raw['id'], 'liberty');
      expect(_textField(raw, 'road_label'), '{name}');
    });
  });

  group('markers', () {
    test('an area circle is a polygon of at least 72 points', () {
      final polygon = areaPolygon(_alger, 1000, color: Colors.teal);
      expect(polygon.points.length, greaterThanOrEqualTo(72));
      const distance = Distance();
      for (final p in polygon.points) {
        expect(distance(_alger, p), closeTo(1000, 5));
      }
    });

    testWidgets('an area is drawn by a PolygonLayer, never a CircleLayer', (
      tester,
    ) async {
      await _pump(
        tester,
        polygons: [areaPolygon(_alger, 500, color: Colors.teal)],
        markers: [
          exactPinMarker(_alger),
          communePinMarker(_alger, label: 'Alger Centre'),
        ],
      );
      expect(find.byType(PolygonLayer), findsOneWidget);
      expect(find.byType(CircleLayer), findsNothing);
      expect(find.byType(ProPin), findsOneWidget);
      expect(find.byType(CommunePin), findsOneWidget);
    });
  });
}
