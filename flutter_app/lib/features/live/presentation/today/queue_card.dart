import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../explore/presentation/pro_labels.dart' show MistTag;
import '../../data/live_models.dart';
import 'today_widgets.dart';

/// "Client 3" for an entry with no name; the server never sends it.
String entryLabel(BuildContext context, OwnerQueueRow row) =>
    row.label ?? context.l10n.todayClientN(row.ticketNo);

/// The large waiting count with −1 / +1.
class QueueCountCard extends StatelessWidget {
  const QueueCountCard({
    required this.waiting,
    required this.waitMin,
    required this.onAdd,
    required this.onUndo,
    this.adding = false,
    this.undoing = false,
    super.key,
  });

  final int waiting;
  final int? waitMin;

  /// Null disables the control.
  final VoidCallback? onAdd;
  final VoidCallback? onUndo;

  /// The +1 or −1 waiting for the server: a spinner in its place.
  final bool adding;
  final bool undoing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final waitMin = this.waitMin;
    return TodayCard(
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.todayWaiting,
                    style: theme.textTheme.titleSmall?.copyWith(color: muted),
                  ),
                  Text(
                    '$waiting',
                    key: const Key('queueCount'),
                    style: lemqesWeight(
                      theme.textTheme.displayLarge!.merge(lemqesNumeric),
                      FontWeight.w600,
                    ).copyWith(height: 1.1),
                  ),
                  if (waitMin != null && waiting > 0)
                    Text(
                      l10n.todayWait(waitMin),
                      style: theme.textTheme.bodyMedium
                          ?.merge(lemqesNumeric)
                          .copyWith(color: muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // −1 then +1, left to right in every language.
          Ltr(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  key: const Key('walkInUndo'),
                  text: '−1',
                  semanticLabel: l10n.todayUndoWalkIn,
                  onPressed: onUndo,
                  busy: undoing,
                ),
                const SizedBox(width: 12),
                _StepButton(
                  key: const Key('walkInAdd'),
                  text: '+1',
                  semanticLabel: l10n.todayAddWalkIn,
                  onPressed: onAdd,
                  filled: true,
                  busy: adding,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.text,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
    this.busy = false,
    super.key,
  });

  final String text;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // No colour of its own: the button's foreground fades it when off.
    final Widget label = busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: lemqesWeight(
                lemqesNumeric.copyWith(
                  fontSize: theme.textTheme.titleLarge!.fontSize,
                ),
                FontWeight.w600,
              ),
            ),
          );
    const size = Size.square(64);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: filled
          ? FilledButton.tonal(
              style: FilledButton.styleFrom(
                fixedSize: size,
                minimumSize: size,
                padding: const EdgeInsets.all(8),
                shape: const CircleBorder(),
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
              onPressed: onPressed,
              child: label,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                fixedSize: size,
                minimumSize: size,
                padding: const EdgeInsets.all(8),
                shape: const CircleBorder(),
              ),
              onPressed: onPressed,
              child: label,
            ),
    );
  }
}

/// "En cours": the customer in the chair, with "Terminé".
class ServingCard extends StatelessWidget {
  const ServingCard({
    required this.row,
    required this.service,
    required this.onFinish,
    required this.finishing,
    super.key,
  });

  final OwnerQueueRow row;
  final String? service;
  final VoidCallback? onFinish;
  final bool finishing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final service = this.service;
    return TodayCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MistTag(l10n.todayServing),
                const SizedBox(height: 6),
                Text(
                  entryLabel(context, row),
                  style: theme.textTheme.titleMedium,
                ),
                if (service != null)
                  Text(
                    service,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('finish'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: finishing ? null : onFinish,
            icon: finishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(l10n.todayFinish),
          ),
        ],
      ),
    );
  }
}
