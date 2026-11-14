import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../account/data/account.dart';
import '../../../account/data/account_providers.dart';
import '../../../account/data/account_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/phone_number.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../data/signup_draft.dart';
import '../../data/signup_draft_store.dart';
import '../signup_completion.dart';
import '../signup_wizard.dart';

/// Step 3: names, then phone and password to receive the code.
///
/// Signed in already (phone verified, profile missing), only the names are
/// asked and the profile is created directly.
class CredentialsStep extends ConsumerStatefulWidget {
  const CredentialsStep({super.key});

  @override
  ConsumerState<CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends ConsumerState<CredentialsStep> {
  late final TextEditingController _business;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _businessError;
  String? _nameError;
  String? _phoneError;
  String? _passwordError;
  String? _failure;
  bool _alreadyRegistered = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(signupDraftProvider);
    final phone = draft?.phone;
    _business = TextEditingController(text: draft?.businessName);
    _name = TextEditingController(text: draft?.fullName);
    _phone = TextEditingController(
      text: phone == null ? null : '0${phone.substring(4)}',
    );
  }

  @override
  void dispose() {
    for (final c in [_business, _name, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ownsSalon =>
      ref.read(signupDraftProvider)?.role == AppRole.salonOwner;

  bool _validateNames() {
    final l10n = context.l10n;
    _businessError = _ownsSalon && _business.text.trim().isEmpty
        ? l10n.businessNameRequired
        : null;
    _nameError = _name.text.trim().isEmpty ? l10n.fullNameRequired : null;
    return _businessError == null && _nameError == null;
  }

  void _saveNames(SignupDraftController drafts, {String? phone}) {
    final business = _business.text.trim();
    drafts.update(
      (d) => d.copyWith(
        fullName: _name.text.trim(),
        businessName: _ownsSalon && business.isNotEmpty ? business : null,
        phone: phone,
      ),
    );
  }

  Future<void> _submit({required bool signedIn}) async {
    if (_loading) return;
    final l10n = context.l10n;
    final drafts = ref.read(signupDraftProvider.notifier);
    setState(() {
      _failure = null;
      _alreadyRegistered = false;
    });

    if (signedIn) {
      setState(_validateNames);
      if (_businessError != null || _nameError != null) return;
      _saveNames(drafts);
      setState(() => _loading = true);
      try {
        await ref.read(signupCompletionProvider.notifier).finish();
      } on AccountFailure catch (failure) {
        if (mounted) {
          setState(() => _failure = accountFailureMessage(l10n, failure));
        }
      } on IncompleteSignupDraft {
        // Space or role is missing; the route guard normally prevents this.
        if (mounted) setState(() => _failure = l10n.errorGeneric);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    final phone = normalizeAlgerianMobile(_phone.text);
    setState(() {
      _validateNames();
      _phoneError = _phone.text.trim().isEmpty
          ? l10n.phoneRequired
          : phone == null
          ? l10n.phoneInvalid
          : null;
      _passwordError = _password.text.length < 8 ? l10n.passwordTooShort : null;
    });
    final matches = _password.text == _confirm.text;
    if (_businessError != null ||
        _nameError != null ||
        phone == null ||
        _passwordError != null ||
        !matches) {
      return;
    }

    // Saved before the request: if the app dies mid-call, sign-up resumes at
    // the code step.
    _saveNames(drafts, phone: phone);
    final auth = ref.read(authRepositoryProvider);
    final router = GoRouter.of(context);
    setState(() => _loading = true);
    try {
      await auth.signUp(phone: phone, password: _password.text);
      router.go('/signup/code');
    } on AuthFailure catch (failure) {
      // No code is on its way: a restart must come back here, not to the code.
      drafts.update(
        (d) => SignupDraft(
          space: d.space,
          role: d.role,
          fullName: d.fullName,
          businessName: d.businessName,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (failure is WeakPassword) {
          _passwordError = l10n.passwordWeak;
        } else {
          _alreadyRegistered = failure is PhoneAlreadyRegistered;
          _failure = authFailureMessage(l10n, failure);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(signupDraftProvider);
    final space = (draft?.space ?? Space.men).toDb();
    final signedIn = watchHasSession(ref);
    final failure = _failure;
    final enabled = !_loading;

    return WizardStepScaffold(
      step: 3,
      title: l10n.credentialsStepTitle,
      body: signedIn ? l10n.credentialsProfileBody : l10n.credentialsStepBody,
      onBack: () => context.go('/signup/role'),
      action: LemqesPrimaryButton(
        key: const Key('primaryAction'),
        label: signedIn ? l10n.profileSubmit : l10n.credentialsSubmit,
        icon: signedIn ? Icons.check : Icons.sms_outlined,
        expand: true,
        loading: _loading,
        onPressed: () => _submit(signedIn: signedIn),
      ),
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (draft?.role == AppRole.salonOwner) ...[
                TextField(
                  key: const Key('businessNameField'),
                  controller: _business,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.organizationName],
                  decoration: lemqesFieldDecoration(
                    context,
                    label: l10n.businessNameLabel(space),
                    error: _businessError,
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('nameField'),
                controller: _name,
                enabled: enabled,
                textCapitalization: TextCapitalization.words,
                textInputAction: signedIn
                    ? TextInputAction.done
                    : TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: lemqesFieldDecoration(
                  context,
                  label: l10n.fullNameLabel,
                  error: _nameError,
                  icon: Icons.badge_outlined,
                ),
              ),
              if (!signedIn) ...[
                const SizedBox(height: 16),
                PhoneField(
                  controller: _phone,
                  error: _phoneError,
                  enabled: enabled,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  fieldKey: const Key('passwordField'),
                  label: l10n.passwordLabel,
                  helper: l10n.passwordHelper,
                  error: _passwordError,
                  enabled: enabled,
                  newPassword: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  fieldKey: const Key('confirmField'),
                  label: l10n.confirmLabel,
                  enabled: enabled,
                  newPassword: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(signedIn: false),
                ),
                PasswordMatchHint(
                  password: _password.text,
                  confirm: _confirm.text,
                ),
              ],
            ],
          ),
        ),
        if (failure != null) ...[
          const SizedBox(height: 16),
          FailureBanner(
            message: failure,
            actions: [
              if (_alreadyRegistered) ...[
                BannerAction(
                  key: const Key('alreadyRegisteredSignIn'),
                  label: l10n.actionSignIn,
                  onPressed: () => context.go('/auth'),
                ),
                BannerAction(
                  key: const Key('alreadyRegisteredReset'),
                  label: l10n.actionResetPassword,
                  onPressed: () => context.go('/auth/reset'),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
