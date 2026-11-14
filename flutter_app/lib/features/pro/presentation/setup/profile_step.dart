import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/choice_card.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../account/data/account.dart';
import '../../../account/data/account_providers.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../../geo/data/geo_providers.dart';
import '../../../geo/presentation/locality_picker.dart';
import '../../../signup/presentation/signup_completion.dart';
import '../../data/photo_uploader.dart';
import '../../data/price_parse.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../pro_failure_message.dart';
import 'pro_setup_flow.dart';

/// Picks a profile photo, downsized on the device (JPEG at 82 %).
final avatarPickerProvider = Provider<Future<XFile?> Function()>(
  (_) =>
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 82,
      ),
);

// Stored like the prototype: the middle of each band.
const _experienceYears = [1, 3, 7, 12];
const _radiiKm = [5, 10, 20, 30];
const _feesDzd = [0, 300, 500, 800];

int? _bandOf(int? years) => switch (years) {
  null => null,
  < 2 => 0,
  < 5 => 1,
  < 10 => 2,
  _ => 3,
};

/// Setup step 1: who the pro is and where they work. The first save creates
/// the profile; later saves update it.
class ProfileStep extends ConsumerStatefulWidget {
  const ProfileStep({this.incomplete = false, super.key});

  final bool incomplete;

