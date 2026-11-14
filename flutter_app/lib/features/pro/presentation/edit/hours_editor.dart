import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../data/pro_models.dart';

/// Why a day would be refused by `set_pro_hours`.
enum HoursIssue { sameTimes, lateClose, breakOrder, breakOutside }

int _min(TimeOfDay t) => t.hour * 60 + t.minute;

/// The client copy of the `set_pro_hours` rules, so a wrong day is flagged
/// before it is sent: closing after midnight up to 06:00, and a break
/// strictly inside the open span (past midnight: `[opens, 24:00) + [00:00,
/// closes]`) that ends after it starts.
HoursIssue? hoursIssue(DayHours d) {
  final opens = _min(d.opens);
  final closes = _min(d.closes);
  if (opens == closes) return HoursIssue.sameTimes;
  if (closes < opens && closes > 6 * 60) return HoursIssue.lateClose;
  final bs = d.breakStart;
  final be = d.breakEnd;
  if (bs == null || be == null) return null;
  final start = _min(bs);
  final end = _min(be);
  if (end <= start) return HoursIssue.breakOrder;
  final inside = closes > opens
      ? start > opens && end < closes
      : start > opens || end < closes;
  return inside ? null : HoursIssue.breakOutside;
}

String _issueText(AppLocalizations l10n, HoursIssue issue) => switch (issue) {
  HoursIssue.sameTimes => l10n.hoursErrorSameTimes,
  HoursIssue.lateClose => l10n.hoursErrorLateClose,
  HoursIssue.breakOrder => l10n.hoursErrorBreakOrder,
  HoursIssue.breakOutside => l10n.hoursErrorBreakOutside,
};

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

// Algerian week: Saturday first (ISO weekdays).
const _order = [6, 7, 1, 2, 3, 4, 5];

typedef TimePick = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initial,
);

/// How screens ask for a time; replaced in tests, where the dialog is not
/// what is under test.
final timePickProvider = Provider<TimePick>((_) => _pick24h);

Future<TimeOfDay?> _pick24h(BuildContext context, TimeOfDay initial) =>
    showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

class _Day {
  _Day({
    required this.open,
    required this.opens,
    required this.closes,
    this.breakStart,
    this.breakEnd,
  });

  bool open;
  TimeOfDay opens;
  TimeOfDay closes;
  TimeOfDay? breakStart;
  TimeOfDay? breakEnd;

  DayHours toHours(int weekday) => DayHours(
    weekday: weekday,
    opens: opens,
    closes: closes,
    breakStart: breakStart,
    breakEnd: breakEnd,
  );
}

