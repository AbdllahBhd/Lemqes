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
    repo = LiveRepository(api);
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
            'join_block': 'closed',
            'waiting_count': null,
            'wait_min': null,
            'serving_called_at': null,
            'serving_duration_min': null,
            'ahead_minutes': 0,
            'queue_version': 1,
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
