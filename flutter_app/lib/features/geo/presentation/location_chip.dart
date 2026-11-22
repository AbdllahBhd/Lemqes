import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../data/device_location.dart';
import '../data/geo_providers.dart';
import '../data/origin.dart';
import 'locality_picker.dart';
import 'location_explainer_sheet.dart';

enum _Choice { device, commune }

/// Where distances are measured from. It only sets the origin (sort and
/// distances); the place filter beside it stays a filter.
class LocationChip extends ConsumerStatefulWidget {
  const LocationChip({super.key});

  @override
  ConsumerState<LocationChip> createState() => _LocationChipState();
}

class _LocationChipState extends ConsumerState<LocationChip> {
  Future<void> _open() async {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: _sheetShape,
      builder: (_) => const _OriginOptionsSheet(),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _Choice.commune:
        await _pickCommune();
      case _Choice.device:
        await _useDevice();
    }
  }

  Future<void> _useDevice() async {
    // The explainer comes only when the OS has never been asked: after a
    // refusal the prompt cannot return, so the commune picker takes over.
    final status = await ref.read(deviceLocationProvider).permission();
    if (!mounted) return;
    switch (status) {
      case DevicePermission.denied:
      case DevicePermission.deniedForever:
      case DevicePermission.serviceOff:
        return _pickCommune();
      case DevicePermission.notAsked:
        if (!await showLocationExplainerSheet(context) || !mounted) return;
      case DevicePermission.approximate:
      case DevicePermission.precise:
        break;
    }
    final result = await ref.read(originProvider.notifier).useDevice();
    if (!mounted || result.granted) return;
    await _pickCommune();
  }

  Future<void> _pickCommune() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: _sheetShape,
      builder: (_) => const _CommuneSheet(),
    );
    if (id == null || !mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final locality = await ref.read(geoRepositoryProvider).locality(id);
      if (!mounted) return;
      if (locality == null ||
          !ref.read(originProvider.notifier).useCommune(locality)) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.locationNoCentre)));
      }
    } on Exception {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorNetwork)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final origin = ref.watch(originProvider);
    final (icon, label) = switch (origin) {
      NoOrigin() => (Icons.location_searching, l10n.locationChipNone),
      DeviceOrigin() => (Icons.my_location, l10n.locationOptionDevice),
      CommuneOrigin(:final localityId) => (
        Icons.location_on_outlined,
        ref
                .watch(localityProvider(localityId))
                .value
                ?.name(Localizations.localeOf(context)) ??
            l10n.locationChipNone,
      ),
    };
    const radius = BorderRadius.all(Radius.circular(24));
    return Semantics(
      button: true,
      label: label,
      hint: l10n.locationChipHint,
      excludeSemantics: true,
      onTap: _open,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          key: const Key('locationChip'),
          borderRadius: radius,
          onTap: _open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(LemqesShape.sheetRadius),
  ),
);

class _OriginOptionsSheet extends StatelessWidget {
  const _OriginOptionsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                l10n.locationSheetTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            _OptionRow(
              key: const Key('locationOptionDevice'),
              icon: Icons.my_location,
              title: l10n.locationOptionDevice,
              subtitle: l10n.locationOptionDeviceHint,
              onTap: () => Navigator.of(context).pop(_Choice.device),
            ),
            _OptionRow(
              key: const Key('locationOptionCommune'),
              icon: Icons.location_city_outlined,
              title: l10n.locationOptionCommune,
              subtitle: l10n.locationOptionCommuneHint,
              onTap: () => Navigator.of(context).pop(_Choice.commune),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Icon(icon, color: scheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommuneSheet extends StatelessWidget {
  const _CommuneSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              l10n.locationPickerTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          LocalityPicker(
            country: 'DZ',
            onChanged: (_, id) => Navigator.of(context).pop(id),
          ),
        ],
      ),
    );
  }
}
