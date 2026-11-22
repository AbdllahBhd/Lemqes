import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_theme.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/status_colors.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../geo/data/geo_models.dart';
import '../../geo/data/geo_providers.dart';
import '../../live/data/live_models.dart';
import '../../live/data/live_providers.dart';
import '../../map/presentation/commune_pin.dart';
import '../../map/presentation/lemqes_base_map.dart';
import '../../map/presentation/pro_markers.dart';
import '../../pro/presentation/pro_failure_message.dart';
import '../data/explore_models.dart';
import '../data/explore_providers.dart';
import 'directions_button.dart';
import 'pro_card_tile.dart';

enum ExploreView { list, map }

/// Explore's view as the route carries it: `/explore?view=map&lat=&lng=&z=`
/// (links into a map view later); the list is `/home`.
@immutable
class ExploreLocation {
  const ExploreLocation.map(this.center, this.zoom) : view = ExploreView.map;
  const ExploreLocation._list()
    : view = ExploreView.list,
      center = null,
      zoom = null;

  static const list = ExploreLocation._list();

  /// Anything unusable in the query falls back to the defaults rather than
  /// failing the screen: a link is typed by people.
  factory ExploreLocation.fromUri(Uri uri) {
    final q = uri.queryParameters;
    if (q['view'] != 'map') return list;
    final lat = double.tryParse(q['lat'] ?? '');
    final lng = double.tryParse(q['lng'] ?? '');
    final z = double.tryParse(q['z'] ?? '');
    final centreOk =
        lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 85 &&
        lng.abs() <= 180;
    return ExploreLocation.map(
      centreOk ? GeoPoint(lat, lng) : null,
      z != null && z.isFinite
          ? z.clamp(exploreMapMinZoom, exploreMapMaxZoom).toDouble()
          : null,
    );
  }

  final ExploreView view;
  final GeoPoint? center;
  final double? zoom;

  String toLocation() {
    if (view == ExploreView.list) return '/home';
    final c = center;
    final z = zoom;
    return Uri(
      path: '/explore',
      queryParameters: {
        'view': 'map',
        if (c != null) 'lat': c.lat.toStringAsFixed(5),
        if (c != null) 'lng': c.lng.toStringAsFixed(5),
        if (z != null) 'z': z.toStringAsFixed(2),
      },
    ).toString();
  }

  /// The same location after a trip through the route (rounded).
  ExploreLocation get routed =>
      ExploreLocation.fromUri(Uri.parse(toLocation()));

  @override
  bool operator ==(Object other) =>
      other is ExploreLocation &&
      other.view == view &&
      other.center == center &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(view, center, zoom);
}

/// Hands the route's [ExploreLocation] to Explore, which sits a few widgets
/// down the home; without one Explore shows the list.
class ExploreLocationScope extends InheritedWidget {
  const ExploreLocationScope({
    required this.location,
    required super.child,
    super.key,
  });

  final ExploreLocation location;

  static ExploreLocation of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ExploreLocationScope>()
          ?.location ??
      ExploreLocation.list;

  @override
  bool updateShouldNotify(ExploreLocationScope old) => old.location != location;
}

const exploreMapMinZoom = 5.0;
const exploreMapMaxZoom = 18.0;

/// Algiers, for a customer who shared no origin.
const exploreMapDefaultCentre = GeoPoint(36.7538, 3.0588);

/// What one map search shows; the server sends one more row to say there
/// are more.
const exploreMapMax = 100;

/// `search_pros` refuses a box wider or taller than 8 degrees; just under,
/// so rounding never tips it over.
const _maxBoxSide = 7.99;

/// [box] shrunk around its centre to what the server accepts, and whether
/// it had to shrink (the map then says "zoom in").
(GeoBounds, bool) clampToSearchBox(GeoBounds box) {
  final w = box.maxLng - box.minLng;
  final h = box.maxLat - box.minLat;
  if (w <= _maxBoxSide && h <= _maxBoxSide) return (box, false);
  final cLng = (box.minLng + box.maxLng) / 2;
  final cLat = (box.minLat + box.maxLat) / 2;
  final halfW = math.min(w, _maxBoxSide) / 2;
  final halfH = math.min(h, _maxBoxSide) / 2;
  return (
    GeoBounds(cLng - halfW, cLat - halfH, cLng + halfW, cLat + halfH),
    true,
  );
}

/// One thing to place on the map; [weight] is how many pros it stands for
/// (a commune pin stands for all its pros).
@immutable
class GridPoint<T> {
  const GridPoint(this.point, this.item, {this.weight = 1});

  final LatLng point;
  final T item;
  final int weight;
}

