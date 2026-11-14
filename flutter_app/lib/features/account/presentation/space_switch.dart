import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../data/account.dart';

/// Men / Women, one segmented control on the Lagoon band.
///
/// Only one space is ever named at a time on the screen around it; this
/// control names both because choosing is its whole job.
class SpaceSwitch extends StatelessWidget {
  const SpaceSwitch({required this.value, required this.onChanged, super.key});

  final Space value;
  final ValueChanged<Space> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {Space.men: l10n.spaceMen, Space.women: l10n.spaceWomen};
    return Semantics(
      label: l10n.spaceSwitchLabel,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Row(
          children: [
            for (final space in Space.values) ...[
              if (space != Space.values.first) const SizedBox(width: 8),
              Expanded(
                child: _Segment(
                  key: Key('spaceSwitch_${space.toDb()}'),
                  label: labels[space]!,
                  icon: space == Space.men ? Icons.man : Icons.woman,
                  selected: space == value,
                  onTap: () => onChanged(space),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = selected ? LemqesColors.deepSea : Colors.white;
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.6),
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: ink),
                    ),
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
