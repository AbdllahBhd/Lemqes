import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_derive.dart';
import 'package:lemqes/features/live/data/live_models.dart';

final t0 = DateTime.utc(2026, 11, 20, 10);

LiveSnapshot snap({
  LiveStatus status = LiveStatus.open,
  DateTime? breakUntil,
  DateTime? autoCloseAt,
  DateTime? ageFrom,
  DateTime? servingCalledAt,
  int servingDuration = 20,
  int ahead = 0,
  int? wait,
}) => LiveSnapshot(
  proId: 'p1',
  status: status,
  breakUntil: breakUntil,
  autoCloseAt: autoCloseAt ?? t0.add(const Duration(hours: 9)),
  statusAgeFrom: ageFrom ?? t0,
  queueMode: QueueMode.open,
  listed: true,
  joinBlock: null,
  waitingCount: 1,
  waitMin: wait,
  servingCalledAt: servingCalledAt,
  servingDurationMin: servingCalledAt == null ? null : servingDuration,
  aheadMinutes: ahead,
  queueVersion: 1,
  serverNow: t0,
);

void main() {
  test('open turns closed at auto_close_at without a new snapshot', () {
    final s = snap(autoCloseAt: t0.add(const Duration(minutes: 30)));
    expect(derive(s, t0).status, LiveStatus.open);
    expect(
      derive(s, t0.add(const Duration(minutes: 30))).status,
      LiveStatus.closed,
    );
    expect(derive(s, t0.add(const Duration(hours: 1))).stale, isFalse);
  });

  test('open or break is stale from 2 h of silence, closed never', () {
    final s = snap(autoCloseAt: t0.add(const Duration(hours: 9)));
    expect(derive(s, t0.add(const Duration(minutes: 119))).stale, isFalse);
    expect(derive(s, t0.add(const Duration(hours: 2))).stale, isTrue);
    final b = snap(status: LiveStatus.onBreak);
    expect(derive(b, t0.add(const Duration(hours: 2))).stale, isTrue);
    final c = snap(status: LiveStatus.closed);
    expect(derive(c, t0.add(const Duration(hours: 5))).stale, isFalse);
  });

  test('break is overdue once its return time has passed', () {
    final s = snap(
      status: LiveStatus.onBreak,
      breakUntil: t0.add(const Duration(minutes: 15)),
    );
    expect(derive(s, t0).breakOverdue, isFalse);
    expect(derive(s, t0.add(const Duration(minutes: 15))).breakOverdue, isTrue);
    final noReturn = snap(status: LiveStatus.onBreak);
    expect(derive(noReturn, t0).breakOverdue, isFalse);
    expect(derive(snap(), t0).breakOverdue, isFalse);
  });

  test(
    'wait shrinks with time since serving_called_at, never below the floor',
    () {
      final s = snap(
        servingCalledAt: t0,
        servingDuration: 20,
        ahead: 30,
        wait: 50,
      );
      expect(derive(s, t0).waitMin, 50);
      expect(derive(s, t0.add(const Duration(minutes: 10))).waitMin, 40);
      // 15 of 20 min used: 5 left + 30 ahead.
      expect(derive(s, t0.add(const Duration(minutes: 15))).waitMin, 35);
      // Overrun: serving part is floored at 5 min, total rounded up to 5.
      expect(derive(s, t0.add(const Duration(minutes: 90))).waitMin, 35);
    },
  );

  test('wait rounds up to 5 and is null when the snapshot has none', () {
    final s = snap(
      servingCalledAt: t0,
      servingDuration: 20,
      ahead: 12,
      wait: 35,
    );
    expect(derive(s, t0.add(const Duration(minutes: 3))).waitMin, 30);
    expect(derive(snap(), t0).waitMin, isNull);
  });

  test('age uses the server clock passed in', () {
    final s = snap(ageFrom: t0);
    expect(
      derive(s, t0.add(const Duration(minutes: 12))).age,
      const Duration(minutes: 12),
    );
    expect(
      derive(s, t0.subtract(const Duration(minutes: 3))).age,
      Duration.zero,
    );
  });
}
