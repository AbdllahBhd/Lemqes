import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/clock_providers.dart';
import '../../account/data/account_providers.dart';
import 'live_channels.dart';
import 'live_derive.dart';
import 'live_failure.dart';
import 'live_models.dart';
import 'live_repository.dart';

// Riverpod 3 retries failing providers by default: on live data that would
// replay actions and hide failures behind a spinner. Screens offer retry.
Duration? _noRetry(int _, Object _) => null;

/// Fires on every app resume. Overridable in tests.
final appResumesProvider = Provider<Stream<void>>((ref) {
  final resumes = StreamController<void>.broadcast();
  final listener = AppLifecycleListener(onResume: () => resumes.add(null));
  ref.onDispose(() {
    listener.dispose();
    unawaited(resumes.close());
  });
  return resumes.stream;
});

/// Re-derives every live view (auto-close, stale, break end, wait) between
/// messages. Overridable in tests.
final liveTickerProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream.periodic(const Duration(seconds: 30), (i) => i),
  retry: _noRetry,
);

/// The realtime socket opening (true) and closing (false), fed by the real
/// channel factory once it has joined a channel.
final liveSocketEventsProvider = Provider<StreamController<bool>>((ref) {
  final events = StreamController<bool>.broadcast();
  ref.onDispose(() => unawaited(events.close()));
  return events;
});

/// Joins a private `pro:<id>` channel. Reads the client only when a channel
/// is joined, so a container that never joins one needs no Supabase. The
/// first join also reports the socket's state to [liveSocketEventsProvider]
/// (realtime_client cannot unregister a callback, so it is added once).
final liveChannelFactoryProvider = Provider<LiveChannelFactory>((ref) {
  var watchingSocket = false;
  return (topic, onBroadcast, onStatus) {
    final client = ref.read(supabaseClientProvider);
    if (!watchingSocket) {
      watchingSocket = true;
      final events = ref.read(liveSocketEventsProvider);
      void report(bool open) {
        if (!events.isClosed) events.add(open);
      }

      client.realtime
        ..onOpen(() => report(true))
        ..onClose((_) => report(false));
    }
    return SupabaseLiveChannel.join(client, topic, onBroadcast, onStatus);
  };
});

/// Whether the last live RPC reached the server: a network failure is half
/// of "Hors ligne", the other half is [LiveChannels.connected].
final liveRpcHealthProvider = NotifierProvider<LiveRpcHealth, bool>(
  LiveRpcHealth.new,
);

class LiveRpcHealth extends Notifier<bool> {
  @override
  bool build() => true;

  void report({required bool ok}) {
    if (state != ok) state = ok;
  }
}

/// Runs a live RPC and records whether it reached the server.
Future<T> _tracked<T>(Ref ref, Future<T> Function() body) async {
  final health = ref.read(liveRpcHealthProvider.notifier);
  try {
    final out = await body();
    health.report(ok: true);
    return out;
  } on LiveNetworkFailure {
    health.report(ok: false);
    rethrow;
  }
}

/// The app's one [LiveChannels]. Every space, role or account change closes
/// all channels (the server authorizes a topic at join only) and re-joins
/// the listeners still there.
final liveChannelsProvider = Provider<LiveChannels>((ref) {
  final channels = LiveChannels(
    channelFactory: ref.watch(liveChannelFactoryProvider),
    fetch: (ids) =>
        _tracked(ref, () => ref.read(liveRepositoryProvider).snapshots(ids)),
    onServerNow: (t) => ref.read(serverOffsetProvider.notifier).observe(t),
  );
  // Signed out, every join would be refused (and the refusal would stick
  // for the next account): nothing joins until an account is there.
  if (ref.read(accountProvider).value?.id == null) {
    channels.closeAll(rejoin: false);
  }
  ref.listen(
    accountProvider.select((a) {
      final v = a.value;
      return (v?.id, v?.currentSpace, v?.activeRole);
    }),
    (previous, next) {
      if (previous == next) return;
      channels.closeAll(rejoin: next.$1 != null);
    },
  );
  final resumes = ref.watch(appResumesProvider).listen((_) {
    channels.refreshAll();
  });
  final socket = ref.watch(liveSocketEventsProvider).stream.listen((open) {
    if (open) {
      channels.socketOpened();
    } else {
      channels.socketClosed();
    }
  });
  ref.onDispose(() {
    unawaited(resumes.cancel());
    unawaited(socket.cancel());
    channels.dispose();
  });
  return channels;
});

/// Raw snapshots of one pro. Errors with [LiveUnavailable] when the server
/// refuses the pro's channel (another space, unpublished).
final liveSnapshotProvider = StreamProvider.autoDispose
    .family<LiveSnapshot, String>(
      (ref, proId) => ref.watch(liveChannelsProvider).watch(proId),
      retry: _noRetry,
    );