/// Points that share a grid cell, drawn at their weighted centre.
@immutable
class GridCluster<T> {
  const GridCluster(this.point, this.members);

  final LatLng point;
  final List<GridPoint<T>> members;

  int get count => members.fold(0, (sum, m) => sum + m.weight);
}

/// Groups [points] into square cells of [cellPx] screen pixels at [zoom] in
/// Web Mercator (256 px tiles), in first-seen order. A grid, not distance
/// clustering: cheap, stable while panning (cells are fixed to the world,
/// not the screen), and a pure function. The marker-cluster package cannot
/// be installed next to the vector tiles.
List<GridCluster<T>> clusterByGrid<T>(
  List<GridPoint<T>> points,
  double zoom,
  double cellPx,
) {
  final scale = 256 * math.pow(2, zoom);
  final cells = <(int, int), List<GridPoint<T>>>{};
  for (final p in points) {
    final x = (p.point.longitude + 180) / 360 * scale;
    final sinLat = math
        .sin(p.point.latitude * math.pi / 180)
        .clamp(-0.9999, 0.9999);
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    cells
        .putIfAbsent(((x / cellPx).floor(), (y / cellPx).floor()), () => [])
        .add(p);
  }
  return [
    for (final members in cells.values)
      GridCluster(_centreOf(members), List.unmodifiable(members)),
  ];
}

LatLng _centreOf<T>(List<GridPoint<T>> members) {
  if (members.length == 1) return members.single.point;
  var lat = 0.0;
  var lng = 0.0;
  var total = 0;
  for (final m in members) {
    lat += m.point.latitude * m.weight;
    lng += m.point.longitude * m.weight;
    total += m.weight;
  }
  return LatLng(lat / total, lng / total);
}

/// A map search: the box, and which tap asked for it (the same box asked
/// again is a new search).
@immutable
class MapSearchArea {
  const MapSearchArea(this.bounds, this.seq);

  final GeoBounds bounds;
  final int seq;

  @override
  bool operator ==(Object other) =>
      other is MapSearchArea && other.bounds == bounds && other.seq == seq;

  @override
  int get hashCode => Object.hash(bounds, seq);
}

class ExploreMapResults {
  const ExploreMapResults({
    required this.items,
    required this.tooMany,
    required this.space,
  });

  final List<ProCard> items;

  /// The server had more than [exploreMapMax] in the box.
  final bool tooMany;
  final Space space;
}

/// The pros inside one searched box, with the list's text, filters and
/// origin. A separate search from the list's: the shared query never holds
/// the box, so the list is not re-searched by the map and keeps its pages.
final exploreMapResultsProvider = AsyncNotifierProvider.autoDispose
    .family<ExploreMapController, ExploreMapResults, MapSearchArea>(
      ExploreMapController.new,
      // The map offers its own retry.
      retry: (_, _) => null,
    );

class ExploreMapController extends AsyncNotifier<ExploreMapResults> {
  ExploreMapController(this.area);

  final MapSearchArea area;
  var _generation = 0;
  var _searched = false;
  String? _lastText;

  @override
  Future<ExploreMapResults> build() async {
    final generation = ++_generation;
    final q = ref.watch(exploreQueryProvider);
    final space = ref.watch(
      accountProvider.select((a) => a.value?.currentSpace),
    );
    if (space == null) return Completer<ExploreMapResults>().future;
    final debounce = ref.read(exploreDebounceProvider);
    // Typing re-searches the same box, like the list: once the typing stops.
    if (_searched && q.text != _lastText && debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
      if (generation != _generation) {
        return state.value ?? Completer<ExploreMapResults>().future;
      }
    }
    _searched = true;
    _lastText = q.text;
    final rows = await ref
        .read(exploreRepositoryProvider)
        .search(
          ExploreQuery(
            text: q.text,
            regionCode: q.regionCode,
            localityId: q.localityId,
            kidsOnly: q.kidsOnly,
            category: q.category,
            origin: q.origin,
            bbox: area.bounds,
          ),
          offset: 0,
          limit: exploreMapMax + 1,
        );
    if (generation == _generation) {
      final channels = ref.read(liveChannelsProvider);
      for (final row in rows) {
        final live = row.live;
        if (live != null) channels.seed(live);
      }
    }
    return ExploreMapResults(
      items: rows.take(exploreMapMax).toList(),
      tooMany: rows.length > exploreMapMax,
      space: space,
    );
  }
}

GeoBounds _boundsOf(MapCamera camera) {
  final b = camera.visibleBounds;
  return GeoBounds(b.west, b.south, b.east, b.north);
}

