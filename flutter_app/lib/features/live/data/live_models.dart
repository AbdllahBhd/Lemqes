enum LiveStatus {
  open('open'),
  onBreak('on_break'),
  closed('closed');

  const LiveStatus(this.db);
  final String db;

  static LiveStatus fromDb(String v) => values.firstWhere(
    (e) => e.db == v,
    orElse: () => throw _bad('status', v),
  );
}

enum QueueMode {
  open('open'),
  followers('followers'),
  paused('paused');

  const QueueMode(this.db);
  final String db;

  static QueueMode fromDb(String v) => values.firstWhere(
    (e) => e.db == v,
    orElse: () => throw _bad('queue_mode', v),
  );
}

/// Why a customer cannot join right now; [unknown] covers values a newer
/// server adds (M10 `limited`), so an old client degrades instead of failing.
enum JoinBlock {
  closed('closed'),
  onBreak('on_break'),
  paused('paused'),
  followers('followers'),
  unknown('');

  const JoinBlock(this.db);
  final String db;

  static JoinBlock? fromDb(String? v) {
    if (v == null) return null;
    return values.firstWhere((e) => e.db == v, orElse: () => unknown);
  }
}

enum QueueKind {
  walkIn('walk_in'),
  remote('remote');

  const QueueKind(this.db);
  final String db;

  static QueueKind fromDb(String v) =>
      values.firstWhere((e) => e.db == v, orElse: () => throw _bad('kind', v));
}

enum EntryState {
  waiting,
  serving,
  served,
  absent,
  cancelled,
  removed;

  static EntryState fromDb(String v) => values.firstWhere(
    (e) => e.name == v,
    orElse: () => throw _bad('state', v),
  );
}

enum EndReason {
  cleared('cleared'),
  endOfDay('end_of_day'),
  left('left'),
  blocked('blocked'),
  undo('undo');

  const EndReason(this.db);
  final String db;

  static EndReason? fromDb(String? v) {
    if (v == null) return null;
    return values.firstWhere(
      (e) => e.db == v,
      orElse: () => throw _bad('end_reason', v),
    );
  }
}

FormatException _bad(String field, String v) =>
    FormatException('unknown $field "$v"');

DateTime _ts(Object? v) => DateTime.parse(v! as String).toUtc();
DateTime? _tsOrNull(Object? v) => v == null ? null : _ts(v);

/// One pro's live state exactly as the server sends it (RPC `live` object and
/// broadcast payload; the broadcast's extra `id` and unknown keys are
/// ignored).
class LiveSnapshot {
  const LiveSnapshot({
    required this.proId,
    required this.status,
    required this.breakUntil,
    required this.autoCloseAt,
    required this.statusAgeFrom,
    required this.queueMode,
    required this.joinBlock,
    required this.waitingCount,
    required this.waitMin,
    required this.servingCalledAt,
    required this.servingDurationMin,
    required this.aheadMinutes,
    required this.queueVersion,
    required this.serverNow,
  });

  factory LiveSnapshot.fromJson(Map<String, Object?> j) => LiveSnapshot(
    proId: j['pro_id']! as String,
    status: LiveStatus.fromDb(j['status']! as String),
    breakUntil: _tsOrNull(j['break_until']),
    autoCloseAt: _tsOrNull(j['auto_close_at']),
    statusAgeFrom: _ts(j['status_age_from']),
    queueMode: QueueMode.fromDb(j['queue_mode']! as String),
    joinBlock: JoinBlock.fromDb(j['join_block'] as String?),
    waitingCount: (j['waiting_count'] as num?)?.toInt(),
    waitMin: (j['wait_min'] as num?)?.toInt(),
    servingCalledAt: _tsOrNull(j['serving_called_at']),
    servingDurationMin: (j['serving_duration_min'] as num?)?.toInt(),
    aheadMinutes: (j['ahead_minutes'] as num?)?.toInt() ?? 0,
    queueVersion: (j['queue_version']! as num).toInt(),
    serverNow: _ts(j['server_now']),
  );

  final String proId;
  final LiveStatus status;
  final DateTime? breakUntil;
  final DateTime? autoCloseAt;

  /// Last barber activity, rounded down to 5 min by the server.
  final DateTime statusAgeFrom;
  final QueueMode queueMode;
  final JoinBlock? joinBlock;

  /// Null when the pro hides the count.
  final int? waitingCount;
  final int? waitMin;
  final DateTime? servingCalledAt;
  final int? servingDurationMin;
  final int aheadMinutes;
  final int queueVersion;
  final DateTime serverNow;

  /// True when this snapshot is fresher than [other]: a higher
  /// `queue_version`, or the same version stamped later (status-only changes
  /// do not bump the version).
  bool isNewerThan(LiveSnapshot other) {
    if (queueVersion != other.queueVersion) {
      return queueVersion > other.queueVersion;
    }
    return serverNow.isAfter(other.serverNow);
  }