/// The owner's view of their own pro: unlike [liveSnapshotProvider], an
/// unpublished pro (`listed: false`) stays visible.
final ownLiveSnapshotProvider = StreamProvider.autoDispose
    .family<LiveSnapshot, String>(
      (ref, proId) => ref.watch(liveChannelsProvider).watch(proId, own: true),
      retry: _noRetry,
    );

/// What a card or screen shows for one pro, re-derived on every tick so a
/// mounted card goes "Fermé" on time without a message.
final proLiveProvider = Provider.autoDispose
    .family<AsyncValue<LiveView>, String>((ref, proId) {
      ref.watch(liveTickerProvider);
      final now = ref.watch(serverNowProvider);
      return ref
          .watch(liveSnapshotProvider(proId))
          .whenData((s) => derive(s, now()));
    }, retry: _noRetry);

/// [proLiveProvider] for the owner's own pro (status card): stays live
/// through an unpublish.
final ownProLiveProvider = Provider.autoDispose
    .family<AsyncValue<LiveView>, String>((ref, proId) {
      ref.watch(liveTickerProvider);
      final now = ref.watch(serverNowProvider);
      return ref
          .watch(ownLiveSnapshotProvider(proId))
          .whenData((s) => derive(s, now()));
    }, retry: _noRetry);

/// "Hors ligne" when false: a channel failing for over 5 s, or the last live
/// RPC hit the network.
final liveConnectedProvider = NotifierProvider<LiveConnected, bool>(
  LiveConnected.new,
);

class LiveConnected extends Notifier<bool> {
  @override
  bool build() {
    final channels = ref.watch(liveChannelsProvider);
    final rpcOk = ref.watch(liveRpcHealthProvider);
    final sub = channels.connectedChanges.listen((c) => state = c && rpcOk);
    ref.onDispose(() => unawaited(sub.cancel()));
    return channels.connected && rpcOk;
  }
}

enum OwnerAction {
  addWalkIn,
  setDetails,
  undoWalkIn,
  callNext,
  finish,
  markAbsent,
  clear,
  block,
}

class OwnerQueue {
  const OwnerQueue({required this.rows, this.inFlight});

  final List<OwnerQueueRow> rows;

  /// The action waiting for the server; others are ignored meanwhile.
  final OwnerAction? inFlight;

  bool get busy => inFlight != null;
}

/// The owner's queue: refetched when the pro's `queue_version` moves (a
/// status-only message does not), replaced by each action's result.
final ownerQueueProvider = AsyncNotifierProvider.autoDispose
    .family<OwnerQueueController, OwnerQueue, String>(
      OwnerQueueController.new,
      retry: _noRetry,
    );

class OwnerQueueController extends AsyncNotifier<OwnerQueue> {
  OwnerQueueController(this.proId);

  final String proId;

  // Kept across rebuilds (the notifier outlives them), so a refetch caused
  // by the action's own broadcast does not re-enable the buttons.
  OwnerAction? _inFlight;

  @override
  Future<OwnerQueue> build() async {
    ref.watch(
      ownLiveSnapshotProvider(proId).select((s) => s.value?.queueVersion),
    );
    final rows = await _tracked(
      ref,
      () => ref.read(liveRepositoryProvider).ownerQueue(proId),
    );
    return OwnerQueue(rows: rows, inFlight: _inFlight);
  }

  Future<void> addWalkIn() =>
      _run(OwnerAction.addWalkIn, (r) => r.addWalkIn(proId));

  Future<void> setDetails(String entryId, {String? name, String? serviceId}) =>
      _run(
        OwnerAction.setDetails,
        (r) => r.setDetails(entryId, name: name, serviceId: serviceId),
      );

  Future<void> undoWalkIn() =>
      _run(OwnerAction.undoWalkIn, (r) => r.undoWalkIn(proId));

  Future<void> callNext() =>
      _run(OwnerAction.callNext, (r) => r.callNext(proId));

  Future<void> finish() => _run(OwnerAction.finish, (r) => r.finish(proId));

  Future<void> markAbsent(String entryId) =>
      _run(OwnerAction.markAbsent, (r) => r.markAbsent(entryId));

  Future<void> clear() => _run(OwnerAction.clear, (r) => r.clear(proId));

  Future<void> block(String entryId) =>
      _run(OwnerAction.block, (r) => r.block(entryId));