  @override
  ConsumerState<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<ProfileStep> {
  late final TextEditingController _name;
  late final TextEditingController _workplaceName;
  late final ProKind _kind;
  late final Space _space;
  int? _band;
  late WorkplaceType _workplace;
  String? _regionCode;
  int? _localityId;
  CustomerMix? _mix;
  int? _radius;
  int? _fee;
  XFile? _avatar;
  Uint8List? _avatarBytes;
  String? _nameError;
  String? _localityError;
  String? _mixError;
  String? _failure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final account = ref.read(accountProvider).value!;
    final p = ref.read(myProProvider).value;
    _kind = ProKind.forRole(account.activeRole)!;
    _space = p?.space ?? account.currentSpace;
    _name = TextEditingController(text: p?.displayName ?? account.fullName);
    _workplaceName = TextEditingController(text: p?.workplaceName);
    _band = _bandOf(p?.experienceYears);
    _workplace = _kind == ProKind.homeArtist
        ? WorkplaceType.mobile
        : p?.workplaceType ?? WorkplaceType.salon;
    _localityId = p?.localityId;
    _mix = p?.customerMix;
    _radius = p?.serviceRadiusKm;
    _fee = p?.travelFeeDzd;
    final id = _localityId;
    if (id != null) {
      // The picker needs the wilaya to list the saved commune. Without it the
      // commune cannot be shown, so it is asked again rather than saved
      // unseen; a pick made meanwhile wins.
      ref
          .read(localityProvider(id).future)
          .then<void>(
            (l) {
              if (!mounted || _localityId != id) return;
              setState(() {
                if (l == null) {
                  _localityId = null;
                } else {
                  _regionCode = l.regionCode;
                }
              });
            },
            onError: (Object _) {
              if (mounted && _localityId == id) {
                setState(() => _localityId = null);
              }
            },
          );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _workplaceName.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ref.read(avatarPickerProvider)();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatar = file;
      _avatarBytes = bytes;
    });
  }

  bool _validate(AppLocalizations l10n) {
    final name = _name.text.trim().characters.length;
    setState(() {
      _nameError = name == 0
          ? l10n.setupDisplayNameRequired
          : name < 2 || name > 60
          ? l10n.setupDisplayNameLength
          : null;
      _localityError = _localityId == null ? l10n.setupLocalityRequired : null;
      _mixError = _mix == null ? l10n.setupCustomersRequired : null;
      _failure = null;
    });
    return _nameError == null && _localityError == null && _mixError == null;
  }

  Future<void> _continue() async {
    final l10n = context.l10n;
    if (_busy || !_validate(l10n)) return;
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    final failure = await _save();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _failure = proFailureMessage(l10n, failure);
      });
      return;
    }
    router.go('/pro/setup/services');
  }

  Future<ProFailure?> _save() async {
    final name = _name.text.trim();
    if (ref.read(myProProvider).value == null) {
      final failure = await runPro(
        ref,
        (p) => p.create(displayName: name, workplaceType: _workplace),
      );
      if (failure is ProProfileExists) {
        // A retry after a lost response: load the profile and update it.
        ref.invalidate(myProProvider);
        try {
          if (await ref.read(myProProvider.future) == null) {
            return const UnknownProFailure('existing profile not found');
          }
        } on ProFailure catch (e) {
          return e;
        }
      } else if (failure != null) {
        return failure;
      }
    }
    final workplaceName = _workplace == WorkplaceType.mobile
        ? ''
        : _workplaceName.text.trim();
    final band = _band;
    final home = _kind == ProKind.homeArtist;
    final failure = await runPro(
      ref,
      (p) => p.updateProfile(
        ProProfilePatch(
          displayName: name,
          experienceYears: band == null ? null : _experienceYears[band],
          workplaceType: _workplace,
          workplaceName: workplaceName.isEmpty ? null : workplaceName,
          localityId: _localityId,
          customerMix: _mix,
          serviceRadiusKm: home ? _radius : null,
          travelFeeDzd: home ? _fee : null,
          clear: {
            if (workplaceName.isEmpty) PatchField.workplaceName,
            if (band == null) PatchField.experienceYears,
            if (!home || _radius == null) PatchField.serviceRadiusKm,
            if (!home || _fee == null) PatchField.travelFeeDzd,
          },
        ),
      ),
    );
    if (failure != null) return failure;
    final avatar = _avatar;
    if (avatar == null) return null;
    final upload = await runPro(ref, (p) => p.uploadAvatar(avatar));
    if (upload == null) _avatar = null;
    return upload;
  }

  void _leave() {
    ref.read(signupJustCompletedProvider.notifier).set(false);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final space = _space.toDb();
    final profile = ref.watch(myProProvider).value;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );
    Widget error(String? text) => text == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          );

    return SetupStepScaffold(
      index: 0,
      title: l10n.setupProfileTitle,
      body: l10n.setupProfileBody(space),
      onBack: _leave,
      action: LemqesPrimaryButton(
        key: const Key('setupContinue'),
        label: l10n.actionContinue,
        expand: true,
        loading: _busy,
        onPressed: _busy ? null : _continue,
      ),
      children: [
        if (widget.incomplete) ...[
          FailureBanner(message: l10n.setupIncomplete),
          const SizedBox(height: 16),
        ],
        if (_failure != null) ...[
          FailureBanner(message: _failure!),
          const SizedBox(height: 16),
        ],
        _AvatarPicker(
          name: _name.text,
          bytes: _avatarBytes,
          url: profile?.avatarPath == null
              ? null
              : ref
                    .read(photoUploaderProvider)
                    .publicUrl(avatarsBucket, profile!.avatarPath!),
          onPick: _busy ? null : _pickAvatar,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('displayNameField'),
          controller: _name,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: lemqesFieldDecoration(
            context,
            label: l10n.setupDisplayNameLabel,
            error: _nameError,
            icon: Icons.badge_outlined,
          ).copyWith(counterText: ''),
        ),
        section(l10n.setupExperienceLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var b = 0; b < _experienceYears.length; b++)
              ChoiceChip(
                key: Key('experience_$b'),
                label: Text(l10n.setupExperienceBand('b$b')),
                selected: _band == b,
                onSelected: (on) => setState(() => _band = on ? b : null),
              ),
          ],
        ),
        if (_kind == ProKind.barber) ...[
          section(l10n.setupWorkplaceLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in WorkplaceType.values)
                ChoiceChip(
                  key: Key('workplace_${t.toDb()}'),
                  label: Text(l10n.setupWorkplaceType(t.toDb())),
                  selected: _workplace == t,
                  onSelected: (_) => setState(() => _workplace = t),
                ),
            ],
          ),
          if (_workplace != WorkplaceType.mobile) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('workplaceNameField'),
              controller: _workplaceName,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: lemqesFieldDecoration(
                context,
                label: l10n.setupWorkplaceNameLabel,
                icon: Icons.storefront_outlined,
              ).copyWith(counterText: ''),
            ),
          ],
        ],
        section(l10n.setupLocalityLabel),
        LocalityPicker(
          country: 'DZ',
          regionCode: _regionCode,
          localityId: _localityId,
          onChanged: (region, locality) => setState(() {
            _regionCode = region;
            _localityId = locality;
            _localityError = null;
          }),
        ),
        error(_localityError),
        section(l10n.setupCustomersLabel),
        for (final (mix, title, icon) in [
          (
            CustomerMix.adults,
            l10n.customerMixAdults(space),
            Icons.person_outline,
          ),
          (
            CustomerMix.adultsAndKids,
            l10n.customerMixAdultsAndKids(space),
            Icons.family_restroom,
          ),
          (CustomerMix.kidsOnly, l10n.customerMixKidsOnly, Icons.child_care),
        ]) ...[
          ChoiceCard(
            key: Key('mix_${mix.toDb()}'),
            title: title,
            icon: icon,
            selected: _mix == mix,
            onTap: () => setState(() {
              _mix = mix;
              _mixError = null;
            }),
          ),
          const SizedBox(height: 12),
        ],
        error(_mixError),
        if (_kind == ProKind.homeArtist) ...[
          section(l10n.setupRadiusLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final km in _radiiKm)
                ChoiceChip(
                  key: Key('radius_$km'),
                  label: Text(l10n.setupRadiusKm(km)),
                  selected: _radius == km,
                  onSelected: (on) => setState(() => _radius = on ? km : null),
                ),
            ],
          ),
          section(l10n.setupTravelFeeLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fee in _feesDzd)
                ChoiceChip(
                  key: Key('fee_$fee'),
                  label: fee == 0
                      ? Text(l10n.setupTravelFeeFree)
                      : Ltr(child: Text(formatDzd(fee, locale))),
                  selected: _fee == fee,
                  onSelected: (on) => setState(() => _fee = on ? fee : null),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A round photo (or initials) with the add / change action under it.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.bytes,
    required this.url,
    required this.onPick,
  });

  final String name;
  final Uint8List? bytes;
  final String? url;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bytes = this.bytes;
    final url = this.url;
    final initials = name.trim().isEmpty
        ? ''
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w.characters.first)
              .join();
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes)
        : url != null
        ? NetworkImage(url)
        : null;
    final has = image != null;
    return Column(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: scheme.secondaryContainer,
            foregroundImage: image,
            child: Text(
              initials.toUpperCase(),
              style: theme.textTheme.headlineSmall!.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('avatarPick'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: Icon(
            has ? Icons.photo_camera_outlined : Icons.add_a_photo_outlined,
          ),
          label: Text(has ? l10n.setupAvatarChange : l10n.setupAvatarAdd),
          onPressed: onPick,
        ),
      ],
    );
  }
}
