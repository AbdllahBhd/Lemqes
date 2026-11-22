import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/step_progress.dart';
import '../../../account/data/account.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../../explore/data/explore_models.dart' show PlaceMode;
import '../../../geo/data/device_location.dart';
import '../../../geo/data/geo_providers.dart';
import '../../../map/presentation/commune_pin.dart';
import '../../../map/presentation/lemqes_base_map.dart';
import '../../../map/presentation/pro_markers.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../pro_failure_message.dart';
import 'place_mode_control.dart';

/// The area sizes a pro may show (`area_radius_m`).
const placeRadiiM = [500, 1000, 2000];

/// Where the map opens when the commune has no known centre.
const _fallbackCentre = LatLng(36.7538, 3.0588);

/// "500 m", "1 km", "2 km" in the locale's words.
String placeRadiusLabel(AppLocalizations l10n, int metres) => metres < 1000
    ? l10n.exploreDistanceM('$metres')
    : l10n.exploreDistanceKm('${metres ~/ 1000}');

/// The words for a refused place write; never the raw exception.
String placeFailureMessage(AppLocalizations l10n, Object? error) =>
    switch (error) {
      PlaceTooFar() => l10n.placeErrorTooFar,
      PlaceOutOfCountry() => l10n.placeErrorOutOfCountry,
      PlaceNoLocality() => l10n.placeErrorNoLocality,
      _ => proFailureMessage(l10n, error),
    };

/// Saves [mode] (and its point) as the pro's place, then reloads the
/// profile. Returns the failure, or null when it was saved.
Future<ProFailure?> savePlace(
  WidgetRef ref,
  PlaceMode mode, {
  LatLng? point,
  int? radiusM,
  String? landmark,
}) async {
  try {
    await ref
        .read(proRepositoryProvider)
        .setPlace(
          mode,
          lat: point?.latitude,
          lng: point?.longitude,
          radiusM: radiusM,
          landmark: landmark,
        );
  } on ProFailure catch (e) {
    return e;
  }
  ref.invalidate(myProProvider);
  return null;
}

/// A zoom that frames the area with room around it on a phone-width map.
double _zoomForRadius(int metres) => switch (metres) {
  <= 500 => 14.5,
  <= 1000 => 13.5,
  _ => 12.5,
};

/// The pro chooses what customers see: an exact pin, an area around a
/// point, or the commune only. The point is the map centre under a fixed
/// crosshair: dragging a marker fights the map's own pan gesture, and the
/// centre is exact without any hit-testing.
class PlacePickerScreen extends ConsumerStatefulWidget {
  const PlacePickerScreen({
    required this.profile,
    required this.onDone,
    required this.onBack,
    this.onSkip,
    this.step,
    this.total,
    super.key,
  });

  final ProProfile profile;

  /// Saved: the setup goes on, the editor closes.
  final VoidCallback onDone;
  final VoidCallback onBack;

  /// "Plus tard" (setup only).
  final VoidCallback? onSkip;

  /// The setup step count; null when edited on its own.
  final int? step;
  final int? total;

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  final _map = MapController();
  late final TextEditingController _landmark;
  late PlaceMode _mode;
  late int _radius;

  /// Where the map opened; null until the commune is known.
  LatLng? _start;
  double _startZoom = 13;

  /// The camera centre: the point that will be saved.
  LatLng? _centre;
  LatLng? _commune;
  bool _acknowledged = false;
  bool _busy = false;
  bool _locating = false;

  /// The point came from "Ma position actuelle": an area centred there
  /// shows the pro's position, so the picker says so.
  bool _located = false;
  String? _failure;
  final _failureKey = GlobalKey();

  bool get _women => widget.profile.space == Space.women;
  bool get _needsAck => _women && _mode != PlaceMode.none && !_acknowledged;

  @override
  void initState() {
    super.initState();
    final saved = widget.profile.place;
    // Nothing chosen yet starts at the most private choice: showing a door
    // is the pro's decision, never a default.
    _mode = saved?.mode ?? PlaceMode.none;
    _radius = saved?.areaRadiusM ?? 1000;
    _landmark = TextEditingController(text: saved?.landmark);
    _resolveStart(saved);
  }

