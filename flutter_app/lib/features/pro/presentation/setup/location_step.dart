import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/router/redirect.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../signup/presentation/signup_completion.dart';
import '../../data/pro_providers.dart';
import '../place/place_picker_screen.dart';

/// Setup step 2, optional: what location customers see. "Plus tard" goes
/// on to the services; the step is never a gap, so a resumed setup skips
/// it.
///
/// With [edit] (from the dashboard) it stands alone and closes on save.
class LocationStep extends ConsumerWidget {
  const LocationStep({this.edit = false, super.key});

  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProProvider).value;
    // The route only opens once the profile exists; a deep link racing its
    // load waits here.
    if (profile == null) {
      return Scaffold(body: LoadingView(label: context.l10n.loading));
    }
    final router = GoRouter.of(context);
    void close() => router.canPop() ? router.pop() : router.go('/home');
    if (edit) {
      return PlacePickerScreen(profile: profile, onDone: close, onBack: close);
    }
    final offset = ref.watch(signupJustCompletedProvider)
        ? signupSteps.length
        : 0;
    void next() => router.go('/pro/setup/services');
    return PlacePickerScreen(
      profile: profile,
      step: offset + proSetupSteps.indexOf('location') + 1,
      total: offset + proSetupSteps.length,
      onDone: next,
      onSkip: next,
      onBack: () => router.go('/pro/setup/profile'),
    );
  }
}
