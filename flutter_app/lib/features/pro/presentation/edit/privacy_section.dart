import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../auth/data/phone_number.dart';
import '../../../auth/presentation/auth_fields.dart';
import '../../../auth/presentation/auth_widgets.dart' show formatAlgerianPhone;
import '../../../explore/presentation/pro_labels.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';

/// Who sees the phone number (public / hidden; followers-only is stored but
/// arrives with follows, so it is offered as "soon") and whether prices
/// show. Each change sends only its own field; making the phone public sends
/// the contact number with it, since the database refuses one without the
/// other.
///
/// The public number is a contact number the pro types here, never the
/// login number: customers choose their space themselves, so whoever can
/// read it is not a vetted audience.
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

  /// Non-null while the contact number field is open.
  TextEditingController? _number;
  String? _numberError;

  bool get _saving => _phone != null || _showPrices != null;

  @override
  void dispose() {
    _number?.dispose();
    super.dispose();
  }

  void _openNumber() {
    final stored = widget.profile.contactPhone;
    setState(() {
      _number?.dispose();
      // Never prefilled with the login number: only a number typed here
      // before (kept when the phone was hidden).
      _number = TextEditingController(
        text: stored == null ? '' : formatAlgerianPhone(stored),
      );
      _numberError = null;
    });
  }

  void _closeNumber() {
    setState(() {
      _number?.dispose();
      _number = null;
      _numberError = null;
    });
  }

  Future<void> _saveNumber() async {
    final field = _number;
    if (_saving || field == null) return;
    final l10n = context.l10n;
    final text = field.text.trim();
    final e164 = text.isEmpty ? null : normalizeAlgerianMobile(text);
    if (e164 == null) {
      setState(
        () => _numberError = text.isEmpty
            ? l10n.phoneRequired
            : l10n.phoneInvalid,
      );
      return;
    }
    setState(() {
      _numberError = null;
      _phone = PhoneVisibility.public;
    });
    final failure = await ref
        .read(myProProvider.notifier)
        .updateProfile(
          ProProfilePatch(
            phoneVisibility: PhoneVisibility.public,
            contactPhone: e164,
          ),
        );
    if (!mounted) return;
    setState(() => _phone = null);
    // On failure the field stays open with the typed number, so a retry is
    // one tap; the failure itself is reported by the dashboard.
    if (failure == null) _closeNumber();
  }

  Future<void> _setPhone(PhoneVisibility v) async {
    if (_saving) return;
    if (v == PhoneVisibility.public) {
      if (widget.profile.phoneVisibility != v && _number == null) {
        _openNumber();
      }
      return;
    }
    if (_number != null) _closeNumber();
    if (v == widget.profile.phoneVisibility) return;
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
    final number = _number;
    final phone =
        _phone ??
        (number != null
            ? PhoneVisibility.public
            : widget.profile.phoneVisibility);
    final showPrices = _showPrices ?? widget.profile.showPrices;
    final stored = widget.profile.contactPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.privacyPhoneLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final (v, label) in [
          (PhoneVisibility.public, l10n.privacyPhonePublic),
          (PhoneVisibility.hidden, l10n.privacyPhoneHidden),
          (PhoneVisibility.followers, l10n.privacyPhoneFollowers),
        ]) ...[
          _RadioRow(
            key: Key('phone_${v.toDb()}'),
            label: label,
            selected: phone == v,
            soon: v == PhoneVisibility.followers,
            onTap: v == PhoneVisibility.followers ? null : () => _setPhone(v),
          ),
          if (v == PhoneVisibility.public && number != null)
            _NumberEditor(
              controller: number,
              error: _numberError,
              saving: _saving,
              onSave: _saveNumber,
              onCancel: _closeNumber,
            )
          else if (v == PhoneVisibility.public &&
              phone == PhoneVisibility.public &&
              _phone == null &&
              stored != null)
            _StoredNumber(phone: stored, onEdit: _openNumber),
        ],
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

/// The public contact number, under the "Visible" choice, with a way to
/// change it.
class _StoredNumber extends StatelessWidget {
  const _StoredNumber({required this.phone, required this.onEdit});

  final String phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 36),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Ltr(
                child: Text(
                  formatAlgerianPhone(phone),
                  key: const Key('contactPhoneNumber'),
                  style: lemqesWeight(
                    theme.textTheme.bodyLarge!.merge(lemqesNumeric),
                    FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            key: const Key('contactPhoneEdit'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onEdit,
            child: Text(context.l10n.privacyContactPhoneEdit),
          ),
        ],
      ),
    );
  }
}

/// The contact number field: the same parser and errors as sign-up.
class _NumberEditor extends StatelessWidget {
  const _NumberEditor({
    required this.controller,
    required this.error,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final String? error;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 36, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('contactPhoneField'),
            controller: controller,
            enabled: !saving,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp('[0-9\u0660-\u0669\u06F0-\u06F9+ ]'),
              ),
            ],
            onSubmitted: (_) => onSave(),
            decoration: lemqesFieldDecoration(
              context,
              label: l10n.privacyContactPhoneLabel,
              hint: l10n.phoneHint,
              helper: l10n.privacyContactPhoneHelp,
              error: error,
              icon: Icons.phone_outlined,
            ).copyWith(hintTextDirection: TextDirection.ltr),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('contactPhoneCancel'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: saving ? null : onCancel,
                child: Text(l10n.actionCancel),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('contactPhoneSave'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  shape: const StadiumBorder(),
                ),
                onPressed: saving ? null : onSave,
                child: Text(l10n.dashboardSave),
              ),
            ],
          ),
        ],
      ),
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
