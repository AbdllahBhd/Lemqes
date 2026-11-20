import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../data/live_failure.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../../data/live_repository.dart';
import '../today/today_widgets.dart' show TodayCard;
import 'join_queue_sheet.dart';
import 'live_status_line.dart';
import 'live_words.dart';
import 'my_ticket_card.dart';

/// The live part of a public profile, under the hero: the status and queue,
/// larger than on a card, then "Rejoindre la file" or the customer's ticket
/// at this pro.
///
/// [LiveBlock.owner] is the owner's preview: read from the owner's own
/// channel (which stays live through an unpublish), with nothing to tap.
class LiveBlock extends ConsumerStatefulWidget {
  const LiveBlock.customer({
    required this.proId,
    required List<JoinService> this.services,
    required String this.priceHiddenLabel,
    super.key,
  }) : owner = false;

  const LiveBlock.owner({required this.proId, super.key})
    : owner = true,
      services = null,
      priceHiddenLabel = null;

  final String proId;
  final bool owner;
  final List<JoinService>? services;
  final String? priceHiddenLabel;

  @override
  ConsumerState<LiveBlock> createState() => _LiveBlockState();
}

class _LiveBlockState extends ConsumerState<LiveBlock> {
  @override
  void initState() {
    super.initState();
    if (!widget.owner) unawaited(_refresh());
  }

  /// A fresh snapshot on open: a pro this device last saw unlisted (and has
  /// since republished) comes back without a new search, since a listed
  /// snapshot clears the refusal.
  Future<void> _refresh() async {
    final proId = widget.proId;
    try {
      final found = await ref.read(liveRepositoryProvider).snapshots([proId]);
      final s = found[proId];
      if (!mounted || s == null) return;
      ref.read(liveChannelsProvider).seed(s);
      if (ref.read(liveSnapshotProvider(proId)).hasError) {
        ref.invalidate(liveSnapshotProvider(proId));
      }
    } on LiveFailure catch (e, st) {
      // The channel's own fetch on join covers a listed pro; the cause
      // goes to the log.
      developer.log('profile live refresh failed', error: e, stackTrace: st);
    }
  }

  Future<void> _join() async {
    await showJoinQueueSheet(
      context,
      proId: widget.proId,
      services: widget.services!,
      priceHiddenLabel: widget.priceHiddenLabel!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    final proId = widget.proId;
    final view = ref
        .watch(owner ? ownProLiveProvider(proId) : proLiveProvider(proId))
        .value;
    if (!owner) listenTicketPlace(ref, context);
    final mine = owner ? null : ref.watch(myTicketProvider).value;
    final ticket = mine?.proId == proId ? mine : null;
    // Loading, or no live line for this caller (unlisted, refused).
    if (view == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final holding =
        ticket != null &&
        (ticket.state == EntryState.waiting ||
            ticket.state == EntryState.serving);
    final services = widget.services ?? const [];
    return TodayCard(
      key: const Key('liveBlock'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiveStatusLine(view: view, large: true),
          const SizedBox(height: 4),
          LiveQueueLine(view: view, large: true),
          if (ticket != null) ...[
            const SizedBox(height: 16),
            TicketView(ticket: ticket, showPro: false),
          ],
          if (!owner && !holding && services.isNotEmpty) ...[
            const SizedBox(height: 16),
            LemqesPrimaryButton(
              key: const Key('liveJoin'),
              label: l10n.liveJoin,
              icon: Icons.group_add_outlined,
              expand: true,
              onPressed: canTryJoin(view) && ref.watch(liveConnectedProvider)
                  ? _join
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
