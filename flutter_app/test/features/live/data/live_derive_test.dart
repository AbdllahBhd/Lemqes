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
  bool countHidden = false,
}) => LiveSnapshot(
  proId: 'p1',
  status: status,
  breakUntil: breakUntil,
  autoCloseAt: autoCloseAt ?? t0.add(const Duration(hours: 9)),
  statusAgeFrom: ageFrom ?? t0,
  queueMode: QueueMode.open,
  listed: true,
  joinBlock: null,
  countHidden: countHidden,
  waitingCount: countHidden ? null : 1,
  waitMin: wait,
  servingCalledAt: servingCalledAt,
  servingDurationMin: servingCalledAt == null ? null : servingDuration,
  aheadMinutes: ahead,
  queueVersion: 1,
  liveVersion: 1,
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

  test('a hidden count shows the server\'s rounded wait, never recounted', () {
    // What a hidden-count snapshot carries: wait_min only, no inputs.
    final s = snap(wait: 40, countHidden: true);
    expect(derive(s, t0).waitMin, 40);
    expect(derive(s, t0.add(const Duration(minutes: 25))).waitMin, 40);
  });

  test('a closed snapshot without an age reads closed, never stale', () {
    final s = LiveSnapshot.fromJson({
      ..._closedJson,
      'server_now': t0.toIso8601String(),
    });
    final later = derive(s, t0.add(const Duration(hours: 5)));
    expect(later.status, LiveStatus.closed);
    expect(later.stale, isFalse);
    expect(later.age, Duration.zero);
    expect(later.waitMin, isNull);
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

  group('ticketWait', () {
    MyTicket ticket({String state = 'waiting', int? ahead = 20}) =>
        MyTicket.fromJson({
          'entry_id': 'e1',
          'pro_id': 'p1',
          'pro_space': 'men',
          'ticket_no': 3,
          'state': state,
          'end_reason': null,
          'position': state == 'waiting' ? 2 : null,
          'wait_min': state == 'waiting' ? 30 : null,
          'ahead_minutes': state == 'waiting' ? ahead : null,
          'on_my_way_at': null,
          'called_at': null,
          'ended_at': null,
          'display_name': 'Karim',
          'avatar_path': null,
        });

    test('recounts the chair from the snapshot, as cards do', () {
      // 20 min service called at 09:50: 10 left at 10:00, the floor of 5
      // from 10:15 on.
      final s = snap(servingCalledAt: t0.subtract(const Duration(minutes: 10)));
      expect(ticketWait(ticket(), s, t0), 30);
      expect(ticketWait(ticket(), s, t0.add(const Duration(minutes: 6))), 25);
      expect(ticketWait(ticket(), s, t0.add(const Duration(hours: 1))), 25);
      // Nobody in the chair: the minutes ahead alone.
      expect(ticketWait(ticket(ahead: 0), snap(), t0), 0);
    });

    test('falls back to the fetched wait without a snapshot or inputs', () {
      expect(ticketWait(ticket(), null, t0), 30);
      // Hidden count: the pro's snapshot carries no chair to recount.
      expect(ticketWait(ticket(), snap(wait: 40, countHidden: true), t0), 30);
      expect(ticketWait(ticket(ahead: null), snap(), t0), 30);
      expect(ticketWait(ticket(state: 'serving'), snap(), t0), isNull);
    });
  });
}

/// A closed pro as the server sends it (and as a blocked customer reads any
/// pro that blocked them): no times, age, queue or wait.
const _closedJson = <String, Object?>{
  'pro_id': 'p1',
  'status': 'closed',
  'break_until': null,
  'auto_close_at': null,
  'status_age_from': null,
  'queue_mode': 'open',
  'listed': true,
  'count_hidden': false,
  'join_block': 'closed',
  'waiting_count': null,
  'wait_min': null,
  'serving_called_at': null,
  'serving_duration_min': null,
  'ahead_minutes': null,
  'queue_version': 4,
  'live_version': 9,
};
