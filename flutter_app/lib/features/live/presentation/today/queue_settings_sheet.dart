import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../live_failure_listener.dart';

/// Queue settings: who can join remotely, hide the count, blocked
/// customers.
Future<void> showQueueSettingsSheet(BuildContext context, String proId) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LemqesShape.sheetRadius),
        ),
      ),
      builder: (_) => QueueSettingsSheet(proId: proId),
    );

class QueueSettingsSheet extends ConsumerWidget {
  const QueueSettingsSheet({required this.proId, super.key});

  final String proId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final snapshot = ref.watch(ownProLiveProvider(proId)).value?.snapshot;
    final writing = ref.watch(ownerLiveProvider(proId)) != null;
    final enabled =
        snapshot != null && !writing && ref.watch(liveConnectedProvider);
    final mode = snapshot?.queueMode ?? QueueMode.open;
    final hidden = snapshot != null && snapshot.countHidden;

    void save({required QueueMode mode, required bool hideCount}) {
      final owner = ref.read(ownerLiveProvider(proId).notifier);
      runLive(
        ref,
        () => owner.setQueueSettings(mode: mode, hideCount: hideCount),
      );
    }

    final hints = {
      QueueMode.open: (l10n.queueModeOpen, l10n.queueModeOpenHint),
      QueueMode.followers: (
        l10n.queueModeFollowers,
        l10n.queueModeFollowersHint,
      ),
      QueueMode.paused: (l10n.queueModePaused, l10n.queueModePausedHint),
    };

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            header: true,
            child: Text(l10n.todaySettings, style: theme.textTheme.titleLarge),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(l10n.queueModeTitle),
        RadioGroup<QueueMode>(
          groupValue: mode,
          onChanged: (m) {
            if (m == null || m == mode || !enabled) return;
            save(mode: m, hideCount: hidden);
          },
          child: Column(
            children: [
              for (final m in QueueMode.values)
                RadioListTile<QueueMode>(
                  key: Key('mode_${m.db}'),
                  value: m,
                  enabled: enabled,
                  title: Text(hints[m]!.$1),
                  subtitle: Text(hints[m]!.$2),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        SwitchListTile(
          key: const Key('hideCount'),
          value: hidden,
          title: Text(l10n.queueHideCount),
          subtitle: Text(l10n.queueHideCountHint),
          onChanged: enabled ? (v) => save(mode: mode, hideCount: v) : null,
        ),
        const Divider(height: 24),
        _SectionTitle(l10n.queueBlockedTitle),
        _BlockedList(proId: proId, enabled: enabled, muted: muted),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _BlockedList extends ConsumerWidget {
  const _BlockedList({
    required this.proId,
    required this.enabled,
    required this.muted,
  });

  final String proId;
  final bool enabled;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(ownerBlockedProvider(proId));
    final blocked = state.value;
    if (blocked == null) {
      if (state.hasError) {
        return ListTile(
          title: Text(l10n.errorGeneric),
          trailing: TextButton(
            onPressed: () => ref.invalidate(ownerBlockedProvider(proId)),
            child: Text(l10n.actionRetry),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (blocked.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          l10n.queueBlockedEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      );
    }
    return Column(
      children: [
        for (final b in blocked)
          ListTile(
            minTileHeight: 56,
            leading: Icon(Icons.block, color: muted),
            title: Text(b.ticketLabel ?? l10n.queueBlockedUnnamed),
            trailing: TextButton(
              key: Key('unblock_${b.blockId}'),
              onPressed: enabled
                  ? () {
                      final blocks = ref.read(
                        ownerBlockedProvider(proId).notifier,
                      );
                      runLive(ref, () => blocks.unblock(b.blockId));
                    }
                  : null,
              child: Text(l10n.queueUnblock),
            ),
          ),
      ],
    );
  }
}
