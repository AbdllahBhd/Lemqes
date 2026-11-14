import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/router/redirect.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../signup/presentation/signup_completion.dart';
import '../../../signup/presentation/signup_wizard.dart';
import '../../../account/data/account_providers.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../pro_failure_message.dart';
import 'hours_step.dart';
import 'profile_step.dart';
import 'services_step.dart';

/// `/pro/setup/:step`: profile, services, hours for the active pro role.
class ProSetupScreen extends ConsumerWidget {
  const ProSetupScreen({
    required this.step,
    this.incomplete = false,
    this.edit = false,
    super.key,
  });

  final String step;

  /// Publishing was refused because this step is unfinished.
  final bool incomplete;

  /// Opened from the dashboard to edit the profile: saving returns home.
  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProProvider);
    final role = ref.watch(accountProvider.select((a) => a.value?.activeRole));
    final kind = role == null ? null : ProKind.forRole(role);
    final profile = state.value;
    // After a role switch the value is the previous role's profile until the
    // reload lands; it must never prefill this role's steps. A failed save
    // keeps the profile in `value`, so only a load that never produced one
    // needs the error view. A role without a pro kind (just switched to
    // customer or salon owner) has no setup: the redirect takes it home.
    if (kind == null ||
        !state.hasValue ||
        (profile != null && profile.kind != kind)) {
      return _ProfileLoading(state: state);
    }
    // Keyed by role so a step's form never outlives the role it was for.
    return KeyedSubtree(
      key: ValueKey(kind),
      child: switch (step) {
        'services' => ServicesStep(incomplete: incomplete),
        'hours' => HoursStep(incomplete: incomplete),
        _ => ProfileStep(incomplete: incomplete, edit: edit),
      },
    );
  }
}

/// Loading, or the error view with a retry when the load failed.
class _ProfileLoading extends ConsumerWidget {
  const _ProfileLoading({required this.state});

  final AsyncValue<ProProfile?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: state.hasError && !state.isLoading
            ? ErrorView(
                message: proFailureMessage(l10n, state.error),
                retryLabel: l10n.actionRetry,
                onRetry: () => ref.invalidate(myProProvider),
              )
            : LoadingView(label: l10n.loading),
      ),
    );
  }
}

/// `/pro/setup` before the profile has loaded; the route redirect then
/// resumes at the first step with a gap.
class ProSetupEntryScreen extends ConsumerWidget {
  const ProSetupEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _ProfileLoading(state: ref.watch(myProProvider));
}

/// The wizard frame for setup step [index] (0-based): after sign-up the
/// count carries on the wizard's (5-7 of 7), otherwise setup counts its own.
///
/// [edit] drops the step count: the step is edited on its own, from the
/// dashboard.
class SetupStepScaffold extends ConsumerWidget {
  const SetupStepScaffold({
    required this.index,
    required this.title,
    required this.children,
    required this.action,
    this.body,
    this.onBack,
    this.edit = false,
    super.key,
  });

  final int index;
  final String title;
  final String? body;
  final List<Widget> children;
  final Widget action;
  final VoidCallback? onBack;
  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (edit) {
      return _EditScaffold(
        title: title,
        onBack: onBack,
        action: action,
        children: children,
      );
    }
    final fromSignup = ref.watch(signupJustCompletedProvider);
    final offset = fromSignup ? 4 : 0;
    return WizardStepScaffold(
      step: offset + index + 1,
      total: offset + proSetupSteps.length,
      title: title,
      body: body,
      onBack: onBack,
      action: action,
      children: children,
    );
  }
}

/// One setup step edited alone: back, title, the fields, the save.
class _EditScaffold extends StatelessWidget {
  const _EditScaffold({
    required this.title,
    required this.children,
    required this.action,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final Widget action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 24, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: onBack == null
                    ? const SizedBox(height: 48)
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        icon: const BackButtonIcon(),
                        onPressed: onBack,
                      ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
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

/// Runs a [MyProController] action and returns the write's failure, or null
/// when it went through (a failed reload afterwards is the controller's to
/// report). The setup steps say a failure in place, so it is marked as
/// reported: the dashboard under an edit does not repeat it.
Future<ProFailure?> runPro(
  WidgetRef ref,
  Future<ProFailure?> Function(MyProController pro) action,
) async {
  final pro = ref.read(myProProvider.notifier);
  final failure = await action(pro);
  if (failure != null && ref.context.mounted) pro.reportedInPlace();
  return failure;
}
