import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/lemqes_typography.dart';
import '../../../core/time/clock_providers.dart';
import '../../../shared/widgets/hours_table.dart';
import '../../../shared/widgets/lagoon_header_band.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../../shared/widgets/ltr.dart';
import '../../../shared/widgets/photo_tile.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account_providers.dart';
import '../../auth/presentation/auth_widgets.dart' show formatAlgerianPhone;
import '../../geo/data/geo_models.dart' show GeoPoint;
import '../../geo/data/geo_providers.dart';
import '../../live/presentation/customer/join_queue_sheet.dart';
import '../../live/data/live_providers.dart';
import '../../live/presentation/customer/live_block.dart';
import '../../live/presentation/customer/live_ring.dart';
import '../../pro/data/photo_uploader.dart';
import '../../pro/data/pro_models.dart';
import '../../pro/data/pro_providers.dart';
import '../../pro/presentation/pro_failure_message.dart';
import '../data/explore_models.dart';
import 'directions_button.dart';
import 'explore_map_view.dart' show directionsPointOf;
import 'photo_viewer.dart';
import 'pro_avatar.dart';
import 'pro_labels.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// What is listable depends on the caller's space and acting role: reload
/// when they change. Read from the last known account, so a failed switch
/// (an error that keeps the account) does not fail the profile.
void _watchVisibility(Ref ref) => ref.watch(
  accountProvider.select((a) => (a.value?.currentSpace, a.value?.activeRole)),
);

/// The profile behind `/pro/:id` as the caller may see it; null when it does
/// not exist or is not listable to them.
final publicProProvider = FutureProvider.autoDispose
    .family<ProProfile?, String>((ref, id) async {
      // The database would reject a malformed id as invalid input, which
      // would read as a failure to retry instead of "no such profile".
      if (!_uuid.hasMatch(id)) return null;
      _watchVisibility(ref);
      return ref.watch(proRepositoryProvider).publicProfile(id);
    }, retry: (_, _) => null);

/// The pro's phone when they made it public; null otherwise.
final proContactPhoneProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, id) async {
      if (!_uuid.hasMatch(id)) return null;
      _watchVisibility(ref);
      try {
        return await ref.watch(proRepositoryProvider).contactPhone(id);
      } on Object catch (e, st) {
        // The screen offers a retry; the cause goes to the log.
        developer.log('pro_contact_phone failed', error: e, stackTrace: st);
        rethrow;
      }
    }, retry: (_, _) => null);

/// Opens a `tel:` link; overridable so tests never reach the platform.
final phoneLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) => launchUrl,
);

/// The experience band (b0..b3) that `proPublicExperience` words a year
/// count in.
int experienceBandOf(int years) => switch (years) {
  < 2 => 0,
  < 5 => 1,
  < 10 => 2,
  _ => 3,
};

/// What a customer sees of one pro: who they are, where, what they offer at
/// what price, when they work and their photos; a call when the number is
/// public.
class ProPublicProfileScreen extends ConsumerWidget {
  const ProPublicProfileScreen({required this.proId, this.card, super.key});

  final String proId;

  /// The explore card this was opened from; a link has none (and so no
  /// directions: the public profile does not carry the pin).
  final ProCard? card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(publicProProvider(proId));
    // After a failed reload the previous profile is still in `value`; the
    // error view must not sit over its working call bar.
    final profile = state.hasError ? null : state.value;
    final phone = profile == null
        ? null
        : ref.watch(proContactPhoneProvider(proId));
    final Widget? callBar = switch (phone) {
      null => null,
      // The call is the screen's only action: its failure is said, not hidden
      // as if the number were private.
      AsyncValue(hasError: true) => _PhoneUnavailableBar(
        onRetry: () => ref.invalidate(proContactPhoneProvider(proId)),
      ),
      AsyncValue(value: final String number) => _CallBar(
        phone: number,
        // One primary action leads: the live block's, when it has one.
        primary: !liveBlockOffersAction(
          ref,
          proId,
          hasServices: profile!.services.isNotEmpty,
        ),
      ),
      _ => null,
    };

