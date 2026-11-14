import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/lemqes_typography.dart';
import '../../../shared/widgets/ltr.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/geo_providers.dart';
import 'search_fold.dart';

/// One row of a picker sheet: a wilaya (with its code) or a commune.
class _Option {
  const _Option({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.name,
    this.code,
  });

  final Object id;
  final String? code;
  final String nameFr;
  final String nameAr;
  final String name;
}

/// Two fields, wilaya then commune, each opening a searchable sheet.
///
/// Choosing a wilaya opens the commune sheet straight away; [onChanged] fires
/// only once a commune is chosen, so callers never see a half-picked place.
class LocalityPicker extends ConsumerStatefulWidget {
  const LocalityPicker({
    super.key,
    required this.country,
    this.regionCode,
    this.localityId,
    required this.onChanged,
  });

  final String country;
  final String? regionCode;
  final int? localityId;
  final void Function(String regionCode, int localityId) onChanged;

  @override
  ConsumerState<LocalityPicker> createState() => _LocalityPickerState();
}

class _LocalityPickerState extends ConsumerState<LocalityPicker> {
  String? _region;
  int? _locality;

  @override
  void initState() {
    super.initState();
    _region = widget.regionCode;
    _locality = widget.localityId;
  }

  @override
  void didUpdateWidget(LocalityPicker old) {
    super.didUpdateWidget(old);
    if (old.regionCode != widget.regionCode ||
        old.localityId != widget.localityId) {
      _region = widget.regionCode;
      _locality = widget.localityId;
    }
  }

  Future<void> _pickRegion() async {
    final locale = Localizations.localeOf(context);
    final picked = await _showSheet(
      title: context.l10n.localityRegionLabel,
      selectedId: _region,
      options: (ref) => ref
          .watch(regionsProvider(widget.country))
          .whenData(
            (list) => [
              for (final r in list)
                _Option(
                  id: r.code,
                  code: r.code,
                  nameFr: r.nameFr,
                  nameAr: r.nameAr,
                  name: r.name(locale),
                ),
            ],
          ),
      retry: (ref) => ref.invalidate(regionsProvider(widget.country)),
    );
    if (picked == null || !mounted) return;
    final code = picked as String;
    if (code != _region) {
      setState(() {
        _region = code;
        _locality = null;
      });
    }
    await _pickLocality();
  }

  Future<void> _pickLocality() async {
    final region = _region;
    if (region == null) return;
    final locale = Localizations.localeOf(context);
    final key = (country: widget.country, regionCode: region);
    final picked = await _showSheet(
      title: context.l10n.localityCommuneLabel,
      selectedId: _locality,
      options: (ref) => ref
          .watch(localitiesProvider(key))
          .whenData(
            (list) => [
              for (final l in list)
                _Option(
                  id: l.id,
                  nameFr: l.nameFr,
                  nameAr: l.nameAr,
                  name: l.name(locale),
                ),
            ],
          ),
      retry: (ref) => ref.invalidate(localitiesProvider(key)),
    );
    if (picked == null || !mounted) return;
    final id = picked as int;
    setState(() => _locality = id);
    widget.onChanged(region, id);
  }

  Future<Object?> _showSheet({
    required String title,
    required Object? selectedId,
    required AsyncValue<List<_Option>> Function(WidgetRef ref) options,
    required void Function(WidgetRef ref) retry,
  }) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LemqesShape.sheetRadius),
        ),
      ),
      builder: (_) => _PickerSheet(
        title: title,
        selectedId: selectedId,
        options: options,
        retry: retry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final regions = ref.watch(regionsProvider(widget.country)).value;
    final region = _region;
    final regionName = region == null
        ? null
        : regions?.where((r) => r.code == region).firstOrNull?.name(locale);
    final localities = region == null
        ? null
        : ref
              .watch(
                localitiesProvider((
                  country: widget.country,
                  regionCode: region,
                )),
              )
              .value;
    final localityName = localities
        ?.where((l) => l.id == _locality)
        .firstOrNull
        ?.name(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          key: const Key('pickRegion'),
          label: l10n.localityRegionLabel,
          value: regionName,
          hint: l10n.localityRegionHint,
          code: region != null && regionName != null ? region : null,
          onTap: _pickRegion,
        ),
        const SizedBox(height: 12),
        _Field(
          key: const Key('pickLocality'),
          label: l10n.localityCommuneLabel,
          value: localityName,
          hint: region == null
              ? l10n.localityCommuneDisabled
              : l10n.localityCommuneHint,
          onTap: region == null ? null : _pickLocality,
          enabled: region != null,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.code,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String hint;
  final String? code;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = this.value;
    final inkColor = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: value ?? hint,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (value == null)
                          Text(
                            hint,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Row(
                            children: [
                              if (code != null) ...[
                                _Code(code!),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  value,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: inkColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Ltr(
      child: Text(
        code,
        style: lemqesWeight(
          Theme.of(context).textTheme.bodyLarge!
              .merge(lemqesNumeric)
              .copyWith(color: scheme.onSurfaceVariant),
          FontWeight.w600,
        ),
      ),
    );
  }
}

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.selectedId,
    required this.options,
    required this.retry,
  });

  final String title;
  final Object? selectedId;
  final AsyncValue<List<_Option>> Function(WidgetRef ref) options;
  final void Function(WidgetRef ref) retry;

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _failure(AppLocalizations l10n) => ErrorView(
    message: l10n.errorGeneric,
    retryLabel: l10n.actionRetry,
    onRetry: () => widget.retry(ref),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final options = widget.options(ref);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                header: true,
                child: Text(widget.title, style: theme.textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('pickerSearch'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.localitySearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: options.when(
                loading: () => LoadingView(label: l10n.loading),
                error: (_, _) => _failure(l10n),
                data: (all) {
                  final shown = [
                    for (final o in all)
                      if (matchesPlace(
                        _search.text,
                        nameFr: o.nameFr,
                        nameAr: o.nameAr,
                        code: o.code,
                      ))
                        o,
                  ];
                  if (shown.isEmpty) {
                    return EmptyView(
                      icon: Icons.search_off,
                      title: l10n.localityEmptyTitle,
                      body: l10n.localityEmptyBody,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final o = shown[i];
                      return _OptionRow(
                        option: o,
                        selected: o.id == widget.selectedId,
                        onTap: () => Navigator.of(context).pop(o.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Option option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = option.code;
    return Semantics(
      key: Key('option_${option.id}'),
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (code != null) ...[
                      SizedBox(width: 32, child: _Code(code)),
                      Text('·', style: theme.textTheme.bodyLarge),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        option.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check, color: scheme.onSecondaryContainer),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
