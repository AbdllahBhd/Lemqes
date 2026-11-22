import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../core/time/clock_providers.dart';
import '../../../../shared/widgets/hours_table.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/price_text.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../account/data/account.dart';
import '../../../explore/data/explore_models.dart' show PlaceMode;
import '../../../explore/presentation/pro_avatar.dart';
import '../../../explore/presentation/pro_labels.dart';
import '../../../explore/presentation/pro_public_profile_screen.dart'
    show experienceBandOf;
import '../../../geo/data/geo_providers.dart';
import '../../../home/presentation/home_header.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../edit/hours_editor.dart';
import '../edit/photo_gallery_editor.dart';
import '../edit/privacy_section.dart';
import '../edit/service_editor.dart';
import '../pro_failure_listener.dart';
import '../place/place_picker_screen.dart';
import '../pro_failure_message.dart';
import '../setup/profile_step.dart';

/// "Mon profil": the pro home. Whether customers can see the profile (and
/// what is missing), then every part of it to edit in place, and a look at
/// it as customers see it.
class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ProKind.forRole(account.activeRole);
    final state = ref.watch(myProProvider);
    final value = state.value;
    // After a role switch the value is the previous role's profile until the
    // reload lands; it must never show (or be edited) as this role's.
    final stale = value != null && value.kind != kind;
    final profile = stale ? null : value;

    final Widget body;
    if (kind == null) {
      // Salon owners get their own space with salons (M7).
      body = EmptyView(
        icon: Icons.storefront_outlined,
        title: l10n.dashboardSalonTitle,
        body: l10n.dashboardSalonBody,
      );
    } else if (!state.hasValue ||
        stale ||
        // Riverpod keeps the last value through a reload: a customer's
        // "no profile" stays the value while the pro role's profile loads,
        // and through a failed load. Only a settled value says there is none.
        (profile == null && (state.isLoading || state.hasError))) {
      body = state.hasError && !state.isLoading
          ? ErrorView(
              message: proFailureMessage(l10n, state.error),
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(myProProvider),
            )
          : LoadingView(label: l10n.loading);
    } else if (profile == null) {
      body = EmptyView(
        icon: Icons.badge_outlined,
        title: l10n.homeProEmptyTitle,
        body: l10n.dashboardNoProfileBody,
        action: LemqesPrimaryButton(
          key: const Key('dashComplete'),
          label: l10n.dashboardComplete,
          onPressed: () => context.go('/pro/setup'),
        ),
      );
    } else {
      body = _DashboardBody(profile: profile);
    }

    return ProFailureListener(
      child: Scaffold(
        body: Column(
          children: [
            _Header(account: account, profile: profile),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The band: the pro's photo (tap to change), name and verified tick, the
/// role and settings actions, and the fixed space.
class _Header extends StatelessWidget {
  const _Header({required this.account, required this.profile});

  final Account account;
  final ProProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = this.profile;
    final name = profile?.displayName ?? account.displayName;
    final space = (profile?.space ?? account.currentSpace).toDb();
    return HomeHeader(
      title: Row(
        children: [
          if (profile != null) ...[
            _AvatarButton(profile: profile),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: lemqesWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.w600,
                ).copyWith(color: Colors.white),
              ),
            ),
          ),
          if (profile?.isVerified ?? false) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.verified_outlined,
              size: 22,
              color: Colors.white,
              semanticLabel: l10n.proVerified,
            ),
          ],
        ],
      ),
      children: [
        Row(
          children: [
            Flexible(child: BandTag(label: l10n.homeSpaceLabel(space))),
            Tooltip(
              message: l10n.proSpaceFixedHint,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 4),
              // A hint, not an action: the tooltip opens on tap for
              // sighted users and the label reads it out.
              child: Semantics(
                label: l10n.proSpaceFixedHint,
                excludeSemantics: true,
                child: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.info_outline, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The profile photo on the band; a tap picks a new one.
class _AvatarButton extends ConsumerStatefulWidget {
  const _AvatarButton({required this.profile});

  final ProProfile profile;

  @override
  ConsumerState<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends ConsumerState<_AvatarButton> {
  bool _busy = false;

  Future<void> _change() async {
    // Set before the picker opens: a second tap would open a second one.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? file;
      try {
        file = await ref.read(avatarPickerProvider)();
      } on Object catch (e, st) {
        developer.log('avatar pick failed', error: e, stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.photoPickFailed)));
        }
        return;
      }
      if (file == null || !mounted) return;
      // A failure keeps the old photo; the listener says why.
      await ref.read(myProProvider.notifier).uploadAvatar(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.setupAvatarChange,
      onTap: _busy ? null : _change,
      excludeSemantics: true,
      child: InkResponse(
        key: const Key('dashAvatar'),
        onTap: _busy ? null : _change,
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProAvatar(
                  name: widget.profile.displayName,
                  path: widget.profile.avatarPath,
                  size: 40,
                ),
                if (_busy)
                  const Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                PositionedDirectional(
                  end: -4,
                  bottom: -4,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        // Deep sea on the white disc in both themes (the
                        // dark scheme's pale primary fades on white).
                        color: Color(0xFF062A35),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _VisibilityCard(profile: profile),
        _Card(
          title: l10n.dashboardProfileSection,
          action: _CardAction(
            actionKey: 'dashEditProfile',
            icon: Icons.edit_outlined,
            label: l10n.dashboardEditProfile,
            // Pushed, so back (and saving) returns here.
            onPressed: () => context.push('/pro/setup/profile?edit=1'),
          ),
          child: _ProfileSummary(profile: profile),
        ),
        _PlaceCard(profile: profile),
        _Card(
          title: l10n.proPublicServices,
          child: _Services(profile: profile),
        ),
        _Card(
          title: l10n.proPublicHours,
          action: _CardAction(
            actionKey: 'dashEditHours',
            icon: Icons.schedule_outlined,
            label: l10n.dashboardEditHours,
            onPressed: () => _editHours(context, profile.hours),
          ),
          child: Consumer(
            builder: (context, ref, _) => HoursTable(
              week: profile.hours,
              clock: ref.watch(countryClockProvider),
            ),
          ),
        ),
        _Card(
          title: l10n.proPublicPhotos,
          child: PhotoGalleryEditor(photos: profile.photos),
        ),
        _Card(
          title: l10n.privacySection,
          child: PrivacySection(profile: profile),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const Key('dashPreview'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l10n.dashboardPreview),
          onPressed: () => context.push('/pro/me/preview'),
        ),
      ],
    );
  }
}

/// Published or hidden; when hidden, what is missing and the one way on
/// (complete the first missing step, or publish a complete profile).
class _VisibilityCard extends ConsumerStatefulWidget {
  const _VisibilityCard({required this.profile});

  final ProProfile profile;

  @override
  ConsumerState<_VisibilityCard> createState() => _VisibilityCardState();
}

class _VisibilityCardState extends ConsumerState<_VisibilityCard> {
  bool _publishing = false;

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    // A refusal is said by the listener; the gaps then show here.
    await ref.read(myProProvider.notifier).publish();
    if (mounted) setState(() => _publishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.profile;
    final published = p.isPublished;
    final gaps = p.gaps;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return _CardFrame(
      key: const Key('visibilityCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      published
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        published
                            ? l10n.dashboardPublished
                            : l10n.dashboardHidden,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      published
                          ? l10n.dashboardPublishedBody(p.space.toDb())
                          : gaps.isEmpty
                          ? l10n.dashboardReadyBody
                          : l10n.dashboardHiddenBody,
                      style: muted,
                    ),
                    if (!published)
                      for (final gap in ProfileGap.values)
                        if (gaps.contains(gap))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: scheme.error,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.dashboardGap(_gapKey(gap)),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
          if (!published) ...[
            const SizedBox(height: 16),
            if (gaps.isEmpty)
              LemqesPrimaryButton(
                key: const Key('dashPublish'),
                label: l10n.dashboardPublish,
                icon: Icons.publish_outlined,
                expand: true,
                loading: _publishing,
                onPressed: _publishing ? null : _publish,
              )
            else
              LemqesPrimaryButton(
                key: const Key('dashComplete'),
                label: l10n.dashboardComplete,
                expand: true,
                // Setup resumes at the first step with a gap.
                onPressed: () => context.go('/pro/setup'),
              ),
          ],
        ],
      ),
    );
  }
}

String _gapKey(ProfileGap gap) => switch (gap) {
  ProfileGap.locality => 'locality',
  ProfileGap.customerMix => 'mix',
  ProfileGap.services => 'services',
  ProfileGap.hours => 'hours',
};

/// The white card every section sits on. A [Material], not a coloured box,
/// so the rows' ink and the switch tile paint on it.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LemqesShape.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: radius,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// A section: heading, content, and its edit action at the bottom start.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _CardFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            child,
            if (action != null) ...[
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerStart, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String actionKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: Key(actionKey),
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}

TextStyle _muted(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium!.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// Workplace, commune, customers and experience, as customers read them.
class _ProfileSummary extends ConsumerWidget {
  const _ProfileSummary({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final p = profile;
    final space = p.space.toDb();
    final localityId = p.localityId;
    final locality = localityId == null
        ? null
        : ref.watch(localityProvider(localityId)).value;
    final region = locality == null
        ? null
        : ref
              .watch(regionsProvider('DZ'))
              .value
              ?.where((r) => r.code == locality.regionCode)
              .firstOrNull;
    final place = placeLine(locality?.name(locale), region?.name(locale));
    final mix = switch (p.customerMix) {
      null => null,
      CustomerMix.adults => l10n.customerMixAdults(space),
      CustomerMix.adultsAndKids => l10n.customerMixAdultsAndKids(space),
      CustomerMix.kidsOnly => l10n.customerMixKidsOnly,
    };
    final years = p.experienceYears;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconLine(
          icon: p.workplaceType == WorkplaceType.mobile
              ? Icons.directions_car_outlined
              : Icons.storefront_outlined,
          text: workplaceLine(l10n, p.workplaceType, p.workplaceName),
        ),
        if (place != null) _IconLine(icon: Icons.place_outlined, text: place),
        if (mix != null) _IconLine(icon: Icons.groups_outlined, text: mix),
        if (years != null)
          _IconLine(
            icon: Icons.workspace_premium_outlined,
            text: l10n.proPublicExperience('b${experienceBandOf(years)}'),
          ),
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// What location customers see, with the way to change it. A salon that
/// shows none is nudged to place itself (S2); studios and home artists
/// never are. Anything shown can be hidden in one tap (S1).
class _PlaceCard extends ConsumerStatefulWidget {
  const _PlaceCard({required this.profile});

  final ProProfile profile;

  @override
  ConsumerState<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<_PlaceCard> {
  bool _hiding = false;

  // Pushed, so back (and saving) returns here.
  void _edit() => context.push('/pro/setup/location?edit=1');

  Future<void> _hide() async {
    if (_hiding) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiding = true);
    final failure = await savePlace(ref, PlaceMode.none);
    if (!mounted) return;
    setState(() => _hiding = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? l10n.placeHidden
              : placeFailureMessage(l10n, failure),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.profile;
    final place = p.place;
    final mode = place?.mode ?? PlaceMode.none;
    final nudge =
        mode == PlaceMode.none && p.workplaceType == WorkplaceType.salon;
    final landmark = place?.landmark;

    final Widget content;
    if (nudge) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      Icons.add_location_alt_outlined,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.placeNudgeTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.placeNudgeBody(p.space.toDb()),
                      style: _muted(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('dashPlaceNudgeAction'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.placeNudgeAction),
            onPressed: _edit,
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IconLine(
            icon: switch (mode) {
              PlaceMode.exact => Icons.location_on_outlined,
              PlaceMode.area => Icons.radar_outlined,
              PlaceMode.none => Icons.location_city_outlined,
            },
            text: switch (mode) {
              PlaceMode.exact => l10n.placeSummaryExact,
              PlaceMode.area => l10n.placeSummaryArea(
                placeRadiusLabel(l10n, place?.areaRadiusM ?? 1000),
              ),
              PlaceMode.none => l10n.placeSummaryNone,
            },
          ),
          if (mode == PlaceMode.exact && landmark != null)
            _IconLine(icon: Icons.signpost_outlined, text: landmark),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _CardAction(
                actionKey: 'dashEditPlace',
                icon: Icons.edit_location_alt_outlined,
                label: l10n.placeEdit,
                onPressed: _hiding ? null : _edit,
              ),
              if (mode != PlaceMode.none)
                _CardAction(
                  actionKey: 'dashHidePlace',
                  icon: Icons.location_off_outlined,
                  label: l10n.placeHide,
                  onPressed: _hiding ? null : _hide,
                ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _CardFrame(
        key: const Key('placeCard'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.placeSectionTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            if (_hiding) const LinearProgressIndicator(),
            content,
          ],
        ),
      ),
    );
  }
}

/// The services with their prices; a row opens the editor (price,
/// duration, pause, remove); "add" offers the space's remaining presets or a
/// custom one.
class _Services extends ConsumerStatefulWidget {
  const _Services({required this.profile});

  final ProProfile profile;

  @override
  ConsumerState<_Services> createState() => _ServicesState();
}

/// The add sheet's answer: a preset, or null for a custom service.
typedef _AddChoice = ({ServicePreset? preset});

class _ServicesState extends ConsumerState<_Services> {
  bool _busy = false;

  ({Space space, bool home}) get _presetsKey => (
    space: widget.profile.space,
    home: widget.profile.kind == ProKind.homeArtist,
  );

  List<ServiceCategory> _categories(List<ServicePreset> presets) => [
    for (final c in ServiceCategory.values)
      if (presets.isEmpty || presets.any((p) => p.category == c)) c,
  ];

  Future<void> _edit({ServicePreset? preset, ProService? existing}) async {
    if (_busy) return;
    final presets = ref.read(presetsProvider(_presetsKey)).value ?? const [];
    final result = await showServiceEditor(
      context,
      preset: preset,
      existing: existing,
      categories: _categories(presets),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    // Failures reach the listener through the controller's state.
    final pro = ref.read(myProProvider.notifier);
    await switch (result) {
      ServiceSaved(:final draft) => pro.upsertService(draft),
      ServiceRemoved() => pro.archiveService(existing!.id),
    };
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add(List<ServicePreset> presets) async {
    if (_busy) return;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final taken = {for (final s in widget.profile.services) s.presetKey};
    final remaining = [
      for (final p in presets)
        if (!taken.contains(p.key)) p,
    ];
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LemqesShape.sheetRadius),
        ),
      ),
      builder: (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.dashboardAddService,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final p in remaining)
              ListTile(
                key: Key('addPreset_${p.key}'),
                minTileHeight: 56,
                title: Text(p.name(locale)),
                subtitle: Text(l10n.serviceDuration(p.defaultDurationMin)),
                trailing: PriceText(p.defaultPriceDzd),
                onTap: () => Navigator.of(sheet).pop((preset: p)),
              ),
            ListTile(
              key: const Key('addCustom'),
              minTileHeight: 56,
              leading: const Icon(Icons.add),
              title: Text(l10n.setupServicesCustom),
              onTap: () => Navigator.of(sheet).pop((preset: null)),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _edit(preset: choice.preset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final presets =
        ref.watch(presetsProvider(_presetsKey)).value ??
        const <ServicePreset>[];
    final byKey = {for (final p in presets) p.key: p};
    final services = widget.profile.services;
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (!services.any((s) => s.active))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.dashboardServicesEmpty, style: _muted(context)),
          ),
        for (final (i, s) in services.indexed) ...[
          if (i > 0) Divider(height: 1, color: divider),
          _ServiceRow(
            key: Key('dashService_${s.id}'),
            // Until the presets load, the category names a preset service.
            name:
                s.customName ??
                byKey[s.presetKey]?.name(locale) ??
                l10n.serviceCategoryName(s.category.toDb()),
            service: s,
            // Off while a save runs: one write at a time, and a tap must
            // never be dropped unseen.
            onTap: _busy
                ? null
                : () => _edit(preset: byKey[s.presetKey], existing: s),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _CardAction(
            actionKey: 'dashAddService',
            icon: Icons.add,
            label: l10n.dashboardAddService,
            onPressed: _busy ? null : () => _add(presets),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = _muted(context);
    final price = service.priceDzd;
    final duration = l10n.serviceDuration(service.durationMin);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.bodyLarge),
                      Text(
                        service.active
                            ? duration
                            : '$duration · ${l10n.servicePaused}',
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

/// Opens the week in a sheet; saving closes it and stores the week (a
/// refusal is said by the listener once the sheet is gone).
Future<void> _editHours(BuildContext context, List<DayHours> hours) async {
  final container = ProviderScope.containerOf(context);
  final week = await showModalBottomSheet<List<DayHours>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LemqesShape.sheetRadius),
      ),
    ),
    builder: (_) => _HoursSheet(initial: hours),
  );
  if (week == null) return;
  await container.read(myProProvider.notifier).setHours(week);
}

class _HoursSheet extends ConsumerStatefulWidget {
  const _HoursSheet({required this.initial});

  final List<DayHours> initial;

  @override
  ConsumerState<_HoursSheet> createState() => _HoursSheetState();
}

class _HoursSheetState extends ConsumerState<_HoursSheet> {
  late List<DayHours> _week = widget.initial;
  late bool _valid = widget.initial.every((d) => hoursIssue(d) == null);
  String? _message;

  void _save() {
    final l10n = context.l10n;
    if (_week.isEmpty || !_valid) {
      setState(
        () => _message = _week.isEmpty
            ? l10n.dashboardHoursNeedOne
            : l10n.hoursFixErrors,
      );
      return;
    }
    Navigator.of(context).pop(_week);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final message = _message;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Semantics(
              header: true,
              child: Text(
                l10n.dashboardEditHours,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: HoursEditor(
                initial: widget.initial,
                pickTime: ref.watch(timePickProvider),
                onChanged: (week, valid) => setState(() {
                  _week = week;
                  _valid = valid;
                  _message = null;
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) ...[
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                LemqesPrimaryButton(
                  key: const Key('hoursSave'),
                  label: l10n.dashboardSaveHours,
                  expand: true,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
