import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/price_text.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../edit/service_editor.dart';
import '../pro_failure_message.dart';
import 'pro_setup_flow.dart';

/// Setup step 2: services from the space's presets, or custom ones. At least
/// one active service is needed to continue.
class ServicesStep extends ConsumerStatefulWidget {
  const ServicesStep({this.incomplete = false, super.key});

  final bool incomplete;

  @override
  ConsumerState<ServicesStep> createState() => _ServicesStepState();
}

class _ServicesStepState extends ConsumerState<ServicesStep> {
  String? _failure;
  bool _busy = false;

  Future<void> _edit({
    ServicePreset? preset,
    ProService? existing,
    required List<ServiceCategory> categories,
  }) async {
    if (_busy) return;
    final result = await showServiceEditor(
      context,
      preset: preset,
      existing: existing,
      categories: categories,
    );
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final ProFailure? failure = switch (result) {
      ServiceSaved(:final draft) => await runPro(
        ref,
        (p) => p.upsertService(draft),
      ),
      ServiceRemoved() => await runPro(
        ref,
        (p) => p.archiveService(existing!.id),
      ),
    };
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure == null
          ? null
          : proFailureMessage(context.l10n, failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final profile = ref.watch(myProProvider).value!;
    final presetsKey = (
      space: profile.space,
      home: profile.kind == ProKind.homeArtist,
    );
    final presetsState = ref.watch(presetsProvider(presetsKey));
    final presets = presetsState.value ?? const <ServicePreset>[];
    final byKey = {for (final p in presets) p.key: p};
    final categories = [
      for (final c in ServiceCategory.values)
        if (presets.isEmpty || presets.any((p) => p.category == c)) c,
    ];
    final services = profile.services;
    final canContinue = services.any((s) => s.active) && !_busy;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );

    return SetupStepScaffold(
      index: 1,
      title: l10n.setupServicesTitle,
      body: l10n.setupServicesBody,
      onBack: () => context.go('/pro/setup/profile'),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!services.any((s) => s.active)) ...[
            Text(
              l10n.setupServicesNeedOne,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          LemqesPrimaryButton(
            key: const Key('setupContinue'),
            label: l10n.actionContinue,
            expand: true,
            onPressed: canContinue
                ? () => context.go('/pro/setup/hours')
                : null,
          ),
        ],
      ),
      children: [
        if (widget.incomplete) ...[
          FailureBanner(message: l10n.setupIncomplete),
          const SizedBox(height: 16),
        ],
        if (_failure != null) ...[
          FailureBanner(message: _failure!),
          const SizedBox(height: 16),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (services.isNotEmpty) ...[
          section(l10n.setupServicesAdded),
          for (final s in services)
            _ServiceRow(
              key: Key('service_${s.id}'),
              name: s.displayName(locale, byKey),
              service: s,
              onTap: () => _edit(
                preset: byKey[s.presetKey],
                existing: s,
                categories: categories,
              ),
            ),
        ],
        section(l10n.setupServicesSuggestions),
        if (presetsState.hasError && presets.isEmpty)
          ErrorView(
            message: l10n.errorGeneric,
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.invalidate(presetsProvider(presetsKey)),
          )
        else if (!presetsState.hasValue)
          LoadingView(label: l10n.loading)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                FilterChip(
                  key: Key('preset_${p.key}'),
                  label: Text(p.name(locale)),
                  selected: services.any((s) => s.presetKey == p.key),
                  onSelected: (_) {
                    final added = services
                        .where((s) => s.presetKey == p.key)
                        .firstOrNull;
                    _edit(preset: p, existing: added, categories: categories);
                  },
                ),
            ],
          ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('addCustomService'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.add),
            label: Text(l10n.setupServicesCustom),
            onPressed: () => _edit(categories: categories),
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    super.key,
    required this.name,
    required this.service,
    required this.onTap,
  });

  final String name;
  final ProService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final price = service.priceDzd;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.bodyLarge),
                      Text(
                        service.active
                            ? l10n.serviceDuration(service.durationMin)
                            : '${l10n.serviceDuration(service.durationMin)} · ${l10n.servicePaused}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (price != null) PriceText(price),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: muted.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
