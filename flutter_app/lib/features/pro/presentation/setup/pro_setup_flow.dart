import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/router/redirect.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../signup/presentation/signup_completion.dart';
import '../../../signup/presentation/signup_wizard.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_providers.dart';
import 'hours_step.dart';
import 'profile_step.dart';
import 'services_step.dart';

/// `/pro/setup/:step`: profile, services, hours for the active pro role.
class ProSetupScreen extends ConsumerWidget {
  const ProSetupScreen({
    required this.step,
    this.incomplete = false,
    super.key,
  });

  final String step;

  /// Publishing was refused because this step is unfinished.
  final bool incomplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(myProProvider);
    // A failed save keeps the profile in `value`; only a first load that
    // never produced one needs the error view.
    if (!state.hasValue) {
      return Scaffold(
        body: SafeArea(
          child: state.hasError
              ? ErrorView(
                  message: l10n.errorGeneric,
                  retryLabel: l10n.actionRetry,
                  onRetry: () => ref.invalidate(myProProvider),
                )
              : LoadingView(label: l10n.loading),
        ),
      );
    }
    return switch (step) {
      'services' => ServicesStep(incomplete: incomplete),
      'hours' => HoursStep(incomplete: incomplete),
      _ => ProfileStep(incomplete: incomplete),
    };
  }
}

/// `/pro/setup` before the profile has loaded; the route redirect then
/// resumes at the first step with a gap.
class ProSetupEntryScreen extends ConsumerWidget {
  const ProSetupEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(myProProvider);
    return Scaffold(
      body: SafeArea(child: LoadingView(label: context.l10n.loading)),
    );
  }
}

/// The wizard frame for setup step [index] (0-based): after sign-up the
/// count carries on the wizard's (5-7 of 7), otherwise setup counts its own.
class SetupStepScaffold extends ConsumerWidget {
  const SetupStepScaffold({
    required this.index,
    required this.title,
    required this.children,
    required this.action,
    this.body,
    this.onBack,
    super.key,
  });

  final int index;
  final String title;
  final String? body;
  final List<Widget> children;
  final Widget action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

/// Runs a [MyProController] action and returns its failure, or null when it
/// went through: the controller reports failures through its state only.
Future<ProFailure?> runPro(
  WidgetRef ref,
  Future<void> Function(MyProController pro) action,
) async {
  await action(ref.read(myProProvider.notifier));
  final state = ref.read(myProProvider);
  if (!state.hasError) return null;
  final error = state.error;
  return error is ProFailure ? error : UnknownProFailure('$error');
}
