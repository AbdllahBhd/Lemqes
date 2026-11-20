import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../data/live_failure.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../../data/live_repository.dart';
import '../live_failure_listener.dart';
import '../today/today_widgets.dart' show TodayCard, confirmLive;
import 'live_words.dart';

bool _active(MyTicket t) =>
    t.state == EntryState.waiting || t.state == EntryState.serving;

/// "3e", "1re" (women's space), "#3", "3": the short place, for the badge.
String ticketPlaceText(AppLocalizations l10n, MyTicket t) =>
    l10n.ticketPlace(t.position ?? 0, t.proSpace);

/// The ticket's headline: place and wait, the turn, or how it ended.
String ticketHeadline(AppLocalizations l10n, MyTicket t) {
  switch (t.state) {
    case EntryState.waiting:
      final place = ticketPlaceText(l10n, t);
      final wait = liveWaitText(l10n, t.waitMin);
      return wait == null
          ? l10n.ticketYouAre(place)
          : l10n.ticketYouAreWait(place, wait);
    case EntryState.serving:
      return l10n.ticketYourTurn;
    case EntryState.served:
      return l10n.ticketServed;
    case EntryState.absent:
      return l10n.ticketAbsent;
    case EntryState.cancelled || EntryState.removed:
      return switch (t.endReason) {
        EndReason.cleared ||
        EndReason.endOfDay => l10n.ticketCleared(t.proSpace),
        EndReason.left => l10n.ticketLeft,
        // Blocked or undone: neutral, never reveals a block.
        _ => l10n.ticketEnded,
      };
  }
}

/// The last place said to screen readers, per entry. Plain memory, not
/// state: both the Explore card and the profile listen, and only the first
/// to see a change may say it.
class TicketPlaceMemory {
  ({String entryId, EntryState state, int? position})? _last;

  /// What to say for [t]: its new place while waiting, or the turn when
  /// waiting gave way to serving; null when nothing changed for the same
  /// entry (the first sighting is never news).
  String? news(AppLocalizations l10n, MyTicket t) {
    final last = _last;
    _last = (entryId: t.entryId, state: t.state, position: t.position);
    if (last == null || last.entryId != t.entryId) return null;
    if (t.state == EntryState.serving && last.state == EntryState.waiting) {
      return l10n.ticketYourTurn;
    }
    if (t.state == EntryState.waiting &&
        t.position != null &&
        t.position != last.position) {
      return l10n.ticketYouAre(ticketPlaceText(l10n, t));
    }
    return null;
  }
}

final ticketPlaceMemoryProvider = Provider<TicketPlaceMemory>(
  (_) => TicketPlaceMemory(),
);

/// Says "Vous êtes 2e" when the customer's place changes and "C'est votre
/// tour" when it comes (G5), never on a rebuild with nothing new. Call from
/// a build method.
void listenTicketPlace(WidgetRef ref, BuildContext context) {
  final memory = ref.read(ticketPlaceMemoryProvider);
  final l10n = context.l10n;
  // What is on screen when this widget builds is known, not news.
  if (ref.read(myTicketProvider).value case final current?) {
    memory.news(l10n, current);
  }
  ref.listen(myTicketProvider.select((s) => s.value), (_, next) {
    if (next == null) return;
    final message = memory.news(context.l10n, next);
    if (message == null) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  });
}

/// The customer's place in a pro's queue: the gold place badge, the wait,
/// "Je suis en route" and "Quitter la file" while waiting; the turn while
/// served; how it ended for 30 min after.
class TicketView extends ConsumerStatefulWidget {
  const TicketView({required this.ticket, this.showPro = true, super.key});

  final MyTicket ticket;

  /// Names the pro (on Explore); the profile already does.
  final bool showPro;