/// Markers closer than this on screen merge into one cluster.
const _cellPx = 56.0;

/// The hit box of every marker (the pins themselves are smaller).
const _markerBox = 48.0;

/// Explore as a map: exact pins with their live dot, area circles, commune
/// pins for pros who show only their commune, clusters when zoomed out. The
/// map searches once on open and then only on "Rechercher dans cette zone".
class ExploreMapView extends ConsumerStatefulWidget {
  const ExploreMapView({
    required this.space,
    required this.location,
    required this.onCameraSaved,
    super.key,
  });

  final Space space;
  final ExploreLocation location;

  /// A search was made here: the route should carry this camera.
  final ValueChanged<ExploreLocation> onCameraSaved;

  @override
  ConsumerState<ExploreMapView> createState() => _ExploreMapViewState();
}

class _ExploreMapViewState extends ConsumerState<ExploreMapView> {
  final _controller = MapController();
  late final LatLng _initialCentre;
  late final double _initialZoom;
  MapSearchArea? _area;
  late int _zoomBucket;

  /// The camera moved by hand since the last search.
  var _moved = false;

  /// The view was wider than the server takes.
  var _clamped = false;

  /// The last camera this map handed to the route, as the route rounds it.
  ExploreLocation? _written;

  @override
  void initState() {
    super.initState();
    final origin = ref.read(exploreQueryProvider).origin;
    final centre = widget.location.center ?? origin ?? exploreMapDefaultCentre;
    _initialCentre = LatLng(centre.lat, centre.lng);
    _initialZoom = widget.location.zoom ?? (origin != null ? 13 : 12);
    _zoomBucket = _initialZoom.floor();
  }

