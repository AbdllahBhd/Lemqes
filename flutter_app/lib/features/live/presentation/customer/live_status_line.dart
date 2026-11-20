import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/time/clock_providers.dart';
import '../../data/live_derive.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../today/today_widgets.dart' show wallTime;
import 'live_words.dart';

/// The status dot: filled for a status the customer can trust, hollow for
/// an uncertain one. Never the only signal: the word is always beside it.
class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, this.hollow = false, super.key});

  final Color color;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hollow ? null : color,
          border: hollow ? Border.all(color: color, width: 1.5) : null,
        ),
      ),
    );
  }
}

/// "● Ouvert · il y a 10 min", "● En pause · retour 14:30 · il y a 5 min",
/// "● Fermé", "○ Statut incertain · il y a 2 h"; while the live connection
/// is down, "○ Mis à jour il y a 3 min" instead of a confident status.
/// One text, so it wraps as a sentence and reads as one.
class LiveStatusLine extends ConsumerWidget {
  const LiveStatusLine({required this.view, this.large = false, super.key});

  final LiveView view;

  /// The profile's live block: one step up the type scale.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = context.statusColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final base =
        (large ? theme.textTheme.bodyLarge! : theme.textTheme.bodyMedium!)
            .merge(lemqesNumeric)
            .copyWith(color: muted);
    final connected = ref.watch(liveConnectedProvider);
    final v = view;

    final Color dot;
    var hollow = false;
    String word;
    Color? wordColor;
    final details = <String>[];
    if (!connected) {
      // Since the last snapshot reached this device, on the server clock.
      final since = ref
          .watch(serverNowProvider)()
          .difference(v.snapshot.serverNow);
      final minutes = since.isNegative ? 0 : since.inMinutes;
      dot = status.closed;
      hollow = true;
      word = minutes == 0 ? l10n.liveUpdatedNow : l10n.liveUpdatedAgo(minutes);
    } else if (v.status == LiveStatus.closed) {
      dot = status.closed;
      word = l10n.liveStatusClosed;
      wordColor = status.closed;
    } else if (v.stale) {
      dot = status.closed;
      hollow = true;
      word = l10n.liveStale;
      details.add(liveAgeText(l10n, v.age));
    } else if (v.status == LiveStatus.onBreak) {
      dot = status.onBreak;
      wordColor = status.onBreak;
      word = v.breakOverdue ? l10n.todayBreakOverdue : l10n.liveStatusOnBreak;
      final until = v.snapshot.breakUntil;
      if (until != null && !v.breakOverdue) {
        details.add(l10n.liveBreakReturn(ltrIsolate(wallTime(until))));
      }
      details.add(liveAgeText(l10n, v.age));
    } else {
      dot = status.open;
      wordColor = status.open;
      word = l10n.liveStatusOpen;
      details.add(liveAgeText(l10n, v.age));
    }

    final wordStyle = wordColor == null
        ? base
        : lemqesWeight(base.copyWith(color: wordColor), FontWeight.w600);
    return Text.rich(
      key: const Key('liveStatusLine'),
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: StatusDot(color: dot, hollow: hollow),
            ),
          ),
          TextSpan(text: word, style: wordStyle),
          // Each detail stays whole ("il y a 5 min"); the line breaks
          // between them.
          for (final d in details)
            TextSpan(text: ' · ${d.replaceAll(' ', '\u00a0')}'),
        ],
      ),
      style: base,
    );
  }
}

/// "3 en attente · ~40 min" and its variants under the status; nothing when
/// closed, uncertain, or while the live connection is down.
class LiveQueueLine extends ConsumerWidget {
  const LiveQueueLine({required this.view, this.large = false, super.key});

  final LiveView view;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(liveConnectedProvider)
        ? queueLineText(context.l10n, view)
        : null;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style =
        (large ? theme.textTheme.titleMedium! : theme.textTheme.bodyMedium!)
            .merge(lemqesNumeric)
            .copyWith(color: theme.colorScheme.onSurface);
    return Text(text, key: const Key('liveQueueLine'), style: style);
  }
}
