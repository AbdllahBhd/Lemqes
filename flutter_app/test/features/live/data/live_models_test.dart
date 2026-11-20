import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_models.dart';

Map<String, Object?> snap({
  int version = 3,
  String serverNow = '2026-11-20T10:00:00+00:00',
}) => {
  'pro_id': 'p1',
  'status': 'open',
  'break_until': null,
  'auto_close_at': '2026-11-20T19:30:00+00:00',
  'status_age_from': '2026-11-20T09:55:00+00:00',
  'queue_mode': 'open',
  'join_block': null,
  'waiting_count': 3,
  'wait_min': 40,
  'serving_called_at': '2026-11-20T09:50:00+00:00',
  'serving_duration_min': 20,
  'ahead_minutes': 30,
  'queue_version': version,
  'server_now': serverNow,
};

void main() {
  test('the RPC live object and a broadcast payload with id parse equal', () {
    final a = LiveSnapshot.fromJson(snap());
    final b = LiveSnapshot.fromJson({
      ...snap(),
      'id': 'broadcast-id',
      'future_key': 1,
    });
    expect(b, a);
    expect(a.status, LiveStatus.open);
    expect(a.queueMode, QueueMode.open);
    expect(a.joinBlock, isNull);
    expect(a.waitingCount, 3);
    expect(a.servingCalledAt, DateTime.utc(2026, 11, 20, 9, 50));
  });

  test('join_block values map, unknown ones do not throw', () {
    expect(
      LiveSnapshot.fromJson({...snap(), 'join_block': 'on_break'}).joinBlock,
      JoinBlock.onBreak,
    );
    expect(
      LiveSnapshot.fromJson({...snap(), 'join_block': 'limited'}).joinBlock,
      JoinBlock.unknown,
    );
  });

  test('isNewerThan compares queue_version then server_now', () {
    final base = LiveSnapshot.fromJson(snap());
    expect(LiveSnapshot.fromJson(snap(version: 4)).isNewerThan(base), isTrue);
    expect(LiveSnapshot.fromJson(snap(version: 2)).isNewerThan(base), isFalse);
    expect(
      LiveSnapshot.fromJson(snap(serverNow: '2026-11-20T10:00:05+00:00'))
          .isNewerThan(base),
      isTrue,
    );
    expect(base.isNewerThan(base), isFalse);
  });

  test('owner row, ticket and block parse', () {
    final r = OwnerQueueRow.fromJson({
      'entry_id': 'e1',
      'ticket_no': 4,
      'kind': 'walk_in',
      'label': 'Client 4',
      'service_id': null,
      'duration_min': null,
      'state': 'waiting',
      'on_my_way_at': null,
      'called_at': null,
      'sort_at': '2026-11-20T10:00:00+00:00',
      'position': 2,
    });
    expect(r.kind, QueueKind.walkIn);
    expect(r.state, EntryState.waiting);
    final t = MyTicket.fromJson({
      'entry_id': 'e1',
      'pro_id': 'p1',
      'pro_space': 'men',
      'ticket_no': 4,
      'state': 'cancelled',
      'end_reason': 'end_of_day',
      'position': null,
      'wait_min': null,
      'on_my_way_at': null,
      'called_at': null,
      'ended_at': '2026-11-20T10:00:00+00:00',
      'display_name': 'Karim',
      'avatar_path': null,
    });
    expect(t.endReason, EndReason.endOfDay);
    expect(t.state, EntryState.cancelled);
    final b = BlockedCustomer.fromJson({
      'block_id': 'b1',
      'ticket_label': 'Sami',
      'created_at': '2026-11-20T10:00:00+00:00',
    });
    expect(b.ticketLabel, 'Sami');
  });
}
