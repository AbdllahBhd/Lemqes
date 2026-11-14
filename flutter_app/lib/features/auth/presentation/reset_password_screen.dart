import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_theme.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../../shared/widgets/ltr.dart';
import '../../account/data/account_providers.dart';
import '../data/auth_repository.dart';
import '../data/phone_number.dart';
import 'auth_widgets.dart';

enum _Stage { phone, code, password }

/// Phone, then the SMS code (which signs the user in), then a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Stage _stage = _Stage.phone;
  String? _e164;
  String? _phoneError;
  String? _passwordError;
  String? _failure;
  bool _noAccount = false;
  bool _busy = false;
  int _attempt = 0;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Runs [body]; an [AuthFailure] becomes the banner message.
  Future<bool> _run(Future<void> Function() body) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _failure = null;
      _noAccount = false;
    });
    try {
      await body();
      return true;
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _noAccount = failure is PhoneNotRegistered;
          if (failure is WeakPassword) {
            _passwordError = l10n.passwordWeak;
          } else {
            _failure = authFailureMessage(l10n, failure);
          }
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final l10n = context.l10n;
    final phone = normalizeAlgerianMobile(_phone.text);
    setState(() {
      _phoneError = _phone.text.trim().isEmpty
          ? l10n.phoneRequired
          : phone == null
          ? l10n.phoneInvalid
          : null;
    });
    if (phone == null) return;
    if (await _run(() => _auth.sendResetCode(phone)) && mounted) {
      setState(() {
        _e164 = phone;
        _stage = _Stage.code;
      });
    }
  }

  Future<void> _verify(String code) async {
    final phone = _e164;
    if (_busy || phone == null) return;
    final ok = await _run(
      () => _auth.verifyResetCode(phone: phone, code: code),
    );
    if (!mounted) return;
    setState(() {
      if (ok) {
        _stage = _Stage.password;
      } else {
        _attempt++;
      }
    });
  }

  Future<Duration?> _resend() async {
    final phone = _e164;
    if (phone == null) return null;
    Duration? wait;
    await _run(() async {
      try {
        await _auth.sendResetCode(phone);
      } on RateLimited catch (failure) {
        wait = failure.retryAfter;
        rethrow;
      }
    });
    return wait;
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _passwordError = _password.text.length < 8 ? l10n.passwordTooShort : null;
    });
    if (_passwordError != null || _password.text != _confirm.text) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (await _run(() => _auth.setNewPassword(_password.text))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.resetDone)));
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (title, body, action) = switch (_stage) {
      _Stage.phone => (
        l10n.actionResetPassword,
        l10n.resetPhoneBody,
        (l10n.resetSendCode, _sendCode),
      ),
      _Stage.code => (l10n.codeStepTitle, l10n.codeSentTo, null),
      _Stage.password => (
        l10n.resetNewPasswordTitle,
        null,
        (l10n.resetSave, _save),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.headlineSmall),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ..._stageFields(context),
                    if (_failure != null) ...[
                      const SizedBox(height: 16),
                      FailureBanner(
                        message: _failure!,
                        actions: [
                          if (_noAccount)
                            BannerAction(
                              key: const Key('resetCreateAccount'),
                              label: l10n.actionCreateAccount,
                              onPressed: () => context.go('/signup/space'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: LemqesPrimaryButton(
                  key: const Key('primaryAction'),
                  label: action.$1,
                  expand: true,
                  loading: _busy,
                  onPressed: action.$2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stageFields(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    switch (_stage) {
      case _Stage.phone:
        return [
          PhoneField(
            controller: _phone,
            error: _phoneError,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendCode(),
          ),
        ];
      case _Stage.code:
        return [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Ltr(
              child: Text(
                formatAlgerianPhone(_e164 ?? ''),
                style: lemqesNumeric.copyWith(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: ValueKey(_attempt),
            child: CodeField(
              key: const Key('codeField'),
              enabled: !_busy,
              semanticsLabel: l10n.codeLabel,
              onCompleted: _verify,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ResendCodeButton(onResend: _resend),
          ),
        ];
      case _Stage.password:
        return [
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  controller: _password,
                  fieldKey: const Key('passwordField'),
                  label: l10n.newPasswordLabel,
                  helper: l10n.passwordHelper,
                  error: _passwordError,
                  enabled: !_busy,
                  newPassword: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  fieldKey: const Key('confirmField'),
                  label: l10n.confirmLabel,
                  enabled: !_busy,
                  newPassword: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
                PasswordMatchHint(
                  password: _password.text,
                  confirm: _confirm.text,
                ),
              ],
            ),
          ),
        ];
    }
  }
}
