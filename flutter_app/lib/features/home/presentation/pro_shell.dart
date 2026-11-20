import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../account/data/account.dart';
import '../../live/presentation/today/today_screen.dart';
import '../../pro/presentation/dashboard/pro_dashboard_screen.dart';

enum ProTab { today, profile }

/// The pro's current tab; kept while the app runs so a rebuild of the home
/// does not throw the barber back to Today.
final proTabProvider = NotifierProvider<ProTabController, ProTab>(
  ProTabController.new,
);

class ProTabController extends Notifier<ProTab> {
  ProTabController([this.initial = ProTab.today]);

  final ProTab initial;

  @override
  ProTab build() => initial;

  void select(ProTab tab) => state = tab;
}

/// The pro home: "Aujourd'hui" (live status and queue) and "Mon profil"
/// (the M2 dashboard), with a bottom navigation bar.
class ProShell extends ConsumerWidget {
  const ProShell({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tab = ref.watch(proTabProvider);
    return Scaffold(
      body: switch (tab) {
        ProTab.today => TodayScreen(account: account),
        ProTab.profile => ProDashboardScreen(account: account),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) =>
            ref.read(proTabProvider.notifier).select(ProTab.values[i]),
        destinations: [
          NavigationDestination(
            key: const Key('proNavToday'),
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule),
            label: l10n.proNavToday,
          ),
          NavigationDestination(
            key: const Key('proNavProfile'),
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.proNavProfile,
          ),
        ],
      ),
    );
  }
}
