import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/ltr.dart';

/// Outlined field look shared by the auth and sign-up forms.
InputDecoration lemqesFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helper,
  String? error,
  IconData? icon,
  Widget? suffix,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    errorText: error,
    errorMaxLines: 3,
    helperMaxLines: 2,
    floatingLabelBehavior: hint == null
        ? FloatingLabelBehavior.auto
        : FloatingLabelBehavior.always,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    border: border(scheme.outline),
    enabledBorder: border(scheme.outline),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 2),
    disabledBorder: border(scheme.outlineVariant),
  );
}

/// An Algerian mobile number. Always laid out left-to-right.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    this.error,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Ltr(
      child: TextField(
        key: const Key('phoneField'),
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹+ ]')),
        ],
        onSubmitted: onSubmitted,
        decoration: lemqesFieldDecoration(
          context,
          label: l10n.phoneLabel,
          hint: l10n.phoneHint,
          error: error,
          icon: Icons.phone_outlined,
        ),
      ),
    );
  }
}

/// A password with a show / hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    required this.fieldKey,
    this.error,
    this.helper,
    this.enabled = true,
    this.newPassword = false,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Key fieldKey;
  final String? error;
  final String? helper;
  final bool enabled;
  final bool newPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: lemqesFieldDecoration(
        context,
        label: widget.label,
        helper: widget.helper,
        error: widget.error,
        icon: Icons.lock_outline,
        suffix: IconButton(
          tooltip: _obscured ? l10n.passwordShow : l10n.passwordHide,
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Live "the two passwords match / do not match" line under a confirm field.
class PasswordMatchHint extends StatelessWidget {
  const PasswordMatchHint({
    required this.password,
    required this.confirm,
    super.key,
  });

  final String password;
  final String confirm;

  @override
  Widget build(BuildContext context) {
    if (confirm.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final match = password == confirm;
    final color = match ? scheme.primary : scheme.error;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
        child: Row(
          children: [
            Icon(
              match ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                match
                    ? context.l10n.passwordsMatch
                    : context.l10n.passwordsMismatch,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
