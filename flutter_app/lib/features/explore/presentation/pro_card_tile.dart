import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/lemqes_typography.dart';
import '../../../shared/widgets/price_text.dart';
import '../../live/data/live_providers.dart';
import '../../live/presentation/customer/live_ring.dart';
import '../../live/presentation/customer/live_status_line.dart';
import '../data/explore_models.dart';
import 'pro_avatar.dart';
import 'pro_labels.dart';

/// One explore result: who, where, the live status and queue, and from what
/// price. The whole card is one button that opens the public profile. The
/// live part follows the pro's channel while the card is mounted.
class ProCardTile extends ConsumerWidget {
  const ProCardTile({required this.card, required this.onTap, super.key});

  final ProCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An unlisted or refused pro has no live line; the card still reads.
    final live = ref.watch(proLiveProvider(card.proId)).value;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final place = placeLine(card.localityName(locale), card.regionName(locale));
    final kids = kidsTagOf(l10n, card.customerMix);
    final price = card.minPriceDzd;
    final distance = distanceLabel(l10n, locale, card);
    final radius = BorderRadius.circular(LemqesShape.cardRadius);

    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          boxShadow: LemqesShape.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveRing(
                    view: live,
                    child: ProAvatar(
                      name: card.displayName,
                      path: card.avatarPath,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                card.displayName,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (card.isVerified) ...[
                              const SizedBox(width: 6),
                              const VerifiedTick(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workplaceLine(
                            l10n,
                            card.workplaceType,
                            card.workplaceName,
                          ),
                          style: muted,
                        ),
                        if (place != null) Text(place, style: muted),
                        if (live != null) ...[
                          const SizedBox(height: 6),
                          LiveStatusLine(view: live),
                          LiveQueueLine(view: live),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (price != null)
                              Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(l10n.exploreFromPrice, style: muted),
                                  PriceText(
                                    price,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                              )
                            else
                              Text(
                                l10n.proPriceHidden(card.workplaceType.toDb()),
                                style: muted,
                              ),
                            if (distance != null) _DistanceLabel(distance),
                            if (card.comesToYou ?? false)
                              MistTag(l10n.exploreComesToYou),
                            if (kids != null) MistTag(kids),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
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

/// "700 m" with a pin: tabular Latin digits, left-to-right inside Arabic.
class _DistanceLabel extends StatelessWidget {
  const _DistanceLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.near_me_outlined, size: 16, color: color),
        ),
        const SizedBox(width: 4),
        // Not wrapped in Ltr: the digits are Latin and tabular, the unit
        // keeps the reading order of the surrounding script ("700 م").
        Text(
          text,
          key: const Key('proDistance'),
          style: theme.textTheme.bodyMedium!
              .merge(lemqesNumeric)
              .copyWith(color: color),
        ),
      ],
    );
  }
}
