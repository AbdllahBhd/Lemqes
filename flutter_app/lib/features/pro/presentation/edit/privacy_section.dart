import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../explore/presentation/pro_labels.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';

/// Who sees the phone number (public / hidden; followers-only is stored but
/// arrives with follows, so it is offered as "soon") and whether prices
/// show. Each change sends only its own field.
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({required this.profile, super.key});

  final ProProfile profile;

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  // The choice being saved, shown at once; cleared when the save settles,
  // so a failure falls back to the stored value.
  PhoneVisibility? _phone;
  bool? _showPrices;

  bool get _saving => _phone != null || _showPrices != null;

  Future<void> _setPhone(PhoneVisibility v) async {
    if (_saving || v == widget.profile.phoneVisibility) return;
    setState(() => _phone = v);
    await ref
        .read(myProProvider.notifier)
        .updateProfile(ProProfilePatch(phoneVisibility: v));
    if (mounted) setState(() => _phone = null);
  }

  Future<void> _setShowPrices(bool v) async {
    if (_saving) return;
    setState(() => _showPrices = v);
    await ref
        .read(myProProvider.notifier)
        .updateProfile(ProProfilePatch(showPrices: v));
    if (mounted) setState(() => _showPrices = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final phone = _phone ?? widget.profile.phoneVisibility;
    final showPrices = _showPrices ?? widget.profile.showPrices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.privacyPhoneLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final (v, label) in [
          (PhoneVisibility.public, l10n.privacyPhonePublic),
          (PhoneVisibility.hidden, l10n.privacyPhoneHidden),
          (PhoneVisibility.followers, l10n.privacyPhoneFollowers),
        ])
          _RadioRow(
            key: Key('phone_${v.toDb()}'),
            label: label,
            selected: phone == v,
            soon: v == PhoneVisibility.followers,
            onTap: v == PhoneVisibility.followers ? null : () => _setPhone(v),
          ),
        Divider(height: 24, color: theme.colorScheme.outlineVariant),
        SwitchListTile(
          key: const Key('showPricesSwitch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.privacyShowPrices),
          subtitle: Text(
            l10n.privacyShowPricesHint(widget.profile.workplaceType.toDb()),
          ),
          value: showPrices,
          onChanged: _setShowPrices,
        ),
      ],
    );
  }
}

/// One choice of a single-choice group; [onTap] null when it cannot be
/// picked yet ([soon] adds the "soon" tag).
class _RadioRow extends StatelessWidget {
  const _RadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.soon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool soon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: !enabled
                      ? scheme.onSurfaceVariant
                      : selected
                      ? scheme.primary
                      : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (soon) ...[
                  const SizedBox(width: 8),
                  MistTag(context.l10n.privacySoon),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
