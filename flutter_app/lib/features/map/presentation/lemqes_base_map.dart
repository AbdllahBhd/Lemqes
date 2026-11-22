import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../../core/config/env.dart';
import '../../../core/l10n/locale_controller.dart';

/// Sent with every style, sprite and tile request: OpenFreeMap asks for a
/// unique client name instead of a key.
const mapUserAgent = 'dz.lemqes.app';

const osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const openMapTilesUrl = 'https://openmaptiles.org/';
const openFreeMapUrl = 'https://openfreemap.org/';

/// Which script the map labels are drawn in.
enum MapLabelScript { arabic, latin }

/// Arabic UI reads `name:ar`; every other locale, Kabyle included (OSM has
/// almost no `name:kab`), the Latin name.
MapLabelScript mapLabelScriptFor(Locale locale) =>
    locale.languageCode == 'ar' ? MapLabelScript.arabic : MapLabelScript.latin;

/// The renderer caches drawn tiles under the theme id: one id per script, or
/// tiles keep the labels of the previous language.
String mapStyleIdFor(MapLabelScript script) => switch (script) {
  MapLabelScript.arabic => 'liberty-ar',
  MapLabelScript.latin => 'liberty-latin',
};

List<Object> _labelField(MapLabelScript script) => [
  'coalesce',
  ['get', script == MapLabelScript.arabic ? 'name:ar' : 'name:latin'],
  ['get', 'name'],
];

/// A copy of [style] with its own id and every name label in [script]'s
/// field; road shields (`ref`) and icon-only symbols are left alone, so a
/// label never mixes scripts.
Map<String, dynamic> localizeMapStyle(
  Map<String, dynamic> style,
  MapLabelScript script,
) {
  final copy = jsonDecode(jsonEncode(style)) as Map<String, dynamic>;
  copy['id'] = mapStyleIdFor(script);
  for (final layer in (copy['layers'] as List<dynamic>? ?? const [])) {
    if (layer is! Map || layer['type'] != 'symbol') continue;
    final layout = layer['layout'];
    if (layout is! Map) continue;
    final field = layout['text-field'];
    if (field == null || !jsonEncode(field).contains('name')) continue;
    layout['text-field'] = _labelField(script);
  }
  return copy;
}

final mapStyleUrlProvider = Provider<String>((_) => Env.mapStyleUrl);

/// Opens attribution and licence links in the browser.
final mapLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class MapStyleUnavailable implements Exception {
  const MapStyleUnavailable(this.message);

  final String message;

  @override
  String toString() => 'MapStyleUnavailable: $message';
}

/// The style as fetched, with its tile sources and sprites resolved.
class _FetchedStyle {
  const _FetchedStyle(this.json, this.providers, this.sprites);

  final Map<String, dynamic> json;
  final vmt.TileProviders providers;
  final vmt.SpriteStyle? sprites;
}

/// Fetched once per app run (kept alive); each locale patches its own copy.
final _fetchedStyleProvider = FutureProvider<_FetchedStyle>((ref) async {
  final url = ref.watch(mapStyleUrlProvider);
  if (url.isEmpty) throw const MapStyleUnavailable('MAP_STYLE_URL is empty');
  const headers = {'User-Agent': mapUserAgent};
  final client = http.Client();
  ref.onDispose(client.close);

  Future<Map<String, dynamic>> getJson(String at) async {
    final response = await client.get(Uri.parse(at), headers: headers);
    if (response.statusCode != 200) {
      throw MapStyleUnavailable('HTTP ${response.statusCode} for $at');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw MapStyleUnavailable('not a JSON object: $at');
    }
    return body;
  }

  final style = await getJson(url);
  final sources = style['sources'];
  if (sources is! Map) throw MapStyleUnavailable('no sources in $url');
  final providers = <String, vmt.VectorTileProvider>{};
  for (final MapEntry(:key, :value) in sources.entries) {
    if (value is! Map) continue;
    final type = vmt.TileProviderType.values
        .where((t) => t.name.replaceAll('_', '-') == value['type'])
        .firstOrNull;
    if (type == null) continue;
    final tileJsonUrl = value['url'];
    final source = tileJsonUrl is String ? await getJson(tileJsonUrl) : value;
    final tiles = source['tiles'];
    if (tiles is! List || tiles.isEmpty) continue;
    providers[key as String] = vmt.NetworkVectorTileProvider(
      type: type,
      urlTemplate: tiles.first as String,
      maximumZoom: source['maxzoom'] as int? ?? 14,
      minimumZoom: source['minzoom'] as int? ?? 0,
      httpHeaders: headers,
    );
  }
  if (providers.isEmpty) throw MapStyleUnavailable('no tile source in $url');

  vmt.SpriteStyle? sprites;
  final sprite = style['sprite'];
  if (sprite is String && sprite.isNotEmpty) {
    for (final suffix in ['@2x', '']) {
      try {
        final index = vtr.SpriteIndexReader().read(
          await getJson('$sprite$suffix.json'),
        );
        sprites = vmt.SpriteStyle(
          atlasProvider: () async {
            final r = await client.get(
              Uri.parse('$sprite$suffix.png'),
              headers: headers,
            );
            if (r.statusCode != 200) {
              throw MapStyleUnavailable('HTTP ${r.statusCode} for sprites');
            }
            return r.bodyBytes;
          },
          index: index,
        );
        break;
      } on Object catch (e, st) {
        // Icons are a nicety: the map still reads without them.
        developer.log('map sprites failed', error: e, stackTrace: st);
      }
    }
  }
  return _FetchedStyle(style, vmt.TileProviders(providers), sprites);
});