  @override
  void didUpdateWidget(ExploreMapView old) {
    super.didUpdateWidget(old);
    final next = widget.location;
    final centre = next.center;
    // A location from outside (a link), not the echo of our own search.
    if (next == old.location || next == _written || centre == null) return;
    _controller.move(
      LatLng(centre.lat, centre.lng),
      next.zoom ?? _controller.camera.zoom,
    );
    _searchCamera(_controller.camera, save: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Camera callbacks can arrive while a frame is being built.
  void _update(VoidCallback fn) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    final bucket = camera.zoom.floor();
    if (bucket == _zoomBucket && (_moved || !hasGesture)) return;
    _update(() {
      _zoomBucket = bucket;
      if (hasGesture) _moved = true;
    });
  }

  void _searchCamera(MapCamera camera, {required bool save}) {
    final (box, clamped) = clampToSearchBox(_boundsOf(camera));
    _area = MapSearchArea(box, (_area?.seq ?? 0) + 1);
    _moved = false;
    _clamped = clamped;
    _zoomBucket = camera.zoom.floor();
    if (!save) return;
    final here = ExploreLocation.map(
      GeoPoint(camera.center.latitude, camera.center.longitude),
      camera.zoom,
    );
    _written = here.routed;
    widget.onCameraSaved(here);
  }

  void _searchHere() =>
      setState(() => _searchCamera(_controller.camera, save: true));

  void _zoomInto(LatLng point) => _controller.move(
    point,
    math.min(_controller.camera.zoom + 2, exploreMapMaxZoom),
  );

  void _open(ProCard card) => context.push('/pro/${card.proId}', extra: card);

  Future<void> _showCards(List<ProCard> cards, {String? title}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => _PinSheet(
          cards: cards,
          title: title,
          onOpen: (card) {
            Navigator.of(sheet).pop();
            _open(card);
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The first search needs the visible box, which needs the size.
        _area ??= () {
          final (box, clamped) = clampToSearchBox(
            _boundsOf(
              MapCamera(
                crs: const Epsg3857(),
                center: _initialCentre,
                zoom: _initialZoom,
                rotation: 0,
                nonRotatedSize: constraints.biggest,
              ),
            ),
          );
          _clamped = clamped;
          return MapSearchArea(box, 0);
        }();
        return Consumer(builder: (context, ref, _) => _map(context, ref));
      },
    );
  }

  Widget _map(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final area = _area!;
    final results = ref.watch(exploreMapResultsProvider(area));
    // Rows searched in the other space are never drawn.
    final value = results.value?.space == widget.space ? results.value : null;
    final items = value?.items ?? const <ProCard>[];
    final layers = _layers(context, ref, items);
    final failed = results.hasError && !results.isLoading;

    return Stack(
      children: [
        Positioned.fill(
          child: LemqesBaseMap(
            key: const Key('exploreMap'),
            controller: _controller,
            initialCenter: _initialCentre,
            initialZoom: _initialZoom,
            minZoom: exploreMapMinZoom,
            maxZoom: exploreMapMaxZoom,
            polygons: layers.polygons,
            markers: layers.markers,
            onPositionChanged: _onMoved,
          ),
        ),
        if (results.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_moved)
                LemqesPrimaryButton(
                  key: const Key('exploreMapSearchArea'),
                  label: l10n.exploreMapSearchArea,
                  icon: Icons.search,
                  onPressed: _searchHere,
                )
              else if (failed)
                _MapNotice(
                  key: const Key('exploreMapError'),
                  icon: Icons.cloud_off_outlined,
                  text: proFailureMessage(l10n, results.error),
                  action: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        ref.invalidate(exploreMapResultsProvider(area)),
                    child: Text(l10n.actionRetry),
                  ),
                ),
              if ((value?.tooMany ?? false) || _clamped) ...[
                if (_moved || failed) const SizedBox(height: 8),
                _MapNotice(
                  key: const Key('exploreMapZoomIn'),
                  icon: Icons.zoom_in,
                  text: l10n.exploreMapZoomIn,
                ),
              ] else if (value != null &&
                  items.isEmpty &&
                  !results.isLoading &&
                  !_moved)
                _MapNotice(
                  key: const Key('exploreMapEmpty'),
                  icon: Icons.search_off,
                  text: l10n.exploreMapEmpty,
                ),
            ],
          ),
        ),
      ],
    );
  }

  ({List<Polygon> polygons, List<Marker> markers}) _layers(
    BuildContext context,
    WidgetRef ref,
    List<ProCard> items,
  ) {
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final status = context.statusColors;
    final polygons = <Polygon>[];
    final areaMarkers = <Marker>[];
    final points = <GridPoint<_MapItem>>[];
    final communes = <int, List<ProCard>>{};

    for (final c in items) {
      final lat = c.lat;
      final lng = c.lng;
      final radius = c.areaRadiusM;
      if (c.placeMode == PlaceMode.exact && lat != null && lng != null) {
        points.add(GridPoint(LatLng(lat, lng), _MapItem.pro(c)));
      } else if (c.placeMode == PlaceMode.area &&
          lat != null &&
          lng != null &&
          radius != null) {
        final centre = LatLng(lat, lng);
        polygons.add(areaPolygon(centre, radius, color: scheme.primary));
        areaMarkers.add(
          Marker(
            key: Key('areaPin_${c.proId}'),
            point: centre,
            width: _markerBox,
            height: _markerBox,
            child: _Tappable(
              label: _pinLabel(context, c),
              onTap: () => _showCards([c]),
              child: const _AreaDot(),
            ),
          ),
        );
      } else if (c.localityId case final id?) {
        communes.putIfAbsent(id, () => []).add(c);
      }
    }
    final names = <int, String>{};
    for (final MapEntry(key: id, value: cards) in communes.entries) {
      final locality = ref.watch(localityProvider(id)).value;
      final lat = locality?.lat;
      final lng = locality?.lng;
      // Until the commune centre is known there is nowhere to put the pin.
      if (locality == null || lat == null || lng == null) continue;
      names[id] = locality.name(locale);
      points.add(
        GridPoint(
          LatLng(lat, lng),
          _MapItem.commune(id, cards),
          weight: cards.length,
        ),
      );
    }

    final markers = <Marker>[...areaMarkers];
    for (final cluster in clusterByGrid(
      points,
      _zoomBucket.toDouble(),
      _cellPx,
    )) {
      if (cluster.members.length > 1) {
        final first = cluster.members.first.item;
        markers.add(
          Marker(
            key: Key('mapCluster_${first.key}'),
            point: cluster.point,
            width: _markerBox,
            height: _markerBox,
            child: _Tappable(
              onTap: () => _zoomInto(cluster.point),
              child: MapClusterPin(
                count: cluster.count,
                statuses: _statusSummary(context, [
                  for (final m in cluster.members) ...m.item.cards,
                ]),
              ),
            ),
          ),
        );
        continue;
      }
      final item = cluster.members.single.item;
      final point = cluster.point;
      final card = item.card;
      if (card != null) {
        markers.add(
          Marker(
            key: Key('exactPin_${card.proId}'),
            point: point,
            width: _markerBox,
            height: _markerBox,
            // The tip on the point.
            alignment: Alignment.topCenter,
            child: _Tappable(
              label: _pinLabel(context, card),
              onTap: () => _showCards([card]),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ProPin(dotColor: _dotOf(status, card.live)),
              ),
            ),
          ),
        );
      } else {
        final name = names[item.localityId]!;
        markers.add(
          Marker(
            key: Key('communePin_${item.localityId}'),
            point: point,
            width: _markerBox,
            height: _markerBox,
            child: _Tappable(
              label: _withStatuses(
                context,
                context.l10n.exploreMapCommune(name, item.cards.length),
                item.cards,
              ),
              onTap: () => _showCards(item.cards, title: name),
              child: CommunePin(count: item.cards.length),
            ),
          ),
        );
      }
    }
    return (polygons: polygons, markers: markers);
  }
}