/// The week, one block per day (Saturday first): an open switch, 24 h
/// opening and closing times, an optional break, and "copy to every day".
///
/// [onChanged] gets the open days only (a missing weekday is closed) and
/// whether every one of them passes [hoursIssue].
class HoursEditor extends StatefulWidget {
  const HoursEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.pickTime = _pick24h,
  });

  final List<DayHours> initial;
  final void Function(List<DayHours> week, bool valid) onChanged;
  final TimePick pickTime;

  @override
  State<HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends State<HoursEditor> {
  late final Map<int, _Day> _days;

  @override
  void initState() {
    super.initState();
    final given = {for (final d in widget.initial) d.weekday: d};
    _days = {
      for (var wd = 1; wd <= 7; wd++)
        wd: given[wd] == null
            ? _Day(
                open: false,
                opens: const TimeOfDay(hour: 9, minute: 0),
                closes: const TimeOfDay(hour: 19, minute: 0),
              )
            : _Day(
                open: true,
                opens: given[wd]!.opens,
                closes: given[wd]!.closes,
                breakStart: given[wd]!.breakStart,
                breakEnd: given[wd]!.breakEnd,
              ),
    };
  }

  void _update(void Function() change) {
    setState(change);
    final week = [
      for (var wd = 1; wd <= 7; wd++)
        if (_days[wd]!.open) _days[wd]!.toHours(wd),
    ];
    widget.onChanged(week, week.every((d) => hoursIssue(d) == null));
  }

  Future<void> _pick(
    TimeOfDay initial,
    void Function(TimeOfDay picked) apply,
  ) async {
    final picked = await widget.pickTime(context, initial);
    if (picked == null || !mounted) return;
    _update(() => apply(picked));
  }

  void _addBreak(_Day d) {
    final opens = _min(d.opens);
    var span = _min(d.closes) - opens;
    if (span <= 0) span += 24 * 60;
    // An hour in the middle of the day, on a half hour.
    final start = (opens + span ~/ 2) ~/ 30 * 30;
    TimeOfDay at(int m) => TimeOfDay(hour: m ~/ 60 % 24, minute: m % 60);
    _update(() {
      d.breakStart = at(start);
      d.breakEnd = at(start + 60);
    });
  }

  // Closed days keep their closure (it may be off-screen) but take the
  // times, so opening one later starts from them.
  void _copyToAll(_Day from) => _update(() {
    for (final d in _days.values) {
      d
        ..opens = from.opens
        ..closes = from.closes
        ..breakStart = from.breakStart
        ..breakEnd = from.breakEnd;
    }
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final wd in _order) ...[
          if (wd != _order.first)
            Divider(height: 1, color: scheme.outlineVariant),
          _dayBlock(context, wd, _days[wd]!),
        ],
      ],
    );
  }

  Widget _dayBlock(BuildContext context, int wd, _Day d) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _dayName(l10n, wd);
    final issue = d.open ? hoursIssue(d.toHours(wd)) : null;
    final bs = d.breakStart;
    final be = d.breakEnd;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      key: Key('day_$wd'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: lemqesWeight(
                    theme.textTheme.titleMedium!,
                    FontWeight.w600,
                  ),
                ),
              ),
              if (!d.open) Text(l10n.hoursClosed, style: muted),
              Semantics(
                label: name,
                child: Switch(
                  key: Key('day_${wd}_open'),
                  value: d.open,
                  onChanged: (v) => _update(() => d.open = v),
                ),
              ),
            ],
          ),
          if (d.open) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Ltr(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      _TimeButton(
                        key: Key('day_${wd}_opens'),
                        label: l10n.hoursOpens,
                        time: d.opens,
                        onTap: () => _pick(d.opens, (t) => d.opens = t),
                      ),
                      const Text('–'),
                      _TimeButton(
                        key: Key('day_${wd}_closes'),
                        label: l10n.hoursCloses,
                        time: d.closes,
                        onTap: () => _pick(d.closes, (t) => d.closes = t),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('day_${wd}_copy'),
                  tooltip: l10n.hoursCopyAll,
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () => _copyToAll(d),
                ),
              ],
            ),
            if (d.toHours(wd).pastMidnight)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.nightlight_outlined,
                      size: 18,
                      color: muted.color,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.hoursPastMidnightNote,
                        key: Key('day_${wd}_pastMidnight'),
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ),
            if (bs != null && be != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(l10n.hoursBreakLabel, style: muted),
                  Ltr(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        _TimeButton(
                          key: Key('day_${wd}_breakStart'),
                          label: l10n.hoursBreakStart,
                          time: bs,
                          onTap: () => _pick(bs, (t) => d.breakStart = t),
                        ),
                        const Text('–'),
                        _TimeButton(
                          key: Key('day_${wd}_breakEnd'),
                          label: l10n.hoursBreakEnd,
                          time: be,
                          onTap: () => _pick(be, (t) => d.breakEnd = t),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('day_${wd}_removeBreak'),
                    tooltip: l10n.hoursRemoveBreak,
                    icon: const Icon(Icons.close),
                    onPressed: () => _update(() {
                      d.breakStart = null;
                      d.breakEnd = null;
                    }),
                  ),
                ],
              )
            else
              TextButton.icon(
                key: Key('day_${wd}_addBreak'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.add),
                label: Text(l10n.hoursAddBreak),
                onPressed: () => _addBreak(d),
              ),
            if (issue != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _issueText(l10n, issue),
                  key: Key('day_${wd}_error'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = _hm(time);
    return Semantics(
      button: true,
      label: '$label, $text',
      excludeSemantics: true,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
        onPressed: onTap,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium!.merge(lemqesNumeric),
        ),
      ),
    );
  }
}
