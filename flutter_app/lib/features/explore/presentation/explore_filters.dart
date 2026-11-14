import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../account/data/account.dart';
import '../../geo/data/geo_providers.dart';
import '../../geo/presentation/locality_picker.dart';
import '../../pro/data/pro_models.dart';
import '../../pro/data/pro_providers.dart';
import '../data/explore_providers.dart';

/// Service categories offered in [space]: those its presets (salon and home)
/// use, in catalogue order. Empty until the presets have loaded.
List<ServiceCategory> exploreCategories(WidgetRef ref, Space space) {
  final used = {
    for (final home in [false, true])
      ...?ref
          .watch(presetsProvider((space: space, home: home)))
          .value
          ?.map((p) => p.category),
  };
  return [
    for (final c in ServiceCategory.values)
      if (used.contains(c)) c,
  ];
}

/// The search field that straddles the home band's lower edge.
class ExploreSearchField extends StatelessWidget {
  const ExploreSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: LemqesShape.cardShadow,
        ),
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            key: const Key('exploreSearch'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.exploreSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('exploreSearchClear'),
                      tooltip: l10n.exploreSearchClear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: border(scheme.outlineVariant),
              enabledBorder: border(scheme.outlineVariant),
              focusedBorder: border(scheme.primary, 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Place, kids and category chips in one horizontally scrolling row.
class ExploreFilters extends ConsumerWidget {
  const ExploreFilters({required this.space, super.key});

  final Space space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(exploreQueryProvider);
    final controller = ref.read(exploreQueryProvider.notifier);
    final locale = Localizations.localeOf(context);
    final localityId = query.localityId;
    final placeName = localityId == null
        ? null
        : ref.watch(localityProvider(localityId)).value?.name(locale);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          FilterChip(
            key: const Key('filterPlace'),
            showCheckmark: false,
            avatar: const Icon(Icons.place_outlined),
            label: Text(placeName ?? l10n.explorePlaceAny),
            selected: localityId != null,
            onSelected: (_) => _pickPlace(context, ref),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('filterKids'),
            label: Text(l10n.exploreKids),
            selected: query.kidsOnly,
            onSelected: controller.setKidsOnly,
          ),
          for (final c in exploreCategories(ref, space)) ...[
            const SizedBox(width: 8),
            FilterChip(
              key: Key('filterCategory_${c.toDb()}'),
              label: Text(l10n.serviceCategoryName(c.toDb())),
              selected: query.category == c,
              onSelected: (on) => controller.setCategory(on ? c : null),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickPlace(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LemqesShape.sheetRadius),
          ),
        ),
        builder: (_) => const _PlaceSheet(),
      );
}

class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final query = ref.watch(exploreQueryProvider);
    final controller = ref.read(exploreQueryProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.explorePlaceTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          LocalityPicker(
            country: 'DZ',
            regionCode: query.regionCode,
            localityId: query.localityId,
            onChanged: (region, locality) {
              controller
                ..setRegion(region)
                ..setLocality(locality);
              Navigator.of(context).pop();
            },
          ),
          if (query.regionCode != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('placeClear'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.public),
                label: Text(l10n.explorePlaceClear),
                onPressed: () {
                  controller.setRegion(null);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
