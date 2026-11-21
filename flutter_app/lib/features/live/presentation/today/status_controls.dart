import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../data/live_derive.dart';
import '../../data/live_models.dart';
import 'today_widgets.dart';

String liveStatusWord(BuildContext context, LiveStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    LiveStatus.open => l10n.liveStatusOpen,
    LiveStatus.onBreak => l10n.liveStatusOnBreak,
    LiveStatus.closed => l10n.liveStatusClosed,
  };
}

/// Ouvert / En pause / Fermé on the Lagoon band, styled like the space
/// switch: the chosen status is a white pill with its status dot.
class StatusSwitch extends StatelessWidget {
  const StatusSwitch({
    required this.value,
    required this.onSelected,
    super.key,
  });

  /// The effective status; null while it loads.
  final LiveStatus? value;

  /// Null disables every segment (offline, a write in flight).
  final ValueChanged<LiveStatus>? onSelected;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;
    return Semantics(
      label: context.l10n.todayStatusLabel,
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Row(
          children: [
            for (final status in LiveStatus.values) ...[
              if (status != LiveStatus.values.first) const SizedBox(width: 8),
              Expanded(
                child: _Segment(
                  key: Key('status_${status.db}'),
                  status: status,
                  selected: status == value,
                  onTap: onSelected == null ? null : () => onSelected(status),
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
    required this.status,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final LiveStatus status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final ink = selected ? LemqesColors.deepSea : Colors.white;
    // The white pill is a light surface in both themes: light status inks.
    final dot = switch (status) {
      LiveStatus.open => StatusColors.light.open,
      LiveStatus.onBreak => StatusColors.light.onBreak,
      LiveStatus.closed => StatusColors.light.closed,
    };
    final radius = BorderRadius.circular(24);
    final label = liveStatusWord(context, status);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.6,
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                // A status word never truncates: at large text it scales
                // down to fit its third of the band.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? dot : Colors.transparent,
                          border: selected
                              ? null
                              : Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const SizedBox.square(dimension: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        maxLines: 1,
                        style: theme.textTheme.labelLarge?.copyWith(color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The break sheet's answer: minutes until the return, or null for none.
typedef BreakChoice = ({int? minutes});

const breakMinutes = [15, 30, 45, 60];

/// "Retour dans…": 15 / 30 / 45 / 60 min, or "Sans heure".
Future<BreakChoice?> showBreakSheet(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<BreakChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LemqesShape.sheetRadius),
      ),
    ),
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.todayBreakTitle,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in breakMinutes)
                _ChoicePill(
                  key: Key('break_$m'),
                  label: l10n.serviceDuration(m),
                  ltr: true,
                  onPressed: () => Navigator.of(sheet).pop((minutes: m)),
                ),
              _ChoicePill(
                key: const Key('break_none'),
                label: l10n.todayBreakNoTime,
                onPressed: () => Navigator.of(sheet).pop((minutes: null)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.onPressed,
    this.ltr = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: lemqesNumeric);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      child: ltr ? Ltr(child: text) : text,
    );
  }
}

/// What the status means right now: break return, auto-close time with
/// "Prolonger d'1 h", and the stale warning. Nothing when closed.
class StatusDetails extends StatelessWidget {
  const StatusDetails({required this.view, required this.onExtend, super.key});

  final LiveView view;

  /// Null disables "Prolonger" (offline, a write in flight).
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = view.snapshot;
    final status = view.status;
    if (status == LiveStatus.closed) return const SizedBox.shrink();
    final muted = theme.colorScheme.onSurfaceVariant;
    final autoClose = s.autoCloseAt;
    final breakUntil = s.breakUntil;
    final rows = <Widget>[
      if (status == LiveStatus.onBreak)
        _DetailRow(
          icon: Icons.coffee_outlined,
          color: context.statusColors.onBreak,
          children: [
            if (view.breakOverdue)
              Text(l10n.todayBreakOverdue)
            else if (breakUntil != null) ...[
              Text(l10n.todayBreakBack),
              WallTimeText(breakUntil),
            ] else
              Text(l10n.todayBreakOpenEnded),
          ],
        ),
      if (autoClose != null)
        _DetailRow(
          icon: Icons.schedule_outlined,
          color: muted,
          trailing: TextButton(
            key: const Key('extendAutoClose'),
            onPressed: onExtend,
            child: Text(l10n.todayExtend),
          ),
          children: [Text(l10n.todayAutoClose), WallTimeText(autoClose)],
        ),
      if (view.stale)
        _DetailRow(
          icon: Icons.info_outline,
          color: muted,
          children: [
            Text(
              l10n.todayStaleNote,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return TodayCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyLarge,
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
