import 'live_models.dart';

/// A silent open/break status older than this reads "Statut incertain".
const staleAfter = Duration(hours: 2);

/// What a screen shows for a [LiveSnapshot] at a given server time.
class LiveView {
  const LiveView({
    required this.snapshot,
    required this.status,
    required this.stale,
    required this.breakOverdue,
    required this.waitMin,
    required this.age,
  });

  final LiveSnapshot snapshot;

  /// Effective status: `closed` once `auto_close_at` has passed, even if no
  /// message said so.
  final LiveStatus status;
  final bool stale;
  final bool breakOverdue;

  /// Wait shrunk to [derive]'s time; null when the snapshot carries none.
  final int? waitMin;

  /// Time since the last barber activity, on the server clock.
  final Duration age;
}

int _ceil5(int m) => (m + 4) ~/ 5 * 5;

/// Pure: re-derives closed, stale, break end, wait and age at [serverNow]
/// (the snapshot's server clock advanced locally), so a card that receives no
/// message still goes "Fermé" on time.
LiveView derive(LiveSnapshot s, DateTime serverNow) {
  final now = serverNow.toUtc();
  final autoClose = s.autoCloseAt;
  final status =
      s.status != LiveStatus.closed &&
          autoClose != null &&
          !autoClose.isAfter(now)
      ? LiveStatus.closed
      : s.status;
  final age = now.difference(s.statusAgeFrom);
  final stale = status != LiveStatus.closed && age >= staleAfter;
  final until = s.breakUntil;
  final breakOverdue =
      status == LiveStatus.onBreak && until != null && !until.isAfter(now);
  return LiveView(
    snapshot: s,
    status: status,
    stale: stale,
    breakOverdue: breakOverdue,
    waitMin: _wait(s, now),
    age: age.isNegative ? Duration.zero : age,
  );
}

int? _wait(LiveSnapshot s, DateTime now) {
  if (s.waitMin == null) return null;
  final called = s.servingCalledAt;
  var serving = 0;
  if (called != null) {
    final elapsed = now.difference(called).inMinutes;
    final remaining = (s.servingDurationMin ?? 0) - (elapsed < 0 ? 0 : elapsed);
    serving = remaining < 5 ? 5 : remaining;
  }
  return _ceil5(serving + s.aheadMinutes);
}
