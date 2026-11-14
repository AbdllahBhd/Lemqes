import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../account/data/account_repository.dart';
import '../data/auth_repository.dart';

export 'auth_fields.dart';

/// Material's `login` glyph, mirrored in right-to-left layouts: the arrow
/// points into the door in the reading direction.
const IconData loginIcon = IconData(
  0xe3b2,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);

/// The words for an auth failure; never the raw exception.
String authFailureMessage(AppLocalizations l10n, AuthFailure failure) =>
    switch (failure) {
      InvalidCredentials() => l10n.errorInvalidCredentials,
      PhoneAlreadyRegistered() => l10n.phoneAlreadyRegistered,
      PhoneNotRegistered() => l10n.resetNoAccount,
      InvalidOrExpiredCode() => l10n.codeInvalid,
      RateLimited(:final retryAfter) =>
        retryAfter == null
            ? l10n.errorRateLimitedLater
            : l10n.errorRateLimited(retryAfter.inSeconds),
      WeakPassword() => l10n.passwordWeak,
      NetworkFailure() => l10n.errorNetwork,
      UnknownAuthFailure() => l10n.errorGeneric,
    };

String accountFailureMessage(AppLocalizations l10n, AccountFailure failure) =>
    failure is NetworkAccountFailure ? l10n.errorNetwork : l10n.errorGeneric;

/// `+213550123456` as `+213 550 12 34 56`, for display only.
String formatAlgerianPhone(String e164) {
  if (!e164.startsWith('+213') || e164.length != 13) return e164;
  final n = e164.substring(4);
  return '+213 ${n.substring(0, 3)} ${n.substring(3, 5)} '
      '${n.substring(5, 7)} ${n.substring(7)}';
}

/// A failure named in words, with optional ways out.
class FailureBanner extends StatelessWidget {
  const FailureBanner({
    required this.message,
    this.actions = const [],
    super.key,
  });

  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A text button on a failure banner, in the banner's ink.
class BannerAction extends StatelessWidget {
  const BannerAction({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onErrorContainer,
        minimumSize: const Size(48, 48),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(decoration: TextDecoration.underline),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// "Resend the code", locked for [cooldown] after each send.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    required this.onResend,
    this.cooldown = const Duration(seconds: 60),
    super.key,
  });

  /// Sends a new code; returns how long to wait before the next one, or
  /// null for the usual [cooldown].
  final Future<Duration?> Function() onResend;
  final Duration cooldown;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _start(widget.cooldown);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(Duration wait) {
    _timer?.cancel();
    setState(() => _secondsLeft = wait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _resend() async {
    _start(widget.cooldown);
    final wait = await widget.onResend();
    if (mounted && wait != null) _start(wait);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = _secondsLeft > 0;
    return TextButton.icon(
      key: const Key('resendCode'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: locked ? null : _resend,
      icon: const Icon(Icons.sms_outlined),
      label: Text(locked ? l10n.codeResendIn(_secondsLeft) : l10n.codeResend),
    );
  }
}
