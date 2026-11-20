import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/live/data/live_api.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockApi extends Mock implements LiveApi {}

const _row = {
  'entry_id': 'e1',
  'ticket_no': 1,
  'kind': 'walk_in',
  'label': 'Client 1',
  'service_id': null,
  'duration_min': null,
  'state': 'waiting',
  'on_my_way_at': null,
  'called_at': null,
  'sort_at': '2026-11-20T10:00:00+00:00',
  'position': 1,
};

void main() {
  late _MockApi api;
  late LiveRepository repo;

  setUp(() {
    api = _MockApi();
    repo = LiveRepository(api, now: () => DateTime.utc(2026, 11, 20, 10));
  });

  final codes = <String, Matcher>{
    'not_owner': isA<NotOwner>(),
    'not_open': isA<NotOpen>(),
    'invalid_break_until': isA<InvalidBreakUntil>(),
    'request_reused': isA<RequestReused>(),
    'queue_empty': isA<QueueEmpty>(),
    'nothing_to_undo': isA<NothingToUndo>(),
    'nothing_serving': isA<NothingServing>(),
    'not_remote': isA<NotRemote>(),
    'invalid_service': isA<InvalidService>(),
    'invalid_name': isA<InvalidName>(),
    'not_listable': isA<NotListable>(),
    'own_queue': isA<OwnQueue>(),
    'pro_not_open': isA<ProNotOpen>(),
    'queue_paused': isA<QueuePaused>(),
    'already_in_queue': isA<AlreadyInQueue>(),
    'join_limit_reached': isA<JoinLimitReached>(),
    'absent_block': isA<AbsentBlock>(),
    'join_unavailable': isA<JoinUnavailable>(),
    'too_many_ids': isA<TooManyIds>(),
    'entry_not_active': isA<EntryNotActive>(),
  };

  for (final e in codes.entries) {
    test('${e.key} maps to its failure', () async {
      when(() => api.rpc(any(), any()))
          .thenThrow(PostgrestException(message: e.key));
      await expectLater(repo.callNext('p1'), throwsA(e.value));
    });
  }

  test('every code in the table is covered by a test', () {
    expect(liveFailureCodes.keys.toSet(), codes.keys.toSet());
  });

  test('every code the live migrations raise is mapped or server-only', () {
    final raised = <String>{};
    final pattern = RegExp(r"raise exception '([a-z_]+)'");
    for (final f in Directory('../supabase/migrations').listSync()) {
      if (f is! File || !f.path.contains('/2026112000')) continue;
      raised.addAll(
        pattern.allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    expect(raised, isNotEmpty);
    expect(
      raised.difference({...liveFailureCodes.keys, ...liveUnmappedCodes}),
      isEmpty,
    );
  });

  for (final code in ['request_id_required', 'invalid_status']) {
    test('$code is an unknown failure (a client bug, not a user case)', () {
      expect(liveUnmappedCodes, contains(code));
      when(() => api.rpc(any(), any()))
          .thenThrow(PostgrestException(message: code));
      expect(repo.callNext('p1'), throwsA(isA<UnknownLiveFailure>()));
    });
  }

  test('not_open is not mistaken for pro_not_open', () async {
    when(() => api.rpc(any(), any()))
        .thenThrow(const PostgrestException(message: 'pro_not_open'));
    await expectLater(repo.callNext('p1'), throwsA(isA<ProNotOpen>()));
  });

  test('unknown error and network errors', () async {
    when(() => api.rpc(any(), any()))
        .thenThrow(const PostgrestException(message: 'boom'));
    await expectLater(repo.callNext('p1'), throwsA(isA<UnknownLiveFailure>()));
    when(() => api.rpc(any(), any())).thenThrow(const SocketException('x'));
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
    when(() => api.rpc(any(), any())).thenThrow(TimeoutException('x'));
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
  });

  test('a retry after a network failure reuses the request id', () async {
    final ids = <Object?>[];
    var calls = 0;
    when(() => api.rpc('queue_call_next', any())).thenAnswer((i) async {
      ids.add((i.positionalArguments[1] as Map)['p_request_id']);
      if (++calls == 1) throw const SocketException('down');
      return [_row];
    });
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
    final rows = await repo.callNext('p1');
    expect(rows.single.ticketNo, 1);
    expect(ids[0], isNotNull);
    expect(ids[1], ids[0]);
    // A new user action after success gets a new id.
    await repo.callNext('p1');
    expect(ids[2], isNot(ids[0]));
  });

  test('a definitive failure ends the action: next try has a new id', () async {
    final ids = <Object?>[];
    when(() => api.rpc('queue_call_next', any())).thenAnswer((i) async {
      ids.add((i.positionalArguments[1] as Map)['p_request_id']);
      throw const PostgrestException(message: 'queue_empty');
    });
    await expectLater(repo.callNext('p1'), throwsA(isA<QueueEmpty>()));
    await expectLater(repo.callNext('p1'), throwsA(isA<QueueEmpty>()));
    expect(ids[1], isNot(ids[0]));
  });

  test('request ids are v4 uuids and differ per action key', () async {
    final ids = <String>[];
    when(() => api.rpc(any(), any())).thenAnswer((i) async {
      ids.add((i.positionalArguments[1] as Map)['p_request_id']! as String);
      return [_row];
    });
    await repo.callNext('p1');
    await repo.finish('p1');
    expect(
      ids[0],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(ids[1], isNot(ids[0]));
  });

  test('a pending id older than 2 minutes is not reused', () async {
    var now = DateTime.utc(2026, 11, 20, 10);
    repo = LiveRepository(api, now: () => now);
    final ids = <Object?>[];
    when(() => api.rpc('queue_call_next', any())).thenAnswer((i) async {
      ids.add((i.positionalArguments[1] as Map)['p_request_id']);
      throw const SocketException('down');
    });
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
    now = now.add(const Duration(seconds: 119));
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
    expect(ids[1], ids[0]);
    now = now.add(const Duration(seconds: 2));
    await expectLater(repo.callNext('p1'), throwsA(isA<LiveNetworkFailure>()));
    expect(ids[2], isNot(ids[0]));
  });

  group('every mutating call sends a request id', () {
    const ticket = {
      'entry_id': 'e1',
      'pro_id': 'p1',
      'pro_space': 'men',
      'ticket_no': 3,
      'state': 'waiting',
      'end_reason': null,
      'position': 1,
      'wait_min': 10,
      'on_my_way_at': null,
      'called_at': null,
      'ended_at': null,
      'display_name': 'Karim',
      'avatar_path': null,
    };
    const blocked = {
      'block_id': 'b2',
      'ticket_label': 'Sami',
      'created_at': '2026-11-20T10:00:00+00:00',
    };
    final calls = <String, (String, Future<Object?> Function(LiveRepository))>{
      'setStatus': (
        'set_live_status',
        (r) => r.setStatus('p1', LiveStatus.open),
      ),
      'extendAutoClose': ('extend_auto_close', (r) => r.extendAutoClose('p1')),
      'addWalkIn': ('queue_add_walk_in', (r) => r.addWalkIn('p1')),
      'setDetails': (
        'queue_set_details',
        (r) => r.setDetails('e1', name: 'Ali'),
      ),
      'undoWalkIn': ('queue_undo_walk_in', (r) => r.undoWalkIn('p1')),
      'callNext': ('queue_call_next', (r) => r.callNext('p1')),
      'finish': ('queue_finish', (r) => r.finish('p1')),
      'markAbsent': ('queue_mark_absent', (r) => r.markAbsent('e1')),
      'clear': ('queue_clear', (r) => r.clear('p1')),
      'setQueueSettings': (
        'set_queue_settings',
        (r) => r.setQueueSettings('p1', mode: QueueMode.open, hideCount: false),
      ),
      'block': ('queue_block', (r) => r.block('e1')),
      'unblock': ('queue_unblock', (r) => r.unblock('p1', 'b1')),
      'joinQueue': ('join_queue', (r) => r.joinQueue('p1', 's1')),
      'onMyWay': ('queue_on_my_way', (r) => r.onMyWay('e1')),
      'leaveQueue': ('leave_queue', (r) => r.leaveQueue('e1')),
    };

    Object? reply(String fn) => switch (fn) {
      'extend_auto_close' => '2026-11-20T20:30:00+00:00',
      'join_queue' || 'queue_on_my_way' || 'leave_queue' => ticket,
      'queue_unblock' => [blocked],
      'set_live_status' || 'set_queue_settings' => const {'pro_id': 'p1'},
      _ => [_row],
    };

    for (final e in calls.entries) {
      test(e.key, () async {
        final (fn, call) = e.value;
        when(() => api.rpc(any(), any()))
            .thenAnswer((i) async => reply(i.positionalArguments[0] as String));
        await call(repo);
        final params =
            verify(() => api.rpc(fn, captureAny())).captured.single as Map;
        expect(params['p_request_id'], isA<String>());
      });
    }
  });

  test('unblock names the pro and returns the remaining blocks', () async {
    when(() => api.rpc('queue_unblock', any())).thenAnswer(
      (_) async => [
        {
          'block_id': 'b2',
          'ticket_label': null,
          'created_at': '2026-11-20T10:00:00+00:00',
        },
      ],
    );
    final left = await repo.unblock('p1', 'b1');
    expect(left.single.blockId, 'b2');
    expect(left.single.ticketLabel, isNull);
    final params =
        verify(() => api.rpc('queue_unblock', captureAny())).captured.single
            as Map;
    expect(params['p_pro_id'], 'p1');
    expect(params['p_block_id'], 'b1');
  });

  test('a queue row without a name has a null label', () async {
    when(() => api.rpc('owner_queue', any())).thenAnswer(
      (_) async => [
        {..._row, 'label': null},
      ],
    );
    expect((await repo.ownerQueue('p1')).single.label, isNull);
  });

  test('join_queue returns one composite row (an object)', () async {
    when(() => api.rpc('join_queue', any())).thenAnswer(
      (_) async => {
        'entry_id': 'e1',
        'pro_id': 'p1',
        'pro_space': 'men',
        'ticket_no': 3,
        'state': 'waiting',
        'end_reason': null,
        'position': 1,
        'wait_min': 10,
        'on_my_way_at': null,
        'called_at': null,
        'ended_at': null,
        'display_name': 'Karim',
        'avatar_path': null,
      },
    );
    expect((await repo.joinQueue('p1', 's1')).ticketNo, 3);
  });

  test('snapshots parse the rows and send the ids', () async {
    when(() => api.rpc('pro_live_snapshots', any())).thenAnswer(
      (_) async => [
        {
          'pro_id': 'p1',
          'live': {
            'pro_id': 'p1',
            'status': 'closed',
            'break_until': null,
            'auto_close_at': null,
            'status_age_from': '2026-11-20T09:55:00+00:00',
            'queue_mode': 'open',
            'listed': true,
            'join_block': 'closed',
            'waiting_count': null,
            'wait_min': null,
            'serving_called_at': null,
            'serving_duration_min': null,
            'ahead_minutes': 0,
            'queue_version': 1,
            'live_version': 1,
            'server_now': '2026-11-20T10:00:00+00:00',
          },
        },
      ],
    );
    final m = await repo.snapshots(['p1']);
    expect(m['p1']!.joinBlock, JoinBlock.closed);
    verify(
      () => api.rpc('pro_live_snapshots', {
        'p_pro_ids': ['p1'],
      }),
    ).called(1);
  });
}