final _mapStyleProvider = FutureProvider.family<vmt.Style, MapLabelScript>((
  ref,
  script,
) async {
  final fetched = await ref.watch(_fetchedStyleProvider.future);
  return vmt.Style(
    theme: vtr.ThemeReader().read(localizeMapStyle(fetched.json, script)),
    providers: fetched.providers,
    sprites: fetched.sprites,
  );
});

typedef MapBaseLayerBuilder = Widget Function(BuildContext context);

/// The layer under everything else on a map. Production draws the
/// OpenFreeMap vector tiles; tests override it with [MapPlainBackground],
/// since a vector tile layer cannot run inside `flutter_test`.
final mapBaseLayerProvider = Provider<MapBaseLayerBuilder>(
  (_) =>
      (_) => const _OpenFreeMapLayer(),
);

/// The ground colour of a map before (or without) its tiles.
class MapPlainBackground extends StatelessWidget {
  const MapPlainBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: ColoredBox(color: scheme.surfaceContainerHighest),
    );
  }
}

class _OpenFreeMapLayer extends ConsumerWidget {
  const _OpenFreeMapLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = mapLabelScriptFor(Localizations.localeOf(context));
    final style = ref.watch(_mapStyleProvider(script));
    return switch (style) {
      AsyncData(:final value) => vmt.VectorTileLayer(
        tileProviders: value.providers,
        theme: value.theme,
        sprites: value.sprites,
      ),
      AsyncError() => const _UnavailableBackground(),
      _ => const MapPlainBackground(),
    };
  }
}

/// No tiles: the plain ground and a small note. Everything drawn on top
/// (pins, areas, the picker's crosshair) still works.
class _UnavailableBackground extends StatelessWidget {
  const _UnavailableBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        const MapPlainBackground(),
        PositionedDirectional(
          top: 8,
          start: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.mapUnavailable,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The only map widget that knows the tile source: base layer, then
/// [polygons], [markers] and [children], with the attribution always
/// reachable.
class LemqesBaseMap extends ConsumerWidget {
  const LemqesBaseMap({
    required this.initialCenter,
    this.initialZoom = 14,
    this.minZoom = 5,
    this.maxZoom = 18,
    this.controller,
    this.polygons = const [],
    this.markers = const [],
    this.children = const [],
    this.onPositionChanged,
    this.interactive = true,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final MapController? controller;
  final List<Polygon> polygons;
  final List<Marker> markers;

  /// Extra layers drawn above the markers.
  final List<Widget> children;

  /// The camera moved (by a gesture when `hasGesture`).
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;

  /// False freezes the camera (a preview).
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(mapBaseLayerProvider);
    final open = ref.watch(mapLinkLauncherProvider);
    final scheme = Theme.of(context).colorScheme;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        backgroundColor: scheme.surfaceContainerHighest,
        onPositionChanged: onPositionChanged,
        interactionOptions: InteractionOptions(
          // A rotated map makes "north up" pins and the RTL layout confusing
          // for a gain nobody asked for.
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        base(context),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ...children,
        // The widget writes the "©" itself, and a neutral "©" lands on the
        // wrong side of the names in a right-to-left layout.
        Directionality(
          textDirection: TextDirection.ltr,
          child: RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution(
                'OpenMapTiles',
                onTap: () => open(Uri.parse(openMapTilesUrl)),
              ),
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => open(Uri.parse(osmCopyrightUrl)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
