import 'package:flutter/material.dart';

import '../../core/theme/lemqes_theme.dart';
import '../../core/theme/lemqes_tokens.dart';

/// One answer among several: a white card that reads as a radio option.
///
/// Selected shows a filled check and a 2 dp primary outline all round.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(LemqesShape.cardRadius);
    final subtitle = this.subtitle;
    final badge = this.badge;
    final icon = this.icon;

    return Semantics(
      button: true,
      enabled: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          boxShadow: LemqesShape.cardShadow,
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      ExcludeSemantics(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: scheme.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (badge != null) ...[
                            const SizedBox(height: 8),
                            _Badge(label: badge),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: lemqesWeight(
            theme.textTheme.labelMedium!,
            FontWeight.w600,
          ).copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