    if (!state.hasError && profile != null) {
      final from = card;
      return ProPublicProfileView(
        profile: profile,
        bottomBar: callBar,
        asCustomer: true,
        directionsTo: from != null && from.proId == proId
            ? directionsPointOf(from)
            : null,
      );
    }

    final Widget body;
    if (state.hasError && !state.isLoading) {
      body = _StatePage(
        child: ErrorView(
          message: proFailureMessage(l10n, state.error),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(publicProProvider(proId)),
        ),
      );
    } else if (!state.hasValue) {
      body = _StatePage(child: LoadingView(label: l10n.loading));
    } else {
      body = _StatePage(
        child: EmptyView(
          key: const Key('proUnavailable'),
          icon: Icons.person_off_outlined,
          title: l10n.proUnavailableTitle,
          body: l10n.proUnavailableBody,
          action: LemqesPrimaryButton(
            label: l10n.proUnavailableBack,
            icon: Icons.home_outlined,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(body: body),
    );
  }
}

/// One pro's public profile as customers see it, from a [profile] already
/// shaped for them. [marker] sits on the band beside back (the owner's
/// "preview" tag); [bottomBar] holds the call.
class ProPublicProfileView extends StatelessWidget {
  const ProPublicProfileView({
    required this.profile,
    this.marker,
    required this.asCustomer,
    this.bottomBar,
    this.directionsTo,
    super.key,
  });

  final ProProfile profile;
  final Widget? marker;
  final Widget? bottomBar;

  /// An exact pin to offer directions to, under the hero.
  final GeoPoint? directionsTo;

  /// A customer's view: the live block and the hero ring follow the
  /// customer channel, and the block offers the join. The owner's preview
  /// passes false: both read the owner's own channel, with nothing to tap.
  final bool asCustomer;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: _ProfileBody(
          profile: profile,
          marker: marker,
          asCustomer: asCustomer,
          directionsTo: directionsTo,
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// The band's top row: back, white on the gradient.
class _BackRow extends StatelessWidget {
  const _BackRow({this.marker});

  final Widget? marker;

  @override
  Widget build(BuildContext context) {
    final marker = this.marker;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 4,
        end: 16,
        top: MediaQuery.paddingOf(context).top + 4,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Row(
          children: [
            IconButton(
              key: const Key('proBack'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              color: Colors.white,
              icon: const BackButtonIcon(),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            if (marker != null) ...[const Spacer(), Flexible(child: marker)],
          ],
        ),
      ),
    );
  }
}

double _bandHeight(BuildContext context) =>
    MediaQuery.paddingOf(context).top + 4 + 48 + 12;

/// A band with back, then a loading, error or unavailable view.
class _StatePage extends StatelessWidget {
  const _StatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LagoonHeaderBand(height: _bandHeight(context), child: const _BackRow()),
        Expanded(child: child),
      ],
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.asCustomer,
    this.marker,
    this.directionsTo,
  });

  final ProProfile profile;
  final bool asCustomer;
  final Widget? marker;
  final GeoPoint? directionsTo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = profile;
    final mix = p.customerMix;
    final bio = p.bio?.trim();
    final hasBio = bio != null && bio.isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LagoonHeaderBand(
            height: _bandHeight(context) + LagoonHeaderBand.overlapRise,
            overlap: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Hero(
                profile: p,
                asCustomer: asCustomer,
                directionsTo: directionsTo,
              ),
            ),
            child: _BackRow(marker: marker),
          ),
          Padding(
            // Each section adds its own 16 dp above.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: asCustomer
                      ? _CustomerLiveBlock(profile: p)
                      : LiveBlock.owner(proId: p.id),
                ),
                if (hasBio || mix != null)
                  _Section(
                    title: l10n.proPublicAbout,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasBio) Text(bio, style: _body(context)),
                        if (hasBio && mix != null) const SizedBox(height: 16),
                        if (mix != null) _CustomerMixLine(profile: p),
                      ],
                    ),
                  ),
                if (p.services.isNotEmpty)
                  _Section(
                    title: l10n.proPublicServices,
                    child: _Services(profile: p),
                  ),
                _Section(
                  title: l10n.proPublicHours,
                  child: _Hours(profile: p),
                ),
                if (p.photos.isNotEmpty)
                  _Section(
                    title: l10n.proPublicPhotos,
                    child: _Photos(photos: p.photos),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _body(BuildContext context) => Theme.of(context).textTheme.bodyLarge!;

TextStyle _muted(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium!.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// A white card with a heading.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
          boxShadow: LemqesShape.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends ConsumerStatefulWidget {
  const _Hero({
    required this.profile,
    required this.asCustomer,
    this.directionsTo,
  });

  final ProProfile profile;
  final bool asCustomer;
  final GeoPoint? directionsTo;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  @override
  void initState() {
    super.initState();
    // The geo lookups are cached app-wide without retry: a failure seen on
    // an earlier profile would otherwise hide the place on every profile
    // until restart. Each hero asks again for what failed. After the frame,
    // because providers cannot change while widgets build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = widget.profile.localityId;
      if (id != null && ref.read(localityProvider(id)).hasError) {
        ref.invalidate(localityProvider(id));
      }
      if (ref.read(regionsProvider('DZ')).hasError) {
        ref.invalidate(regionsProvider('DZ'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = profile;
    final space = p.space.toDb();
    final kind = p.kind == ProKind.homeArtist
        ? l10n.roleHomeArtistTitle(space)
        : l10n.roleBarberTitle(space);
    final years = p.experienceYears;
    final kindLine = years == null
        ? kind
        : '$kind · ${l10n.proPublicExperience('b${experienceBandOf(years)}')}';
    final place = _placeOf(context, p.localityId);
    final muted = _muted(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveRing(
                  view: ref
                      .watch(
                        widget.asCustomer
                            ? proLiveProvider(p.id)
                            : ownProLiveProvider(p.id),
                      )
                      .value,
                  child: ProAvatar(
                    name: p.displayName,
                    path: p.avatarPath,
                    size: 72,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.displayName,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (p.isVerified) ...[
                              const SizedBox(width: 6),
                              const VerifiedTick(size: 20),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(kindLine, style: muted),
                      const SizedBox(height: 8),
                      _IconLine(
                        icon: p.workplaceType == WorkplaceType.mobile
                            ? Icons.directions_car_outlined
                            : Icons.storefront_outlined,
                        text: workplaceLine(
                          l10n,
                          p.workplaceType,
                          p.workplaceName,
                        ),
                      ),
                      if (place != null) ...[
                        const SizedBox(height: 4),
                        _IconLine(icon: Icons.place_outlined, text: place),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (widget.directionsTo case final to?) ...[
              const SizedBox(height: 16),
              DirectionsButton(to: to),
            ],
          ],
        ),
      ),
    );
  }

  /// "Commune · Wilaya" once both lookups answer; the line stays out until
  /// then (and if they fail: the rest of the profile still reads).
  String? _placeOf(BuildContext context, int? localityId) {
    if (localityId == null) return null;
    final locale = Localizations.localeOf(context);
    final locality = ref.watch(localityProvider(localityId)).value;
    if (locality == null) return null;
    final region = ref
        .watch(regionsProvider('DZ'))
        .value
        ?.where((r) => r.code == locality.regionCode)
        .firstOrNull;
    return placeLine(locality.name(locale), region?.name(locale));
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = _muted(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: style.color),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _CustomerMixLine extends StatelessWidget {
  const _CustomerMixLine({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = profile.space.toDb();
    final words = switch (profile.customerMix!) {
      CustomerMix.adults => l10n.customerMixAdults(space),
      CustomerMix.adultsAndKids => l10n.customerMixAdultsAndKids(space),
      CustomerMix.kidsOnly => l10n.customerMixKidsOnly,
    };
    return MergeSemantics(
      child: Row(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.proPublicCustomers, style: _muted(context)),
                Text(words, style: _body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A service's name as customers read it. Until the presets load (or if
/// they fail), the category names a preset service rather than its raw key.
String _serviceName(
  AppLocalizations l10n,
  Locale locale,
  ProService s,
  Map<String, ServicePreset> byKey,
) =>
    s.customName ??
    byKey[s.presetKey]?.name(locale) ??
    l10n.serviceCategoryName(s.category.toDb());

Map<String, ServicePreset> _presetsOf(WidgetRef ref, ProProfile p) {
  final presets = ref
      .watch(
        presetsProvider((space: p.space, home: p.kind == ProKind.homeArtist)),
      )
      .value;
  return {for (final s in presets ?? const <ServicePreset>[]) s.key: s};
}

class _CustomerLiveBlock extends ConsumerWidget {
  const _CustomerLiveBlock({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final p = profile;
    final byKey = _presetsOf(ref, p);
    return LiveBlock.customer(
      proId: p.id,
      priceHiddenLabel: l10n.proPriceHidden(p.workplaceType.toDb()),
      services: [
        for (final s in p.services)
          JoinService(
            id: s.id,
            name: _serviceName(l10n, locale, s, byKey),
            durationMin: s.durationMin,
            priceDzd: s.priceDzd,
          ),
      ],
    );
  }
}

class _Services extends ConsumerWidget {
  const _Services({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final p = profile;
    final byKey = _presetsOf(ref, p);
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: [
        for (final (i, s) in p.services.indexed) ...[
          if (i > 0) Divider(height: 1, color: divider),
          _ServiceRow(
            name: _serviceName(l10n, locale, s, byKey),
            service: s,
            workplaceType: p.workplaceType,
          ),
        ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.service,
    required this.workplaceType,
  });

  final String name;
  final ProService service;
  final WorkplaceType workplaceType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = service.priceDzd;
    final muted = _muted(context);
    return MergeSemantics(
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
                    Text(name, style: _body(context)),
                    Text(
                      l10n.serviceDuration(service.durationMin),
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (price != null)
                PriceText(price)
              else
                Flexible(
                  child: Text(
                    l10n.proPriceHidden(workplaceType.toDb()),
                    style: muted,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hours extends ConsumerWidget {
  const _Hours({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      HoursTable(week: profile.hours, clock: ref.watch(countryClockProvider));
}

class _Photos extends ConsumerWidget {
  const _Photos({required this.photos});

  final List<ProPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final uploader = ref.watch(photoUploaderProvider);
    final urls = [
      for (final p in photos) uploader.publicUrl(workPhotosBucket, p.path),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on a phone; tiles never shrink below a tappable size.
        final columns = math.max(2, math.min(3, constraints.maxWidth ~/ 96));
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (i, url) in urls.indexed)
              Semantics(
                button: true,
                label: l10n.photoViewerPosition(i + 1, urls.length),
                onTap: () => showPhotoViewer(context, urls: urls, initial: i),
                excludeSemantics: true,
                child: InkWell(
                  key: Key('proPhoto_$i'),
                  borderRadius: BorderRadius.circular(PhotoTile.radius),
                  onTap: () => showPhotoViewer(context, urls: urls, initial: i),
                  child: PhotoTile(url: url),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The phone lookup failed: says so in the call's place, with a retry.
class _PhoneUnavailableBar extends StatelessWidget {
  const _PhoneUnavailableBar({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              l10n.proPhoneUnavailable,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              key: const Key('phoneRetry'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onRetry,
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one primary action, under the thumb: the number, then the call.
class _CallBar extends ConsumerWidget {
  const _CallBar({required this.phone, required this.primary});

  final String phone;

  /// False while the live block offers its own action: the call is then an
  /// outlined 48 dp button under it.
  final bool primary;

  Future<void> _call(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.proPublicCallFailed;
    var placed = false;
    try {
      placed = await ref.read(phoneLauncherProvider)(
        Uri(scheme: 'tel', path: phone),
      );
    } on Object catch (e, st) {
      developer.log('tel: launch failed', error: e, stackTrace: st);
    }
    if (!placed) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Ltr(
              child: Text(
                formatAlgerianPhone(phone),
                textAlign: TextAlign.center,
                style: lemqesWeight(
                  theme.textTheme.titleMedium!.merge(lemqesNumeric),
                  FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (primary)
              LemqesPrimaryButton(
                key: const Key('callPro'),
                label: l10n.proPublicCall,
                icon: Icons.call_outlined,
                expand: true,
                onPressed: () => _call(context, ref),
              )
            else
              OutlinedButton(
                key: const Key('callPro'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _call(context, ref),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_outlined, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.proPublicCall)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
