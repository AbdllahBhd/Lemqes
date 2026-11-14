import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/choice_card.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../account/data/account.dart';
import '../../data/signup_draft_store.dart';
import '../signup_completion.dart';
import '../signup_wizard.dart';

/// Step 1: the men's or the women's space.
class SpaceStep extends ConsumerWidget {
  const SpaceStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final space = ref.watch(signupDraftProvider)?.space;
    // Signed in without a profile, there is no sign-in screen to go back to.
    final signedIn = watchHasSession(ref);
    void choose(Space s) => ref
        .read(signupDraftProvider.notifier)
        .update((d) => d.copyWith(space: s));

    return WizardStepScaffold(
      step: 1,
      title: l10n.spaceStepTitle,
      body: l10n.spaceStepBody,
      onBack: signedIn ? null : () => context.go('/auth'),
      action: LemqesPrimaryButton(
        key: const Key('primaryAction'),
        label: l10n.actionContinue,
        expand: true,
        onPressed: space == null ? null : () => context.go('/signup/role'),
      ),
      children: [
        ChoiceCard(
          key: const Key('space_men'),
          title: l10n.spaceMen,
          subtitle: l10n.spaceMenBody,
          icon: Icons.man,
          selected: space == Space.men,
          onTap: () => choose(Space.men),
        ),
        const SizedBox(height: 12),
        ChoiceCard(
          key: const Key('space_women'),
          title: l10n.spaceWomen,
          subtitle: l10n.spaceWomenBody,
          icon: Icons.woman,
          selected: space == Space.women,
          onTap: () => choose(Space.women),
        ),
      ],
    );
  }
}
