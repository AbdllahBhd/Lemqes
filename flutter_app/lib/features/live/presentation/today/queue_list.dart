import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../explore/presentation/pro_labels.dart' show MistTag;
import '../../data/live_models.dart';
import 'queue_card.dart';
import 'today_widgets.dart';

/// The waiting entries in order: position, name or "Client N", service,
/// walk-in or remote, and "En route".
class QueueList extends StatelessWidget {
  const QueueList({
    required this.rows,
    required this.serviceNames,
    required this.onTap,
    super.key,
  });

  final List<OwnerQueueRow> rows;
  final Map<String, String> serviceNames;

  /// Null makes the rows read-only (offline).
  final ValueChanged<OwnerQueueRow>? onTap;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).colorScheme.outlineVariant;
    final onTap = this.onTap;
    return TodayCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: divider),
            _QueueRow(
              key: Key('queueRow_${row.entryId}'),
              row: row,
              position: row.position ?? i + 1,
              service: serviceNames[row.serviceId],
              onTap: onTap == null ? null : () => onTap(row),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.row,
    required this.position,
    required this.service,
    required this.onTap,
    super.key,
  });

  final OwnerQueueRow row;
  final int position;
  final String? service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final remote = row.kind == QueueKind.remote;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                // Grows with the text size rather than clipping the number.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Ltr(
                        child: Text(
                          '$position',
                          style: lemqesWeight(
                            theme.textTheme.titleSmall!.merge(lemqesNumeric),
                            FontWeight.w600,
                          ).copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entryLabel(context, row),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(service ?? l10n.todayNoService, style: muted),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              remote
                                  ? Icons.smartphone_outlined
                                  : Icons.storefront_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              remote
                                  ? l10n.todayKindRemote
                                  : l10n.todayKindWalkIn,
                              style: muted,
                            ),
                          ],
                        ),
                        if (row.onMyWayAt != null) MistTag(l10n.todayOnTheWay),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the barber chose in an entry's sheet.
sealed class EntryAction {
  const EntryAction();
}

class EntrySave extends EntryAction {
  const EntrySave({required this.name, required this.serviceId});

  final String? name;
  final String? serviceId;
}

class EntryAbsent extends EntryAction {
  const EntryAbsent();
}

class EntryBlock extends EntryAction {
  const EntryBlock();
}

/// An entry's sheet: its service (and a walk-in's optional name), plus
/// "Bloquer" for remote entries, and "Absent" once one is called (only the
/// called customer can be missing).
Future<EntryAction?> showQueueEntrySheet(
  BuildContext context, {
  required OwnerQueueRow row,
  required List<({String id, String name})> services,
}) => showModalBottomSheet<EntryAction>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(LemqesShape.sheetRadius),
    ),
  ),
  builder: (_) => _EntrySheet(row: row, services: services),
);

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.row, required this.services});

  final OwnerQueueRow row;
  final List<({String id, String name})> services;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.row.label ?? '',
  );
  late String? _serviceId = widget.row.serviceId;

  bool get _walkIn => widget.row.kind == QueueKind.walkIn;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    Navigator.of(context).pop(
      EntrySave(
        name: _walkIn && name.isNotEmpty ? name : null,
        serviceId: _serviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                entryLabel(context, widget.row),
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              _walkIn ? l10n.todayKindWalkIn : l10n.todayKindRemote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_walkIn) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('entryName'),
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.todayEntryName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
            ],
            if (widget.services.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.todayEntryService, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in widget.services)
                    ChoiceChip(
                      key: Key('entryService_${s.id}'),
                      label: Text(s.name),
                      selected: _serviceId == s.id,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (on) =>
                          setState(() => _serviceId = on ? s.id : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            LemqesPrimaryButton(
              key: const Key('entrySave'),
              label: l10n.dashboardSave,
              expand: true,
              onPressed: _save,
            ),
            if (!_walkIn) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (widget.row.state == EntryState.serving)
                    TextButton.icon(
                      key: const Key('entryAbsent'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(const EntryAbsent()),
                      icon: const Icon(Icons.person_off_outlined),
                      label: Text(l10n.todayAbsent),
                    ),
                  TextButton.icon(
                    key: const Key('entryBlock'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(const EntryBlock()),
                    icon: const Icon(Icons.block),
                    label: Text(l10n.todayBlock),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
