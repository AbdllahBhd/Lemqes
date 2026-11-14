import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/lemqes_wordmark.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../account/presentation/space_switch.dart';
import 'home_header.dart';

/// Customer home: the header band, then the search that M2 will bring.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  bool _switching = false;

  Future<void> _switchTo(Space space) async {
    // One write at a time: a second tap mid-flight would race the first.
    if (_switching) return;
    setState(() => _switching = true);
    try {
      await ref.read(accountProvider.notifier).switchSpace(space);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final l10n = context.l10n;
    final space = account.customerSpace;
    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LemqesWordmark(),
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
                  if (s != space) _switchTo(s);
                },
              ),
            ],
          ),
          Expanded(
            child: EmptyView(
              icon: Icons.storefront_outlined,
              title: l10n.homeCustomerEmptyTitle(space.toDb()),
              body: l10n.homeCustomerEmptyBody,
            ),
          ),
        ],
      ),
    );
  }
}