String _statusWord(BuildContext context, LiveStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    LiveStatus.open => l10n.liveStatusOpen,
    LiveStatus.onBreak => l10n.liveStatusOnBreak,
    LiveStatus.closed => l10n.liveStatusClosed,
  };
}

/// A pin's spoken name: the dot's colour is not the only signal.
String _pinLabel(BuildContext context, ProCard card) {
  final status = card.live?.status;
  return status == null
      ? card.displayName
      : '${card.displayName}, ${_statusWord(context, status)}';
}

/// "Ouvert : 1, En pause : 2" over [cards] that came with a live status;
/// null when none did.
String? _statusSummary(BuildContext context, Iterable<ProCard> cards) {
  final counts = <LiveStatus, int>{};
  for (final c in cards) {
    final status = c.live?.status;
    if (status != null) counts[status] = (counts[status] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return [
    for (final s in LiveStatus.values)
      if (counts[s] case final n?)
        context.l10n.exploreMapStatusCount(_statusWord(context, s), n),
  ].join(', ');
}

String _withStatuses(
  BuildContext context,
  String label,
  Iterable<ProCard> cards,
) {
  final statuses = _statusSummary(context, cards);
  return statuses == null ? label : '$label. $statuses';
}

/// The live status as of the search; the card in the sheet follows the
/// channel. No dot when the row came without a live object.
Color? _dotOf(StatusColors colors, LiveSnapshot? live) =>
    switch (live?.status) {
      null => null,
      LiveStatus.open => colors.open,
      LiveStatus.onBreak => colors.onBreak,
      LiveStatus.closed => colors.closed,
    };

/// An exact pro or a commune's pros, as one clusterable point.
class _MapItem {
  _MapItem.pro(ProCard this.card) : localityId = null, cards = [card];
  _MapItem.commune(int this.localityId, this.cards) : card = null;

  final ProCard? card;
  final int? localityId;
  final List<ProCard> cards;

  String get key => card?.proId ?? 'commune_$localityId';
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child, this.label});

  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// Several pins sharing a cell: a filled primary disc with how many pros it
/// holds; a tap zooms in.
class MapClusterPin extends StatelessWidget {
  const MapClusterPin({required this.count, this.statuses, super.key});

  final int count;

  /// The members' live statuses, spoken after the count.
  final String? statuses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: [context.l10n.exploreMapCluster(count), ?statuses].join(' '),
      container: true,
      excludeSemantics: true,
      child: Container(
        width: communePinSize,
        height: communePinSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33141228),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$count',
          textDirection: TextDirection.ltr,
          style: lemqesWeight(
            theme.textTheme.titleMedium!,
            FontWeight.w600,
          ).merge(lemqesNumeric).copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// The centre of an area circle: small, so the circle reads as the place.
class _AreaDot extends StatelessWidget {
  const _AreaDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33141228),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-line note floating on the map.
class _MapNotice extends StatelessWidget {
  const _MapNotice({
    required this.icon,
    required this.text,
    this.action,
    super.key,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = this.action;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16,
          end: action == null ? 16 : 4,
          top: action == null ? 12 : 0,
          bottom: action == null ? 12 : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// The cards behind a tapped pin: one for a pin or an area, every pro of a
/// commune under its name. An exact pin's card carries the directions.
class _PinSheet extends StatelessWidget {
  const _PinSheet({required this.cards, required this.onOpen, this.title});

  final List<ProCard> cards;
  final String? title;
  final ValueChanged<ProCard> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Padding(
          key: const Key('exploreMapSheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.exploreMapCommuneNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final card = cards[i];
                    final to = directionsPointOf(card);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProCardTile(
                          key: Key('proCard_${card.proId}'),
                          card: card,
                          onTap: () => onOpen(card),
                        ),
                        if (to != null) ...[
                          const SizedBox(height: 8),
                          DirectionsButton(to: to),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where directions lead: only an exact pin has a door.
GeoPoint? directionsPointOf(ProCard card) {
  final lat = card.lat;
  final lng = card.lng;
  if (card.placeMode != PlaceMode.exact || lat == null || lng == null) {
    return null;
  }
  return GeoPoint(lat, lng);
}
