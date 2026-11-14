import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/step_progress.dart';
import '../../account/data/account.dart';
import '../data/signup_draft_store.dart';
import 'steps/code_step.dart';
import 'steps/credentials_step.dart';
import 'steps/role_step.dart';
import 'steps/space_step.dart';

/// `/signup/:step`. Steps 4-5 for pros (profile, hours) arrive in M2; until
/// then pros land on home after the code step.
class SignupWizard extends StatelessWidget {
  const SignupWizard({required this.step, super.key});

  final String step;

  @override
  Widget build(BuildContext context) => switch (step) {
    'role' => const RoleStep(),
    'credentials' => const CredentialsStep(),
    'code' => const CodeStep(),
    _ => const SpaceStep(),
  };
}

/// The frame every wizard step shares: back, progress, title, scrolling
/// content, and the step's one primary action pinned under the thumb.
class WizardStepScaffold extends ConsumerWidget {
  const WizardStepScaffold({
    required this.step,
    required this.title,
    required this.children,
    this.body,
    this.onBack,
    this.action,
    super.key,
  });

  final int step;
  final String title;
  final String? body;
  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = ref.watch(signupDraftProvider)?.role;
    final total = role != null && role.isPro ? 5 : 4;
    final body = this.body;
    final action = this.action;
    final onBack = this.onBack;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 24, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: const BackButtonIcon(),
                      onPressed: onBack,
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: StepProgress(step: step, total: total),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                    ...children,
                  ],
                ),
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}

/// The icon on each role card.
extension SignupRoleIcon on AppRole {
  IconData get icon => switch (this) {
    AppRole.customer => Icons.person_outline,
    AppRole.barber => Icons.content_cut,
    AppRole.homeArtist => Icons.home_work_outlined,
    AppRole.salonOwner => Icons.storefront_outlined,
  };
}