  @override
  void dispose() {
    _landmark.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _resolveStart(ProPlace? saved) async {
    final localityId = widget.profile.localityId;
    LatLng? commune;
    if (localityId != null) {
      try {
        final l = await ref.read(localityProvider(localityId).future);
        final lat = l?.lat;
        final lng = l?.lng;
        if (lat != null && lng != null) commune = LatLng(lat, lng);
      } on Object catch (e, st) {
        // Offline: the map opens on the fallback and the pro pans or
        // locates; the server still checks the 30 km.
        developer.log('commune centre lookup failed', error: e, stackTrace: st);
      }
    }
    final savedLat = saved?.lat;
    final savedLng = saved?.lng;
    // Never the device fix, even when already granted: an area's centre is
    // public, and a pro working from home would publish her door without
    // having chosen to. "Ma position actuelle" is the explicit way there.
    final start = savedLat != null && savedLng != null
        ? LatLng(savedLat, savedLng)
        : null;
    if (!mounted) return;
    setState(() {
      _commune = commune;
      _start = start ?? commune ?? _fallbackCentre;
      _centre = _start;
      _startZoom = switch (_mode) {
        PlaceMode.exact => 16,
        PlaceMode.area => _zoomForRadius(_radius),
        PlaceMode.none => commune == null && start == null ? 11 : 13,
      };
    });
  }

  void _setMode(PlaceMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _failure = null;
    });
    if (_start == null) return;
    switch (mode) {
      case PlaceMode.area:
        _map.move(_centre!, _zoomForRadius(_radius));
      case PlaceMode.exact:
        _map.move(_centre!, math.max(_map.camera.zoom, 15));
      case PlaceMode.none:
        final commune = _commune;
        if (commune != null) _map.move(commune, 13);
    }
  }

  void _setRadius(int metres) {
    setState(() => _radius = metres);
    if (_centre != null) _map.move(_centre!, _zoomForRadius(metres));
  }

  Future<void> _locate() async {
    if (_locating) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final device = ref.read(deviceLocationProvider);
    final permission = await device.request(precise: true);
    final fix = permission.granted ? await device.current() : null;
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placeLocateFailed)));
      return;
    }
    final point = LatLng(fix.lat, fix.lng);
    _map.move(point, math.max(_map.camera.zoom, 16));
    setState(() {
      _centre = point;
      _located = true;
    });
  }

  Future<void> _save() async {
    final centre = _centre;
    if (_busy || _needsAck || centre == null) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final landmark = _landmark.text.trim();
    final failure = await savePlace(
      ref,
      _mode,
      point: _mode == PlaceMode.none ? null : centre,
      radiusM: _mode == PlaceMode.area ? _radius : null,
      landmark: _mode == PlaceMode.exact && landmark.isNotEmpty
          ? landmark
          : null,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _failure = placeFailureMessage(l10n, failure);
      });
      // The banner sits at the top of the controls, which the pro may have
      // scrolled away (down at the acknowledgement, say).
      final reduce = MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final banner = _failureKey.currentContext;
        if (banner == null || !banner.mounted) return;
        unawaited(
          Scrollable.ensureVisible(
            banner,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          ),
        );
      });
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final step = widget.step;
    final total = widget.total;
    final onSkip = widget.onSkip;
    final edit = step == null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const BackButtonIcon(),
                    onPressed: _busy ? null : widget.onBack,
                  ),
                  const SizedBox(width: 4),
                  if (step != null && total != null)
                    Expanded(
                      child: StepProgress(step: step, total: total),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mapHeight = (constraints.maxHeight * 0.42).clamp(
                    160.0,
                    340.0,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: mapHeight, child: _buildMap(context)),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: _buildControls(context, muted),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LemqesPrimaryButton(
                    key: const Key('placeSave'),
                    label: edit ? l10n.dashboardSave : l10n.actionContinue,
                    expand: true,
                    loading: _busy,
                    onPressed: _busy || _needsAck || _start == null
                        ? null
                        : _save,
                  ),
                  if (onSkip != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('placeLater'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _busy ? null : onSkip,
                      child: Text(l10n.placeLater),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final start = _start;
    if (start == null) {
      return const Stack(
        children: [
          MapPlainBackground(),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final centre = _centre ?? start;
    final commune = _commune;
    final pointed = _mode != PlaceMode.none;
    return Stack(
      children: [
        LemqesBaseMap(
          controller: _map,
          initialCenter: start,
          initialZoom: _startZoom,
          onPositionChanged: (camera, _) =>
              setState(() => _centre = camera.center),
          polygons: [
            if (_mode == PlaceMode.area)
              areaPolygon(centre, _radius, color: scheme.primary),
          ],
          markers: [
            if (_mode == PlaceMode.none && commune != null)
              communePinMarker(commune),
          ],
        ),
        if (pointed)
          IgnorePointer(
            child: Center(
              child: Semantics(
                key: const Key('placeCrosshair'),
                label: l10n.placeChosenPoint,
                container: true,
                child: _mode == PlaceMode.exact
                    // The pin's tip, not its middle, marks the centre.
                    ? Transform.translate(
                        offset: Offset(0, -proPinSize.height / 2),
                        child: const ProPin(),
                      )
                    : _CentreDot(color: scheme.primary),
              ),
            ),
          ),
        if (pointed)
          PositionedDirectional(
            top: 8,
            start: 8,
            end: 8,
            child: IgnorePointer(
              child: Center(child: _MapNote(text: l10n.placeMoveHint)),
            ),
          ),
        if (pointed)
          // Bottom-left in every direction: the attribution button sits
          // bottom-right on the map in both.
          Positioned(
            left: 12,
            bottom: 12,
            child: FilledButton.tonalIcon(
              key: const Key('placeLocate'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: scheme.surfaceContainerLow,
                foregroundColor: scheme.primary,
                elevation: 2,
                shape: const StadiumBorder(),
              ),
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(l10n.placeLocate),
            ),
          ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, TextStyle muted) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final space = widget.profile.space.toDb();
    final failure = _failure;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );

    final preview = switch (_mode) {
      PlaceMode.exact => l10n.placePreviewExact(space),
      PlaceMode.area => l10n.placePreviewArea(
        space,
        placeRadiusLabel(l10n, _radius),
      ),
      PlaceMode.none => l10n.placePreviewNone(space),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.placeTitle, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(l10n.placeBody(space), style: muted),
        if (failure != null) ...[
          const SizedBox(height: 16),
          FailureBanner(key: _failureKey, message: failure),
        ],
        section(l10n.placeModeLabel),
        PlaceModeControl(mode: _mode, onChanged: _busy ? null : _setMode),
        if (_mode == PlaceMode.area) ...[
          section(l10n.placeRadiusLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in placeRadiiM)
                ChoiceChip(
                  key: Key('placeRadius_$r'),
                  label: Text(placeRadiusLabel(l10n, r)),
                  selected: _radius == r,
                  onSelected: _busy ? null : (_) => _setRadius(r),
                ),
            ],
          ),
        ],
        if (_mode == PlaceMode.exact) ...[
          const SizedBox(height: 24),
          TextField(
            key: const Key('placeLandmark'),
            controller: _landmark,
            maxLength: 80,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: lemqesFieldDecoration(
              context,
              label: l10n.placeLandmarkLabel,
              hint: l10n.placeLandmarkHint,
              icon: Icons.signpost_outlined,
            ).copyWith(counterText: ''),
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Row(
            key: const Key('placePreview'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.visibility_outlined,
                  size: 20,
                  color: muted.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(preview, style: muted)),
            ],
          ),
        ),
        if (_mode == PlaceMode.area && _located) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('placeAreaDeviceNote'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.my_location,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.placeAreaDeviceNote,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        if (_women && _mode != PlaceMode.none) ...[
          const SizedBox(height: 16),
          _ExposureWarning(
            acknowledged: _acknowledged,
            onChanged: _busy ? null : (v) => setState(() => _acknowledged = v),
          ),
        ],
      ],
    );
  }
}

/// S1: spaces are self-chosen, so a women's-space point is public to
/// anyone. Saving waits for the pro to say she understood.
class _ExposureWarning extends StatelessWidget {
  const _ExposureWarning({required this.acknowledged, required this.onChanged});

  final bool acknowledged;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onChanged = this.onChanged;
    // A Material, not a coloured box: the checkbox row paints its ink on it.
    return Material(
      key: const Key('placeWarning'),
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.public, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.placeWarningTitle,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.placeWarningBody,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              key: const Key('placeWarningAck'),
              value: acknowledged,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: false,
              title: Text(l10n.placeWarningAck),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentreDot extends StatelessWidget {
  const _CentreDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40141228),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    ),
  );
}

/// A small card over the map.
class _MapNote extends StatelessWidget {
  const _MapNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F141228),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium!.copyWith(color: scheme.onSurface),
        ),
      ),
    );
  }
}
