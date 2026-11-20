import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../core/time/clock_providers.dart';
import '../../../../core/time/country_clock.dart';
import '../../../../shared/widgets/ltr.dart';

/// "19:30": an instant on the country's wall clock, whatever the device's
/// zone.
String wallTime(DateTime instant) {
  final t = countryNow(defaultCountryTimezone, instant);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// A time in tabular figures, kept left-to-right inside Arabic.
class WallTimeText extends StatelessWidget {
  const WallTimeText(this.instant, {this.style, super.key});

  final DateTime instant;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    return Ltr(
      child: Text(
        wallTime(instant),
        style: lemqesWeight(base.merge(lemqesNumeric), FontWeight.w600),
      ),
    );
  }
}

/// A white card lifted off the ground (DESIGN.md "Card lift").
class TodayCard extends StatelessWidget {
  const TodayCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LemqesShape.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A full-width notice under the band ("Hors ligne", unpublished).
class TodayBanner extends StatelessWidget {
  const TodayBanner({
    required this.icon,
    required this.message,
    this.error = false,
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = error
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final ink = error ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    final action = this.action;
    return Semantics(
      liveRegion: true,
      container: true,
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              children: [
                Icon(icon, size: 20, color: ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                  ),
                ),
                ?action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before an action that cannot be taken back; true when confirmed.
Future<bool> confirmLive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = true,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) {
      final scheme = Theme.of(dialog).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const Key('confirmCancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('confirmAction'),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}
