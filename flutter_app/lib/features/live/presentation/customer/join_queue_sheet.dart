import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/price_text.dart';
import '../../data/live_failure.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';
import '../../data/live_repository.dart';
import '../live_failure_listener.dart';

/// One service a customer can join for, already named for the screen.
class JoinService {
  const JoinService({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.priceDzd,
  });

  final String id;
  final String name;
  final int durationMin;

  /// Null when the pro hides prices (`show_prices` off).
  final int? priceDzd;
}

/// One sentence per `join_queue` refusal (the join rules are not callable
/// on their own: the button follows the snapshot's `join_block`). A customer
/// the pro blocked is refused `pro_not_open`, like at any closed pro.
String joinFailureMessage(AppLocalizations l10n, LiveFailure f) => switch (f) {
  NotListable() => l10n.joinErrorNotListable,
  OwnQueue() => l10n.joinErrorOwnQueue,
  ProNotOpen() => l10n.joinErrorNotOpen,
  QueuePaused() => l10n.joinErrorPaused,
  AlreadyInQueue() => l10n.joinErrorAlreadyInQueue,
  JoinLimitReached() => l10n.joinErrorLimit,
  AbsentBlock() => l10n.joinErrorAbsentBlock,
  _ => liveFailureMessage(l10n, f),
};

/// The service picker, then the join. Returns the ticket once joined, null
/// when dismissed. A refusal stays on the sheet, in words.
Future<MyTicket?> showJoinQueueSheet(
  BuildContext context, {
  required String proId,
  required List<JoinService> services,
  required String priceHiddenLabel,
}) => showModalBottomSheet<MyTicket>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => JoinQueueSheet(
    proId: proId,
    services: services,
    priceHiddenLabel: priceHiddenLabel,
  ),
);

class JoinQueueSheet extends ConsumerStatefulWidget {
  const JoinQueueSheet({
    required this.proId,
    required this.services,
    required this.priceHiddenLabel,
    super.key,
  });

  final String proId;
  final List<JoinService> services;

  /// "Prix au salon" (or on request) when a service has no price.
  final String priceHiddenLabel;

  @override
  ConsumerState<JoinQueueSheet> createState() => _JoinQueueSheetState();
}

class _JoinQueueSheetState extends ConsumerState<JoinQueueSheet> {
  late String? _picked = widget.services.length == 1
      ? widget.services.single.id
      : null;
  bool _busy = false;
  LiveFailure? _failure;

  Future<void> _join() async {
    final serviceId = _picked;
    if (serviceId == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final navigator = Navigator.of(context);
    try {
      final ticket = await ref
          .read(liveRepositoryProvider)
          .joinQueue(widget.proId, serviceId);
      // The ticket card and the profile both follow this provider.
      ref.invalidate(myTicketProvider);
      if (mounted) navigator.pop(ticket);
    } on LiveFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failure = _failure;
    return Padding(
      key: const Key('joinSheet'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.liveJoinTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.liveJoinHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<String>(
                groupValue: _picked,
                onChanged: (v) {
                  if (_busy) return;
                  setState(() {
                    _picked = v;
                    _failure = null;
                  });
                },
                child: Column(
                  children: [
                    for (final s in widget.services)
                      _ServiceOption(
                        service: s,
                        selected: s.id == _picked,
                        priceHiddenLabel: widget.priceHiddenLabel,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (failure != null)
            Semantics(
              key: const Key('joinError'),
              liveRegion: true,
              container: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        joinFailureMessage(l10n, failure),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          LemqesPrimaryButton(
            key: const Key('joinConfirm'),
            label: l10n.liveJoinConfirm,
            icon: Icons.how_to_reg_outlined,
            expand: true,
            loading: _busy,
            onPressed: _picked == null ? null : _join,
          ),
        ],
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({
    required this.service,
    required this.selected,
    required this.priceHiddenLabel,
  });

  final JoinService service;
  final bool selected;
  final String priceHiddenLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final price = service.priceDzd;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final radius = BorderRadius.circular(LemqesShape.cardRadius / 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: radius,
        child: RadioListTile<String>(
          key: Key('joinService_${service.id}'),
          value: service.id,
          shape: RoundedRectangleBorder(borderRadius: radius),
          contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 12),
          title: Text(service.name, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            l10n.serviceDuration(service.durationMin),
            style: muted.merge(lemqesNumeric),
          ),
          secondary: price != null
              ? PriceText(price)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    priceHiddenLabel,
                    style: muted,
                    textAlign: TextAlign.end,
                  ),
                ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
