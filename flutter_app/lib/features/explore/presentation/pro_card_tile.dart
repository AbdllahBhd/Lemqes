import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
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