  @override
  bool operator ==(Object other) =>
      other is LiveSnapshot &&
      proId == other.proId &&
      status == other.status &&
      breakUntil == other.breakUntil &&
      autoCloseAt == other.autoCloseAt &&
      statusAgeFrom == other.statusAgeFrom &&
      queueMode == other.queueMode &&
      joinBlock == other.joinBlock &&
      waitingCount == other.waitingCount &&
      waitMin == other.waitMin &&
      servingCalledAt == other.servingCalledAt &&
      servingDurationMin == other.servingDurationMin &&
      aheadMinutes == other.aheadMinutes &&
      queueVersion == other.queueVersion &&
      serverNow == other.serverNow;

  @override
  int get hashCode => Object.hash(
    proId,
    status,
    breakUntil,
    autoCloseAt,
    statusAgeFrom,
    queueMode,
    joinBlock,
    waitingCount,
    waitMin,
    servingCalledAt,
    servingDurationMin,
    aheadMinutes,
    queueVersion,
    serverNow,
  );
}

/// A line of the owner's queue. Carries no customer id by design.
class OwnerQueueRow {
  const OwnerQueueRow({
    required this.entryId,
    required this.ticketNo,
    required this.kind,
    required this.label,
    required this.serviceId,
    required this.durationMin,
    required this.state,
    required this.onMyWayAt,
    required this.calledAt,
    required this.sortAt,
    required this.position,
  });

  factory OwnerQueueRow.fromJson(Map<String, Object?> j) => OwnerQueueRow(
    entryId: j['entry_id']! as String,
    ticketNo: (j['ticket_no']! as num).toInt(),
    kind: QueueKind.fromDb(j['kind']! as String),
    label: j['label'] as String?,
    serviceId: j['service_id'] as String?,
    durationMin: (j['duration_min'] as num?)?.toInt(),
    state: EntryState.fromDb(j['state']! as String),
    onMyWayAt: _tsOrNull(j['on_my_way_at']),
    calledAt: _tsOrNull(j['called_at']),
    sortAt: _ts(j['sort_at']),
    position: (j['position'] as num?)?.toInt(),
  );

  final String entryId;
  final int ticketNo;
  final QueueKind kind;

  /// Walk-in name or the customer's name; null when there is none (the UI
  /// shows a localized `Client <ticketNo>`).
  final String? label;
  final String? serviceId;
  final int? durationMin;
  final EntryState state;
  final DateTime? onMyWayAt;
  final DateTime? calledAt;
  final DateTime sortAt;
  final int? position;
}

/// The caller's own place in a queue (active, or ended within 30 min).
class MyTicket {
  const MyTicket({
    required this.entryId,
    required this.proId,
    required this.proSpace,
    required this.ticketNo,
    required this.state,
    required this.endReason,
    required this.position,
    required this.waitMin,
    required this.onMyWayAt,
    required this.calledAt,
    required this.endedAt,
    required this.displayName,
    required this.avatarPath,
  });

  factory MyTicket.fromJson(Map<String, Object?> j) => MyTicket(
    entryId: j['entry_id']! as String,
    proId: j['pro_id']! as String,
    proSpace: j['pro_space']! as String,
    ticketNo: (j['ticket_no']! as num).toInt(),
    state: EntryState.fromDb(j['state']! as String),
    endReason: EndReason.fromDb(j['end_reason'] as String?),
    position: (j['position'] as num?)?.toInt(),
    waitMin: (j['wait_min'] as num?)?.toInt(),
    onMyWayAt: _tsOrNull(j['on_my_way_at']),
    calledAt: _tsOrNull(j['called_at']),
    endedAt: _tsOrNull(j['ended_at']),
    displayName: j['display_name']! as String,
    avatarPath: j['avatar_path'] as String?,
  );

  final String entryId;
  final String proId;
  final String proSpace;
  final int ticketNo;
  final EntryState state;
  final EndReason? endReason;
  final int? position;
  final int? waitMin;
  final DateTime? onMyWayAt;
  final DateTime? calledAt;
  final DateTime? endedAt;
  final String displayName;
  final String? avatarPath;
}

class BlockedCustomer {
  const BlockedCustomer({
    required this.blockId,
    required this.ticketLabel,
    required this.createdAt,
  });

  factory BlockedCustomer.fromJson(Map<String, Object?> j) => BlockedCustomer(
    blockId: j['block_id']! as String,
    ticketLabel: j['ticket_label'] as String?,
    createdAt: _ts(j['created_at']),
  );

  final String blockId;
  final String? ticketLabel;
  final DateTime createdAt;
}
