import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../account/presentation/space_switch.dart';
import 'home_header.dart';

/// Customer home: the header band, then the search that M2 will bring.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final space = account.customerSpace;
    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Wordmark(),
                const SizedBox(width: 12),
                Flexible(
                  child: BandTag(label: l10n.homeSpaceLabel(space.toDb())),
                ),
              ],
            ),
            children: [
              SpaceSwitch(
                value: space,
                onChanged: (s) {
                  if (s != space) {
                    ref.read(accountProvider.notifier).switchSpace(s);
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: EmptyView(
              title: l10n.homeCustomerEmptyTitle(space.toDb()),
              body: l10n.homeCustomerEmptyBody,
            ),
          ),
        ],
      ),
    );
  }
}
