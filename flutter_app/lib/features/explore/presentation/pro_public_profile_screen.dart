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
import '../../../shared/widgets/hours_table.dart';
import '../../../shared/widgets/lagoon_header_band.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../../shared/widgets/ltr.dart';
import '../../../shared/widgets/photo_tile.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account_providers.dart';
import '../../auth/presentation/auth_widgets.dart' show formatAlgerianPhone;
import '../../geo/data/geo_providers.dart';
import '../../pro/data/photo_uploader.dart';
import '../../pro/data/pro_models.dart';
import '../../pro/data/pro_providers.dart';
import '../../pro/presentation/pro_failure_message.dart';
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
      return ref.watch(proRepositoryProvider).contactPhone(id);
    }, retry: (_, _) => null);

/// Opens a `tel:` link; overridable so tests never reach the platform.
final phoneLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (_) => launchUrl,
);

/// "Today" for the hours table; overridable for stable goldens.
final profileClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

int _experienceBand(int years) => switch (years) {
  < 2 => 0,
  < 5 => 1,
  < 10 => 2,
  _ => 3,
};

/// What a customer sees of one pro: who they are, where, what they offer at
/// what price, when they work and their photos; a call when the number is
/// public.
class ProPublicProfileScreen extends ConsumerWidget {
  const ProPublicProfileScreen({required this.proId, super.key});

  final String proId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(publicProProvider(proId));
    final profile = state.value;
    final phone = profile == null
        ? null
        : ref.watch(proContactPhoneProvider(proId)).value;

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
    } else if (profile == null) {
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
    } else {
      body = _ProfileBody(profile: profile);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: body,
        bottomNavigationBar: phone == null ? null : _CallBar(phone: phone),
      ),
    );
  }
}

/// The band's top row: back, white on the gradient.
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 4,
        top: MediaQuery.paddingOf(context).top + 4,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: IconButton(
          key: const Key('proBack'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          color: Colors.white,
          icon: const BackButtonIcon(),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
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
  const _ProfileBody({required this.profile});

  final ProProfile profile;

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
              child: _Hero(profile: p),
            ),
            child: const _BackRow(),
          ),
          Padding(
            // Each section adds its own 16 dp above.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

class _Hero extends ConsumerWidget {
  const _Hero({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        : '$kind · ${l10n.proPublicExperience('b${_experienceBand(years)}')}';
    final place = _placeOf(context, ref, p.localityId);
    final muted = _muted(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProAvatar(name: p.displayName, path: p.avatarPath, size: 72),
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
                    text: workplaceLine(l10n, p.workplaceType, p.workplaceName),
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
      ),
    );
  }

  /// "Commune · Wilaya" once both lookups answer; the line stays out until
  /// then (and if they fail: the rest of the profile still reads).
  String? _placeOf(BuildContext context, WidgetRef ref, int? localityId) {
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

class _Services extends ConsumerWidget {
  const _Services({required this.profile});

  final ProProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final p = profile;
    final presets = ref
        .watch(
          presetsProvider((space: p.space, home: p.kind == ProKind.homeArtist)),
        )
        .value;
    final byKey = {
      for (final s in presets ?? const <ServicePreset>[]) s.key: s,
    };
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

  // Until the presets load (or if they fail), the category names a preset
  // service rather than its raw key.
  String _serviceName(
    AppLocalizations l10n,
    Locale locale,
    ProService s,
    Map<String, ServicePreset> byKey,
  ) =>
      s.customName ??
      byKey[s.presetKey]?.name(locale) ??
      l10n.serviceCategoryName(s.category.toDb());
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
      HoursTable(week: profile.hours, clock: ref.watch(profileClockProvider));
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
                child: ExcludeSemantics(
                  child: InkWell(
                    key: Key('proPhoto_$i'),
                    borderRadius: BorderRadius.circular(PhotoTile.radius),
                    onTap: () =>
                        showPhotoViewer(context, urls: urls, initial: i),
                    child: PhotoTile(url: url),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The one primary action, under the thumb: the number, then the call.
class _CallBar extends ConsumerWidget {
  const _CallBar({required this.phone});

  final String phone;

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
            LemqesPrimaryButton(
              key: const Key('callPro'),
              label: l10n.proPublicCall,
              icon: Icons.call_outlined,
              expand: true,
              onPressed: () => _call(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
