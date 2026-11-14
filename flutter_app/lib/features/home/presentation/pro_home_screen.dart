import 'package:flutter/material.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_theme.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account.dart';
import 'home_header.dart';

/// Pro home: the name and the fixed space on the band, setup to come in M2.
class ProHomeScreen extends StatelessWidget {
  const ProHomeScreen({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final space = account.currentSpace.toDb();
    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            title: Semantics(
              header: true,
              child: Text(
                account.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: lemqesWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.w600,
                ).copyWith(color: Colors.white),
              ),
            ),
            children: [
              Row(
                children: [
                  BandTag(label: l10n.homeSpaceLabel(space)),
                  Tooltip(
                    message: l10n.proSpaceFixedHint,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Semantics(
                      button: true,
                      label: l10n.proSpaceFixedHint,
                      excludeSemantics: true,
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.info_outline, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: EmptyView(
              title: l10n.homeProEmptyTitle,
              body: l10n.homeProEmptyBody,
              action: LemqesPrimaryButton(
                key: const Key('completeProfile'),
                label: l10n.homeProEmptyAction,
                onPressed: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
