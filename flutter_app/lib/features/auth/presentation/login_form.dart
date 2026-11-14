import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../account/data/account_providers.dart';
import '../data/auth_repository.dart';
import '../data/phone_number.dart';
import 'auth_widgets.dart';

/// Phone + password sign-in. On success the session change moves the router.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _phoneError;
  String? _passwordError;
  String? _failure;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final l10n = context.l10n;
    final phone = normalizeAlgerianMobile(_phone.text);
    setState(() {
      _phoneError = _phone.text.trim().isEmpty
          ? l10n.phoneRequired
          : phone == null
          ? l10n.phoneInvalid
          : null;
      _passwordError = _password.text.isEmpty ? l10n.passwordRequired : null;
      _failure = null;
    });
    if (phone == null || _passwordError != null) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(phone: phone, password: _password.text);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = authFailureMessage(l10n, failure));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = _failure;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhoneField(
            controller: _phone,
            error: _phoneError,
            enabled: !_loading,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _password,
            fieldKey: const Key('passwordField'),
            label: l10n.passwordLabel,
            error: _passwordError,
            enabled: !_loading,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('forgotPassword'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _loading ? null : () => context.go('/auth/reset'),
              child: Text(l10n.forgotPassword),
            ),
          ),
          if (failure != null) ...[
            FailureBanner(message: failure),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 8),
          LemqesPrimaryButton(
            key: const Key('primaryAction'),
            label: l10n.actionSignIn,
            icon: loginIcon,
            expand: true,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
