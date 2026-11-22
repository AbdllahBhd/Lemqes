import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../explore/data/explore_models.dart' show PlaceMode;

/// Pin · Zone · Commune seulement as three equal tiles. Not a
/// `SegmentedButton`: "Commune seulement" needs two lines at phone width and
/// in large text, which a segmented button clips.
class PlaceModeControl extends StatelessWidget {
  const PlaceModeControl({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final PlaceMode mode;
  final ValueChanged<PlaceMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      (PlaceMode.exact, l10n.placeModeExact, Icons.location_on_outlined),
      (PlaceMode.area, l10n.placeModeArea, Icons.radar_outlined),
      (PlaceMode.none, l10n.placeModeNone, Icons.location_city_outlined),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (value, label, icon)) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _ModeTile(
                key: Key('placeMode_${value.toDb()}'),
                label: label,
                icon: icon,
                selected: value == mode,
                onTap: onChanged == null ? null : () => onChanged!(value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(12);
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(child: Icon(icon, color: fg)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: lemqesWeight(
                      theme.textTheme.labelLarge!,
                      selected ? FontWeight.w600 : FontWeight.w500,
                    ).copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
