import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../geo/data/geo_models.dart';

/// Opens a directions link in the maps app; overridable so tests never
/// reach the platform.
final directionsLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Google Maps directions to [to]: the universal URL opens the app when it
/// is installed and the browser otherwise.
Uri googleMapsDirectionsUri(GeoPoint to) => Uri.parse(
  'https://www.google.com/maps/dir/?api=1&destination=${to.lat}%2C${to.lng}',
);

Uri wazeDirectionsUri(GeoPoint to) =>
    Uri.parse('https://waze.com/ul?ll=${to.lat},${to.lng}&navigate=yes');

enum _DirectionsApp { waze }

/// "Itinéraire" to an exact pin, with Waze in the overflow. Never shown for
/// an area or a commune: there is no door to lead to.
class DirectionsButton extends ConsumerWidget {
  const DirectionsButton({required this.to, super.key});

  final GeoPoint to;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final failed = context.l10n.directionsFailed;
    var opened = false;
    try {
      opened = await ref.read(directionsLauncherProvider)(uri);
    } on Object catch (e, st) {
      developer.log('directions launch failed', error: e, stackTrace: st);
    }
    if (opened) return;
    // The message lands on the page's Scaffold: a sheet's barrier would dim
    // it, so the sheet makes way.
    if (route is ModalBottomSheetRoute && route.isCurrent) navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('directions'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.directions_outlined, size: 20),
            label: Text(l10n.directionsOpen),
            onPressed: () => _open(context, ref, googleMapsDirectionsUri(to)),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<_DirectionsApp>(
          key: const Key('directionsMore'),
          tooltip: l10n.directionsMore,
          icon: const Icon(Icons.more_vert),
          onSelected: (_) => _open(context, ref, wazeDirectionsUri(to)),
          itemBuilder: (_) => [
            PopupMenuItem(
              key: const Key('directionsWaze'),
              value: _DirectionsApp.waze,
              child: Text(l10n.directionsWaze),
            ),
          ],
        ),
      ],
    );
  }
}
