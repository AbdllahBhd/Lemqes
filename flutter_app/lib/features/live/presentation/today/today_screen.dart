import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../core/time/clock_providers.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../account/data/account.dart';
import '../../../home/presentation/home_header.dart';
import '../../../pro/data/pro_models.dart';
import '../../../pro/data/pro_providers.dart';
import '../../../pro/presentation/pro_failure_message.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../live_failure_listener.dart';
import 'queue_card.dart';
import 'queue_list.dart';
import 'queue_settings_sheet.dart';
import 'status_controls.dart';
import 'today_widgets.dart';

/// "Aujourd'hui": the barber's live status and queue.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ProKind.forRole(account.activeRole);
    final state = ref.watch(myProProvider);
    final value = state.value;
    // After a role switch the value is the previous role's profile until the
    // reload lands; it must never show as this role's.
    final stale = value != null && value.kind != kind;
    final profile = stale ? null : value;

    if (kind != null && profile != null) {
      return LiveFailureListener(
        child: Scaffold(body: _TodayBody(profile: profile)),
      );
    }

    final Widget body;
    if (kind == null) {
      // Salon owners get their own space with salons (M7).
      body = EmptyView(
        icon: Icons.storefront_outlined,
        title: l10n.dashboardSalonTitle,
        body: l10n.dashboardSalonBody,
      );
    } else if (!state.hasValue || stale || state.isLoading) {
      body = state.hasError && !state.isLoading
          ? ErrorView(
              message: proFailureMessage(l10n, state.error),
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(myProProvider),
            )
          : LoadingView(label: l10n.loading);
    } else {
      body = EmptyView(
        icon: Icons.badge_outlined,
        title: l10n.homeProEmptyTitle,
        body: l10n.dashboardNoProfileBody,
        action: LemqesPrimaryButton(
          key: const Key('todayComplete'),
          label: l10n.dashboardComplete,
          onPressed: () => context.go('/pro/setup'),
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          _Header(name: account.displayName, status: null),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.status});

  final String name;

  /// The band's status control; null shows the name alone.
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = this.status;
    return HomeHeader(
      extraRows: status == null ? 0 : 1,
      title: Semantics(
        header: true,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: lemqesWeight(
            theme.textTheme.headlineSmall!,
            FontWeight.w600,
          ).copyWith(color: Colors.white),
        ),
      ),
      children: [?status],
    );
  }
}

class _TodayBody extends ConsumerStatefulWidget {
  const _TodayBody({required this.profile});

  final ProProfile profile;

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  String get _proId => widget.profile.id;

  // From the last build: callbacks must not watch.
  Map<String, String> _names = const {};

  OwnerQueueController get _queue =>
      ref.read(ownerQueueProvider(_proId).notifier);

  OwnerLiveController get _owner =>
      ref.read(ownerLiveProvider(_proId).notifier);

  List<OwnerQueueRow> _waiting(List<OwnerQueueRow> rows) => [
    for (final r in rows)
      if (r.state == EntryState.waiting) r,
  ]..sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

  /// A break always opens the return-time sheet (also to change it);
  /// closing with customers waiting asks first.
  ///
  /// While the status reads "Statut incertain" ([stale]), the current one
  /// is sent again: the write is the barber's activity that clears it.
  Future<void> _selectStatus(
    LiveStatus chosen,
    LiveStatus current,
    int waiting, {
    required bool stale,
  }) async {
    final l10n = context.l10n;
    if (chosen == LiveStatus.onBreak) {
      final choice = await showBreakSheet(context);
      if (choice == null || !mounted) return;
      final minutes = choice.minutes;
      final until = minutes == null
          ? null
          : ref.read(serverNowProvider)().add(Duration(minutes: minutes));
      final owner = _owner;
      await runLive(
        ref,
        () => owner.setStatus(LiveStatus.onBreak, breakUntil: until),
      );
      return;
    }
    if (chosen == current && !stale) return;
    if (chosen == LiveStatus.closed && waiting > 0) {
      final ok = await confirmLive(
        context,
        title: l10n.todayCloseTitle,
        body: l10n.todayCloseBody(waiting),
        confirm: l10n.todayCloseConfirm,
        destructive: false,
      );
      if (!ok || !mounted) return;
    }
    final owner = _owner;
    await runLive(ref, () => owner.setStatus(chosen));
  }

  Future<void> _openEntry(OwnerQueueRow row) async {
    final l10n = context.l10n;
    final services = [
      for (final s in widget.profile.services)
        if (s.active) (id: s.id, name: _names[s.id]!),
    ];
    final action = await showQueueEntrySheet(
      context,
      row: row,
      services: services,
    );
    if (action == null || !mounted) return;
    final queue = _queue;
    switch (action) {
      case EntrySave(:final name, :final serviceId):
        await runLive(
          ref,
          () => queue.setDetails(row.entryId, name: name, serviceId: serviceId),
        );
      case EntryAbsent():
        final ok = await confirmLive(
          context,
          title: l10n.todayAbsentTitle,
          body: l10n.todayAbsentBody,
          confirm: l10n.todayAbsent,
        );
        if (ok && mounted) {
          await runLive(ref, () => queue.markAbsent(row.entryId));
        }
      case EntryBlock():
        final ok = await confirmLive(
          context,
          title: l10n.todayBlockTitle,
          body: l10n.todayBlockBody,
          confirm: l10n.todayBlock,
        );
        if (ok && mounted) {
          await runLive(ref, () => queue.block(row.entryId));
        }
    }
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final ok = await confirmLive(
      context,
      title: l10n.todayClearTitle,
      body: l10n.todayClearBody,
      confirm: l10n.todayClearConfirm,
    );
    if (!ok || !mounted) return;
    final queue = _queue;
    await runLive(ref, queue.clear);
  }

