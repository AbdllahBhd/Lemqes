import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/lemqes_theme.dart';

const communePinSize = 44.0;

/// A commune centre: pros there who show no point of their own. A mist disc
/// with a teal ring, holding [count] (pros there) or a place icon.
class CommunePin extends StatelessWidget {
  const CommunePin({this.count, this.label, super.key});

  final int? count;

  /// The commune's name, for screen readers.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = this.count;
    return Semantics(
      label: label,
      container: label != null,
      child: Container(
        width: communePinSize,
        height: communePinSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33141228),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: count == null
            ? Icon(
                Icons.location_city_outlined,
                size: 22,
                color: scheme.onSecondaryContainer,
              )
            : Text(
                '$count',
                textDirection: TextDirection.ltr,
                style:
                    lemqesWeight(theme.textTheme.titleMedium!, FontWeight.w600)
                        .merge(lemqesNumeric)
                        .copyWith(color: scheme.onSecondaryContainer),
              ),
      ),
    );
  }
}

/// A [CommunePin] centred on [point].
Marker communePinMarker(LatLng point, {int? count, String? label, Key? key}) =>
    Marker(
      key: key,
      point: point,
      width: communePinSize,
      height: communePinSize,
      child: CommunePin(count: count, label: label),
    );
