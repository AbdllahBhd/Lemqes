import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../account/data/account_providers.dart';
import '../../../explore/presentation/pro_public_profile_screen.dart';
import '../../../home/presentation/home_header.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';

/// [p] as a customer receives it: only active services, and no prices when
/// the pro hides them (the customer RPC returns them null).
ProProfile customerViewOf(ProProfile p) => ProProfile(
  id: p.id,
  kind: p.kind,
  space: p.space,
  displayName: p.displayName,
  workplaceType: p.workplaceType,
  phoneVisibility: p.phoneVisibility,
  showPrices: p.showPrices,
  isVerified: p.isVerified,
  bio: p.bio,
  experienceYears: p.experienceYears,
  workplaceName: p.workplaceName,
  localityId: p.localityId,
  customerMix: p.customerMix,
  serviceRadiusKm: p.serviceRadiusKm,
  travelFeeDzd: p.travelFeeDzd,
  avatarPath: p.avatarPath,
  publishedAt: p.publishedAt,
  services: [
    for (final s in p.services)
      if (s.active)
        ProService(
          id: s.id,
          presetKey: s.presetKey,
          customName: s.customName,
          category: s.category,
          priceDzd: p.showPrices ? s.priceDzd : null,
          durationMin: s.durationMin,
          sort: s.sort,
        ),
  ],
  hours: p.hours,
  photos: p.photos,
);

/// `/pro/me/preview`: the owner's public profile as customers see it.
///
/// Built from the owner's own profile: the customer read serves services
/// only for listable profiles seen as a customer, so the owner would see
/// none. The call never dials (and the phone is never fetched): it shows
/// where customers will find it.
class ProProfilePreviewScreen extends ConsumerWidget {
  const ProProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(myProProvider);
    final role = ref.watch(accountProvider.select((a) => a.value?.activeRole));
    final kind = role == null ? null : ProKind.forRole(role);
    final profile = state.value;

    if (profile == null || profile.kind != kind) {
      return Scaffold(
        body: SafeArea(
          child: state.isLoading || !state.hasValue
              ? LoadingView(label: l10n.loading)
              : EmptyView(
                  icon: Icons.person_off_outlined,
                  title: l10n.proUnavailableTitle,
                  action: LemqesPrimaryButton(
                    label: l10n.proUnavailableBack,
                    icon: Icons.home_outlined,
                    onPressed: () => context.go('/home'),
                  ),
                ),
        ),
      );
    }

    return ProPublicProfileView(
      profile: customerViewOf(profile),
      marker: Semantics(
        key: const Key('previewTag'),
        child: BandTag(label: l10n.previewTag),
      ),
      bottomBar: profile.phoneVisibility == PhoneVisibility.public
          ? const _CallPreviewBar()
          : null,
    );
  }
}

/// Where customers find the call: a button that cannot call, and why.
class _CallPreviewBar extends StatelessWidget {
  const _CallPreviewBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.previewCallNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            LemqesPrimaryButton(
              key: const Key('callPreview'),
              label: l10n.proPublicCall,
              icon: Icons.call_outlined,
              expand: true,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}
