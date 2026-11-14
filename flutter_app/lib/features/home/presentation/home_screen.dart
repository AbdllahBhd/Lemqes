import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account_providers.dart';
import '../../account/presentation/account_failure_listener.dart';
import 'customer_home_screen.dart';
import 'pro_home_screen.dart';

/// The signed-in landing: customer or pro home by the active role.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(accountProvider);

    // The previous account stays on screen after a failed switch (the
    // listener says so in a snackbar); the error view is for a first load
    // that never produced an account.
    final account = state.value;
    if (account == null) {
      if (state.hasError) {
        return Scaffold(
          body: SafeArea(
            child: ErrorView(
              message: accountErrorMessage(l10n, state.error),
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.read(accountProvider.notifier).refresh(),
            ),
          ),
        );
      }
      return const Scaffold(body: SafeArea(child: LoadingView()));
    }
    return AccountFailureListener(
      child: account.activeRole.isPro
          ? ProHomeScreen(account: account)
          : CustomerHomeScreen(account: account),
    );
  }
}
