import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'live_api.dart';
import 'live_failure.dart';
import 'live_models.dart';

final liveApiProvider = Provider<LiveApi>(
  (ref) => SupabaseLiveApi(ref.watch(supabaseClientProvider)),
);

final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepository(ref.watch(liveApiProvider)),
);

/// A random (version 4) UUID; `dart:math` avoids a new dependency.
String newRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// One method per client RPC. Each mutating call carries a request id that
/// the server uses to make a repeat harmless; the id is kept while an action
/// ends in an unknown outcome (network, unknown error) so the retry of that
/// same action reuses it, and dropped on success or a definitive refusal.
class LiveRepository {
  LiveRepository(this._api, {String Function()? newId})
    : _newId = newId ?? newRequestId;

  final LiveApi _api;
  final String Function() _newId;
  final Map<String, String> _pending = {};

  Future<T> _act<T>(
    String key,
    Future<T> Function(String requestId) body,
  ) async {
    final id = _pending[key] ??= _newId();
    try {
      final out = await guardLive(() => body(id));
      _pending.remove(key);
      return out;
    } on LiveFailure catch (f) {
      if (!isRetryable(f)) _pending.remove(key);
      rethrow;
    }
  }

  List<OwnerQueueRow> _rows(Object? raw) => [
    for (final r in raw! as List<Object?>)
      OwnerQueueRow.fromJson(r! as Map<String, Object?>),
  ];

  Future<List<OwnerQueueRow>> _queueAction(
    String fn,
    String key,
    Map<String, Object?> params,
  ) => _act(key, (id) async {
    return _rows(await _api.rpc(fn, {...params, 'p_request_id': id}));
  });

  // Owner status.

  Future<void> setStatus(
    String proId,
    LiveStatus status, {
    DateTime? breakUntil,
  }) => _act('set_status:$proId:${status.db}:$breakUntil', (id) async {
    await _api.rpc('set_live_status', {
      'p_pro_id': proId,
      'p_status': status.db,
      'p_break_until': breakUntil?.toUtc().toIso8601String(),
      'p_request_id': id,
    });
  });

  /// Returns the new auto-close time.
  Future<DateTime> extendAutoClose(String proId) =>
      _act('extend_auto_close:$proId', (id) async {
        final v = await _api.rpc('extend_auto_close', {
          'p_pro_id': proId,
          'p_request_id': id,
        });
        return DateTime.parse(v! as String).toUtc();
      });

  // Owner queue.

  Future<List<OwnerQueueRow>> ownerQueue(String proId) => guardLive(
    () async => _rows(await _api.rpc('owner_queue', {'p_pro_id': proId})),
  );

  Future<List<OwnerQueueRow>> addWalkIn(String proId) => _queueAction(
    'queue_add_walk_in',
    'add_walk_in:$proId',
    {'p_pro_id': proId},
  );

  Future<List<OwnerQueueRow>> setDetails(
    String entryId, {
    String? name,
    String? serviceId,
  }) => _queueAction(
    'queue_set_details',
    'set_details:$entryId:$name:$serviceId',
    {'p_entry_id': entryId, 'p_name': name, 'p_service_id': serviceId},
  );

  Future<List<OwnerQueueRow>> undoWalkIn(String proId) => _queueAction(
    'queue_undo_walk_in',
    'undo_walk_in:$proId',
    {'p_pro_id': proId},
  );

  Future<List<OwnerQueueRow>> callNext(String proId) =>
      _queueAction('queue_call_next', 'call_next:$proId', {'p_pro_id': proId});

  Future<List<OwnerQueueRow>> finish(String proId) =>
      _queueAction('queue_finish', 'finish:$proId', {'p_pro_id': proId});

  Future<List<OwnerQueueRow>> markAbsent(String entryId) => _queueAction(
    'queue_mark_absent',
    'mark_absent:$entryId',
    {'p_entry_id': entryId},
  );

  Future<List<OwnerQueueRow>> clear(String proId) =>
      _queueAction('queue_clear', 'clear:$proId', {'p_pro_id': proId});

  // Settings and blocks.

  Future<void> setQueueSettings(
    String proId, {
    required QueueMode mode,
    required bool hideCount,
  }) => _act('settings:$proId:${mode.db}:$hideCount', (id) async {
    await _api.rpc('set_queue_settings', {
      'p_pro_id': proId,
      'p_mode': mode.db,
      'p_hide_count': hideCount,
      'p_request_id': id,
    });
  });

  Future<void> block(String entryId) => _act('block:$entryId', (id) async {
    await _api.rpc('queue_block', {'p_entry_id': entryId, 'p_request_id': id});
  });

  Future<void> unblock(String blockId) => _act('unblock:$blockId', (id) async {
    await _api.rpc('queue_unblock', {
      'p_block_id': blockId,
      'p_request_id': id,
    });
  });

  Future<List<BlockedCustomer>> blocked(String proId) => guardLive(() async {
    final raw = await _api.rpc('queue_blocked', {'p_pro_id': proId});
    return [
      for (final r in raw! as List<Object?>)
        BlockedCustomer.fromJson(r! as Map<String, Object?>),
    ];
  });

  // Customer.

  /// Raises the first failing join rule without joining.
  Future<void> canJoin(String proId) => guardLive(() async {
    await _api.rpc('can_join', {'p_pro_id': proId});
  });

  Future<MyTicket> joinQueue(String proId, String serviceId) =>
      _act('join:$proId:$serviceId', (id) async {
        final raw = await _api.rpc('join_queue', {
          'p_pro_id': proId,
          'p_service_id': serviceId,
          'p_request_id': id,
        });
        return MyTicket.fromJson(_first(raw)!);
      });

  Future<void> onMyWay(String entryId) =>
      _act('on_my_way:$entryId', (id) async {
        await _api.rpc('queue_on_my_way', {
          'p_entry_id': entryId,
          'p_request_id': id,
        });
      });

  Future<void> leaveQueue(String entryId) => _act('leave:$entryId', (id) async {
    await _api.rpc('leave_queue', {'p_entry_id': entryId, 'p_request_id': id});
  });

  /// The caller's active ticket, or the latest ended one within 30 min.
  Future<MyTicket?> myTicket() => guardLive(() async {
    final row = _first(await _api.rpc('my_ticket', const {}));
    return row == null ? null : MyTicket.fromJson(row);
  });

  /// Snapshots by pro id; ids the caller cannot see are absent. At most 60
  /// ids per call.
  Future<Map<String, LiveSnapshot>> snapshots(List<String> proIds) =>
      guardLive(() async {
        final raw = await _api.rpc('pro_live_snapshots', {'p_pro_ids': proIds});
        return {
          for (final r in raw! as List<Object?>)
            (r! as Map<String, Object?>)['pro_id']!
                as String: LiveSnapshot.fromJson(
              (r as Map<String, Object?>)['live']! as Map<String, Object?>,
            ),
        };
      });
}

Map<String, Object?>? _first(Object? raw) {
  if (raw == null) return null;
  if (raw is List<Object?>) {
    return raw.isEmpty ? null : raw.first! as Map<String, Object?>;
  }
  return raw as Map<String, Object?>;
}