  /// Ignored while another action is in flight (a double tap must never
  /// call next twice): the ignored call is a no-op that completes at once.
  /// Failures are rethrown for the screen to show.
  Future<void> _run(
    OwnerAction action,
    Future<List<OwnerQueueRow>> Function(LiveRepository repo) body,
  ) async {
    if (_inFlight != null) return;
    _inFlight = action;
    _publish();
    try {
      final rows = await _tracked(
        ref,
        () => body(ref.read(liveRepositoryProvider)),
      );
      _inFlight = null;
      if (ref.mounted) state = AsyncData(OwnerQueue(rows: rows));
    } finally {
      if (_inFlight == action) {
        _inFlight = null;
        if (ref.mounted) _publish();
      }
    }
  }

  void _publish() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(OwnerQueue(rows: current.rows, inFlight: _inFlight));
  }
}

enum OwnerLiveAction { status, extend, settings }

/// The owner's status and settings writes, one at a time; the new state
/// arrives through the pro's own channel. Tracked for "Hors ligne".
final ownerLiveProvider = NotifierProvider.autoDispose
    .family<OwnerLiveController, OwnerLiveAction?, String>(
      OwnerLiveController.new,
    );

class OwnerLiveController extends Notifier<OwnerLiveAction?> {
  OwnerLiveController(this.proId);

  final String proId;

  @override
  OwnerLiveAction? build() => null;

  Future<void> setStatus(LiveStatus status, {DateTime? breakUntil}) => _run(
    OwnerLiveAction.status,
    (r) => r.setStatus(proId, status, breakUntil: breakUntil),
  );

  Future<void> extendAutoClose() =>
      _run(OwnerLiveAction.extend, (r) => r.extendAutoClose(proId));

  Future<void> setQueueSettings({
    required QueueMode mode,
    required bool hideCount,
  }) => _run(
    OwnerLiveAction.settings,
    (r) => r.setQueueSettings(proId, mode: mode, hideCount: hideCount),
  );

  /// Ignored while another write is in flight; failures are rethrown for
  /// the screen to show.
  Future<void> _run(
    OwnerLiveAction action,
    Future<Object?> Function(LiveRepository repo) body,
  ) async {
    if (state != null) return;
    state = action;
    try {
      await _tracked(ref, () => body(ref.read(liveRepositoryProvider)));
    } finally {
      if (ref.mounted) state = null;
    }
  }
}

/// The customers this pro blocked ("Clients bloqués"); [unblock] replaces
/// the list with the server's answer.
final ownerBlockedProvider = AsyncNotifierProvider.autoDispose
    .family<OwnerBlockedController, List<BlockedCustomer>, String>(
      OwnerBlockedController.new,
      retry: _noRetry,
    );

class OwnerBlockedController extends AsyncNotifier<List<BlockedCustomer>> {
  OwnerBlockedController(this.proId);

  final String proId;
  bool _busy = false;

  @override
  Future<List<BlockedCustomer>> build() =>
      _tracked(ref, () => ref.read(liveRepositoryProvider).blocked(proId));

  /// Ignored while another unblock is in flight; failures are rethrown.
  Future<void> unblock(String blockId) async {
    if (_busy) return;
    _busy = true;
    try {
      final left = await _tracked(
        ref,
        () => ref.read(liveRepositoryProvider).unblock(proId, blockId),
      );
      if (ref.mounted) state = AsyncData(left);
    } finally {
      _busy = false;
    }
  }
}

/// The customer's ticket, only in its own space (null elsewhere, and when
/// there is none). Refetched when its pro's queue moves and on resume.
final myTicketProvider = AsyncNotifierProvider<MyTicketController, MyTicket?>(
  MyTicketController.new,
  retry: _noRetry,
);

class MyTicketController extends AsyncNotifier<MyTicket?> {
  // The pro version the ticket was last refetched for. Kept across rebuilds:
  // the rebuilt listener sees the same snapshot again and must stay quiet.
  ({String proId, int version})? _seen;

  @override
  Future<MyTicket?> build() async {
    final (:id, :space) = ref.watch(
      accountProvider.select(
        (a) => (id: a.value?.id, space: a.value?.currentSpace),
      ),
    );
    if (id == null || space == null) return null;
    final resumes = ref.watch(appResumesProvider).listen((_) {
      ref.invalidateSelf();
    });
    ref.onDispose(() => unawaited(resumes.cancel()));

    final ticket = await _tracked(
      ref,
      () => ref.read(liveRepositoryProvider).myTicket(),
    );
    if (ticket == null || ticket.proSpace != space.toDb()) return null;
    if (ticket.state == EntryState.waiting ||
        ticket.state == EntryState.serving) {
      ref.listen(liveSnapshotProvider(ticket.proId), (_, next) {
        final version = next.value?.queueVersion;
        if (version == null) return;
        final seen = (proId: ticket.proId, version: version);
        if (seen == _seen) return;
        // Also on the first snapshot: the queue may have moved between the
        // ticket fetch and the channel join.
        _seen = seen;
        ref.invalidateSelf();
      });
    }
    return ticket;
  }
}
