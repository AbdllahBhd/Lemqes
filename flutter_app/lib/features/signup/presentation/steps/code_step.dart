import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_theme.dart';
import '../../../../shared/widgets/code_field.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../account/data/account_providers.dart';
import '../../../account/data/account_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../data/signup_draft_store.dart';
import '../signup_completion.dart';
import '../signup_wizard.dart';

/// Step 4: the SMS code. A valid code signs the user in and creates the
/// profile from the draft; the router then moves on to home.
class CodeStep extends ConsumerStatefulWidget {
  const CodeStep({super.key});

  @override
  ConsumerState<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<CodeStep> {
  /// Bumped to rebuild the code field empty after a refused code.
  int _attempt = 0;
  bool _busy = false;
  String? _failure;

  /// Verified but the profile call failed: retry that, not the code.
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // Resumed after verification (the app died before the profile existed);
    // the route guard only lets a signed-in user here with a name saved.
    if (readHasSession(ref) &&
        ref.read(signupDraftProvider)?.fullName != null) {
      _verified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  Future<void> _verify(String code) async {
    final phone = ref.read(signupDraftProvider)?.phone;
    if (_busy || phone == null) return;
    final l10n = context.l10n;
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await auth.verifySignUpCode(phone: phone, code: code);
      _verified = true;
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = authFailureMessage(l10n, failure);
          _attempt++;
          _busy = false;
        });
      }
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final l10n = context.l10n;
    final completion = ref.read(signupCompletionProvider.notifier);
    setState(() {
      _busy = true;
      _verified = true;
      _failure = null;
    });
    try {
      await completion.finish();
    } on AccountFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = accountFailureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Duration?> _resend() async {
    final phone = ref.read(signupDraftProvider)?.phone;
    if (phone == null) return null;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).resendSignUpCode(phone);
      messenger.showSnackBar(SnackBar(content: Text(l10n.codeResent)));
      return null;
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = authFailureMessage(l10n, failure));
      }
      return failure is RateLimited ? failure.retryAfter : null;
    }
  }

  void _backToLogin() {
    ref.read(signupDraftProvider.notifier).clear();
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final phone = ref.watch(signupDraftProvider)?.phone;
    final failure = _failure;

    if (_verified) {
      return Scaffold(
        body: SafeArea(
          child: failure == null
              ? _Finishing(label: l10n.signupFinishing)
              : ErrorView(
                  message: failure,
                  retryLabel: l10n.actionRetry,
                  onRetry: _finish,
                ),
        ),
      );
    }

    return WizardStepScaffold(
      step: 4,
      title: l10n.codeStepTitle,
      onBack: _busy ? null : () => context.go('/signup/credentials'),
      children: [
        Text(
          l10n.codeSentTo,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Ltr(
            child: Text(
              phone == null ? '' : formatAlgerianPhone(phone),
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
        if (_busy)
          _Busy(label: l10n.codeVerifying)
        else if (failure != null)
          FailureBanner(message: failure),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ResendCodeButton(onResend: _resend),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('backToLogin'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _busy ? null : _backToLogin,
            icon: const Icon(Icons.login),
            label: Text(l10n.backToLogin),
          ),
        ),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Finishing extends StatelessWidget {
  const _Finishing({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