  /// Service names by id: a custom name, else the preset's in this locale,
  /// else (until the presets load) the category.
  Map<String, String> _serviceNames() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final profile = widget.profile;
    final presets =
        ref
            .watch(
              presetsProvider((
                space: profile.space,
                home: profile.kind == ProKind.homeArtist,
              )),
            )
            .value ??
        const <ServicePreset>[];
    final byKey = {for (final p in presets) p.key: p};
    return {
      for (final s in profile.services)
        s.id:
            s.customName ??
            byKey[s.presetKey]?.name(locale) ??
            l10n.serviceCategoryName(s.category.toDb()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = widget.profile;
    final live = ref.watch(ownProLiveProvider(_proId));
    final queueState = ref.watch(ownerQueueProvider(_proId));
    final connected = ref.watch(liveConnectedProvider);
    final writing = ref.watch(ownerLiveProvider(_proId)) != null;
    final view = live.value;
    final queue = queueState.value;
    final rows = queue?.rows ?? const <OwnerQueueRow>[];
    final waiting = _waiting(rows);
    OwnerQueueRow? serving;
    for (final r in rows) {
      if (r.state == EntryState.serving) serving = r;
    }
    final names = _names = _serviceNames();
    final inFlight = queue?.inFlight;
    // One queue action at a time: while one is in flight every control
    // waits (the controller would drop the tap), the one running shows it.
    final canAct = connected && queue != null && inFlight == null;

    void act(Future<void> Function(OwnerQueueController q) body) {
      final q = _queue;
      runLive(ref, () => body(q));
    }

    final statusControl = StatusSwitch(
      value: view?.status,
      onSelected: connected && view != null && !writing
          ? (s) =>
                _selectStatus(s, view.status, waiting.length, stale: view.stale)
          : null,
    );

    final Widget content;
    if (view == null) {
      content = live.hasError
          ? ErrorView(
              message: l10n.errorGeneric,
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(ownLiveSnapshotProvider(_proId)),
            )
          : LoadingView(label: l10n.loading);
    } else {
      final undoable = waiting.any((r) => r.kind == QueueKind.walkIn);
      content = ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          StatusDetails(
            view: view,
            onExtend: connected && !writing
                ? () {
                    final owner = _owner;
                    runLive(ref, owner.extendAutoClose);
                  }
                : null,
          ),
          if (view.status != LiveStatus.closed || view.stale)
            const SizedBox(height: 16),
          QueueCountCard(
            waiting: waiting.length,
            waitMin: view.waitMin,
            onAdd: canAct ? () => act((q) => q.addWalkIn()) : null,
            onUndo: canAct && undoable
                ? () => act((q) => q.undoWalkIn())
                : null,
            adding: inFlight == OwnerAction.addWalkIn,
            undoing: inFlight == OwnerAction.undoWalkIn,
          ),
          if (serving != null) ...[
            const SizedBox(height: 16),
            ServingCard(
              row: serving,
              service: names[serving.serviceId],
              finishing: inFlight == OwnerAction.finish,
              onFinish: canAct ? () => act((q) => q.finish()) : null,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.todayQueueTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const Key('queueSettings'),
                tooltip: l10n.todaySettings,
                icon: const Icon(Icons.tune),
                onPressed: () => showQueueSettingsSheet(context, _proId),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (queue == null)
            queueState.hasError
                ? TodayCard(
                    child: Row(
                      children: [
                        Expanded(child: Text(l10n.errorGeneric)),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(ownerQueueProvider(_proId)),
                          child: Text(l10n.actionRetry),
                        ),
                      ],
                    ),
                  )
                : const LinearProgressIndicator()
          else if (waiting.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.todayQueueEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            QueueList(
              rows: waiting,
              serviceNames: names,
              onTap: canAct ? _openEntry : null,
            ),
          if (waiting.isNotEmpty) ...[
            const SizedBox(height: 32),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('queueClear'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: canAct ? _clear : null,
                icon: inFlight == OwnerAction.clear
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_remove),
                label: Text(l10n.todayClear),
              ),
            ),
          ],
        ],
      );
    }

    final unpublished =
        !profile.isPublished || (view != null && !view.snapshot.listed);
    return Column(
      children: [
        _Header(name: profile.displayName, status: statusControl),
        if (!connected)
          TodayBanner(
            key: const Key('offlineBanner'),
            icon: Icons.cloud_off_outlined,
            message: l10n.todayOffline,
            error: true,
            action: TextButton(
              onPressed: () {
                // The channels too: a failing one rejoins now, every
                // watched pro is fetched again (the status card's included).
                ref.read(liveRetryProvider)();
                ref.invalidate(ownerQueueProvider(_proId));
              },
              child: Text(l10n.actionRetry),
            ),
          ),
        if (unpublished)
          TodayBanner(
            key: const Key('unpublishedBanner'),
            icon: Icons.visibility_off_outlined,
            message: l10n.todayUnpublished,
          ),
        Expanded(child: content),
        if (view != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: LemqesPrimaryButton(
                key: const Key('callNext'),
                label: l10n.todayCallNext,
                icon: Icons.campaign_outlined,
                expand: true,
                loading: inFlight == OwnerAction.callNext,
                // The server refuses with nobody waiting, even while
                // someone is in the chair.
                onPressed: canAct && waiting.isNotEmpty
                    ? () => act((q) => q.callNext())
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