  @override
  ConsumerState<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends ConsumerState<TicketView> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(LiveRepository repo) body) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await body(ref.read(liveRepositoryProvider));
    } on LiveFailure catch (f) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              f is EntryNotActive
                  ? l10n.ticketEnded
                  : liveFailureMessage(l10n, f),
            ),
          ),
        );
    } finally {
      // The server's answer is the truth either way.
      ref.invalidate(myTicketProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final l10n = context.l10n;
    final ok = await confirmLive(
      context,
      title: l10n.ticketLeaveTitle,
      body: l10n.ticketLeaveBody,
      confirm: l10n.ticketLeaveConfirm,
    );
    if (!ok || !mounted) return;
    await _run((r) => r.leaveQueue(widget.ticket.entryId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = widget.ticket;
    final waiting = t.state == EntryState.waiting;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              _Badge(ticket: t),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticketHeadline(l10n, t),
                      key: const Key('ticketHeadline'),
                      style: lemqesWeight(
                        theme.textTheme.titleMedium!.merge(lemqesNumeric),
                        FontWeight.w600,
                      ),
                    ),
                    if (widget.showPro)
                      Text(l10n.ticketAt(isolate(t.displayName)), style: muted),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (waiting) ...[
          const SizedBox(height: 12),
          if (t.onMyWayAt == null)
            LemqesPrimaryButton(
              key: const Key('ticketOnMyWay'),
              label: l10n.ticketOnMyWay,
              icon: Icons.directions_walk,
              expand: true,
              loading: _busy,
              onPressed: () => _run((r) => r.onMyWay(t.entryId)),
            )
          else
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: muted.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.ticketOnMyWayDone(t.proSpace),
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('ticketLeave'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: scheme.error,
              ),
              onPressed: _busy ? null : _leave,
              icon: const Icon(Icons.logout),
              label: Text(l10n.ticketLeave),
            ),
          ),
        ],
      ],
    );
  }
}

/// Gold is spent on "you": the badge holds your place, or your turn. An
/// ended ticket is no longer yours, so it goes neutral.
class _Badge extends StatelessWidget {
  const _Badge({required this.ticket});

  final MyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = ticket;
    final mine = _active(t);
    final background = mine ? LemqesColors.gold : scheme.surfaceContainerHigh;
    final ink = mine ? LemqesColors.ink : scheme.onSurfaceVariant;
    final Widget content = switch (t.state) {
      EntryState.waiting => Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            ticketPlaceText(context.l10n, t),
            key: const Key('ticketBadge'),
            style: lemqesWeight(
              theme.textTheme.titleMedium!
                  .merge(lemqesNumeric)
                  .copyWith(fontFamily: 'Alexandria', color: ink),
              FontWeight.w600,
            ),
          ),
        ),
      ),
      EntryState.serving => Icon(Icons.content_cut, color: ink, size: 22),
      EntryState.served => Icon(Icons.check, color: ink, size: 22),
      EntryState.absent => Icon(Icons.person_off_outlined, color: ink),
      EntryState.cancelled || EntryState.removed => Icon(
        t.endReason == EndReason.left ? Icons.logout : Icons.info_outline,
        color: ink,
        size: 22,
      ),
    };
    // The headline says the same in words.
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: content,
      ),
    );
  }
}

/// "Votre file" at the top of Explore while the customer holds a place, or
/// for 30 min after it ended. Only in the ticket's space: the provider
/// drops a ticket from the other one.
class ExploreTicketCard extends ConsumerWidget {
  const ExploreTicketCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenTicketPlace(ref, context);
    final ticket = ref.watch(myTicketProvider).value;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topCenter,
      child: ticket == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ExploreTicket(ticket: ticket),
            ),
    );
  }
}

class _ExploreTicket extends StatelessWidget {
  const _ExploreTicket({required this.ticket});

  final MyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return TodayCard(
      key: const Key('ticketCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.ticketTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('ticketOpenPro'),
                tooltip: l10n.ticketOpenPro,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => context.push('/pro/${ticket.proId}'),
              ),
            ],
          ),
          TicketView(ticket: ticket),
        ],
      ),
    );
  }
}
