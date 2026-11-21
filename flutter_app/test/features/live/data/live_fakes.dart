import 'dart:async';

import 'package:lemqes/features/live/data/live_channels.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_models_test.dart' show snap;

/// One fake private channel: the test drives its status and broadcasts.
class FakeChannel implements LiveChannel {
  FakeChannel(this.topic, this.onBroadcast, this.onStatus);

  final String topic;
  final LiveBroadcastHandler onBroadcast;
  final LiveStatusHandler onStatus;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  void subscribed() => onStatus(RealtimeSubscribeStatus.subscribed, null);

  void error([Object? e]) =>
      onStatus(RealtimeSubscribeStatus.channelError, e ?? Exception('down'));

  void refuse() => onStatus(
    RealtimeSubscribeStatus.channelError,
    Exception(
      'Unauthorized: You do not have permissions to read from this '
      'Channel topic: $topic',
    ),
  );

  /// A broadcast exactly as realtime_client hands it over (spike b).
  void send(Map<String, Object?> live) => onBroadcast({
    'type': 'broadcast',
    'event': 'live',
    'payload': {...live, 'id': 'message-id'},
    'meta': {'id': 'message-id'},
  });
}

class FakeFactory {
  final channels = <FakeChannel>[];

  List<FakeChannel> get open => [
    for (final c in channels)
      if (!c.closed) c,
  ];

  FakeChannel last(String proId) =>
      channels.lastWhere((c) => c.topic == 'pro:$proId');

  LiveChannel call(
    String topic,
    LiveBroadcastHandler onBroadcast,
    LiveStatusHandler onStatus,
  ) {
    final c = FakeChannel(topic, onBroadcast, onStatus);
    channels.add(c);
    return c;
  }
}

/// [version] is `live_version`; `queue_version` follows it unless
/// [queueVersion] is given.
Map<String, Object?> live(
  String proId, {
  int version = 3,
  int? queueVersion,
  String serverNow = '2026-11-20T10:00:00+00:00',
  String status = 'open',
  bool listed = true,
}) => {
  ...snap(version: version, queueVersion: queueVersion, serverNow: serverNow),
  'pro_id': proId,
  'status': status,
  'listed': listed,
};

/// [live] with the count hidden: what the server leaves out (every input
/// that would recount it) is gone, only the rounded wait remains.
Map<String, Object?> hiddenLive(String proId, {int version = 3}) =>
    {...live(proId, version: version), 'count_hidden': true}
      ..remove('waiting_count')
      ..remove('ahead_minutes')
      ..remove('serving_called_at')
      ..remove('serving_duration_min')
      ..remove('queue_version');

LiveSnapshot snapshot(
  String proId, {
  int version = 3,
  int? queueVersion,
  String serverNow = '2026-11-20T10:00:00+00:00',
  String status = 'open',
}) => LiveSnapshot.fromJson(
  live(
    proId,
    version: version,
    queueVersion: queueVersion,
    serverNow: serverNow,
    status: status,
  ),
);

/// Not awaited: inside testWidgets, awaiting a cancel resumes outside the
/// fake-async zone and the next pump never returns.
void stop(StreamSubscription<Object?> s) => unawaited(s.cancel());

extension CopyListed on LiveSnapshot {
  /// The same snapshot with another `listed` value.
  LiveSnapshot copyWithListed(bool listed) => LiveSnapshot.fromJson({
    ...live(proId, version: liveVersion, listed: listed),
    'queue_version': queueVersion,
    'server_now': serverNow.toIso8601String(),
  });
}
