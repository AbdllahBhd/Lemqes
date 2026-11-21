import 'package:material_ui/material_ui.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/lemqes_typography.dart';
import '../../core/theme/status_colors.dart';
import '../../features/pro/data/pro_models.dart';
import 'ltr.dart';

// Algerian week: Saturday first (ISO weekdays).
const _order = [6, 7, 1, 2, 3, 4, 5];

String _dayName(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.weekdayMon,
  2 => l10n.weekdayTue,
  3 => l10n.weekdayWed,
  4 => l10n.weekdayThu,
  5 => l10n.weekdayFri,
  6 => l10n.weekdaySat,
  _ => l10n.weekdaySun,
};

String _hm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The weekly opening hours, Saturday first. A weekday missing from [week] is
/// closed; today (from [clock], the country's wall clock) sits on the pill tint and carries a tag, so
/// it never relies on colour alone.
class HoursTable extends StatelessWidget {
  const HoursTable({super.key, required this.week, required this.clock});

  final List<DayHours> week;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = clock().weekday;
    final byDay = {for (final h in week) h.weekday: h};
    return Column(
      children: [
        for (final wd in _order)
          _DayRow(
            weekday: wd,
            hours: byDay[wd],
            isToday: wd == today,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.hours,
    required this.isToday,
    required this.l10n,
  });

  final int weekday;
  final DayHours? hours;
  final bool isToday;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final h = hours;
    final ink = isToday ? scheme.onSecondaryContainer : scheme.onSurface;
    final dayStyle = lemqesWeight(
      theme.textTheme.bodyLarge!.copyWith(color: ink),
      isToday ? FontWeight.w600 : FontWeight.w400,
    );
    final timeStyle = lemqesWeight(
      theme.textTheme.bodyLarge!.merge(lemqesNumeric).copyWith(color: ink),
      FontWeight.w500,
    );
    final mutedStyle = theme.textTheme.bodyMedium!.copyWith(
      color: isToday ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
    );

    final Widget times;
    if (h == null) {
      times = Text(
        l10n.hoursClosed,
        style: dayStyle.copyWith(color: context.statusColors.closed),
        textAlign: TextAlign.end,
      );
    } else {
      final bs = h.breakStart;
      final be = h.breakEnd;
      times = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Ltr(
            child: Text('${_hm(h.opens)} – ${_hm(h.closes)}', style: timeStyle),
          ),
          if (bs != null && be != null)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              children: [
                Text(l10n.hoursBreakLabel, style: mutedStyle),
                Ltr(
                  child: Text(
                    '${_hm(bs)} – ${_hm(be)}',
                    style: mutedStyle.merge(lemqesNumeric),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Semantics(
      container: true,
      child: DecoratedBox(
        key: isToday ? Key('today_$weekday') : null,
        decoration: BoxDecoration(
          color: isToday ? scheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_dayName(l10n, weekday), style: dayStyle),
                      if (isToday) Text(l10n.hoursToday, style: mutedStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Align pins the times to the trailing edge in both directions.
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: times,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
