import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../shared/widgets/ltr.dart';
import '../../map/presentation/lemqes_base_map.dart';

/// "Données cartographiques": the credits OSM's attribution guideline asks
/// apps to keep findable, beyond the map's own (i) button.
class MapLicencesScreen extends ConsumerWidget {
  const MapLicencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = ref.watch(mapLinkLauncherProvider);
    final credits = [
      ('osm', 'OpenStreetMap', l10n.mapLicenceOsm, osmCopyrightUrl),
      (
        'openmaptiles',
        'OpenMapTiles',
        l10n.mapLicenceOpenMapTiles,
        openMapTilesUrl,
      ),
      (
        'openfreemap',
        'OpenFreeMap',
        l10n.mapLicenceOpenFreeMap,
        openFreeMapUrl,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(l10n.settingsMapData),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
              child: Text(
                l10n.mapLicencesIntro,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final (id, name, body, url) in credits) ...[
              _CreditCard(
                name: name,
                body: body,
                linkKey: Key('licence_$id'),
                onOpen: () => open(Uri.parse(url)),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.name,
    required this.body,
    required this.linkKey,
    required this.onOpen,
  });

  final String name;
  final String body;
  final Key linkKey;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              // A Latin brand name stays left-to-right inside Arabic.
              child: Ltr(child: Text(name, style: theme.textTheme.titleMedium)),
            ),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            TextButton.icon(
              key: linkKey,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.mapLicenceMore),
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}
