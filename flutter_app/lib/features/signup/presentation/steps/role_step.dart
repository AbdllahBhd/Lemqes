import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../shared/widgets/choice_card.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../account/data/account.dart';
import '../../data/signup_draft_store.dart';
import '../signup_wizard.dart';

/// Step 2: customer or one of the three pro roles, worded for the space.
///
/// No free-month badge on pro roles: the free month starts at wallet launch.
class RoleStep extends ConsumerWidget {
  const RoleStep({super.key});

  static (String, String) _copy(
    AppLocalizations l10n,
    AppRole role,
    String space,
  ) => switch (role) {
    AppRole.customer => (
      l10n.roleCustomerTitle(space),
      l10n.roleCustomerBody(space),
    ),
    AppRole.barber => (l10n.roleBarberTitle(space), l10n.roleBarberBody(space)),
    AppRole.homeArtist => (
      l10n.roleHomeArtistTitle(space),
      l10n.roleHomeArtistBody(space),
    ),
    AppRole.salonOwner => (
      l10n.roleSalonOwnerTitle(space),
      l10n.roleSalonOwnerBody(space),
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft = ref.watch(signupDraftProvider);
    final space = (draft?.space ?? Space.men).toDb();
    final selected = draft?.role;

    return WizardStepScaffold(
      step: 2,
      title: l10n.roleStepTitle(space),
      onBack: () => context.go('/signup/space'),
      action: LemqesPrimaryButton(
        key: const Key('primaryAction'),
        label: l10n.actionContinue,
        expand: true,
        onPressed: selected == null
            ? null
            : () => context.go('/signup/credentials'),
      ),
      children: [
        for (final role in AppRole.values) ...[
          if (role != AppRole.values.first) const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final (title, body) = _copy(l10n, role, space);
              return ChoiceCard(
                key: Key('role_${role.toDb()}'),
                title: title,
                subtitle: body,
                badge: role == AppRole.customer ? l10n.badgeFree : null,
                icon: role.icon,
                selected: role == selected,
                onTap: () => ref
                    .read(signupDraftProvider.notifier)
                    .update((d) => d.copyWith(role: role)),
              );
            },
          ),
        ],
      ],
    );
  }
}
