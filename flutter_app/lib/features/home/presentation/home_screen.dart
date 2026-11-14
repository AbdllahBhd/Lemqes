import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account_providers.dart';
import '../../account/data/account_repository.dart';
import '../../auth/presentation/auth_widgets.dart';
import 'customer_home_screen.dart';
import 'pro_home_screen.dart';

/// The signed-in landing: customer or pro home by the active role.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(accountProvider);

    // Error first: a failed role or space change keeps the old value, and the
    // user still needs the way to retry.
    if (state.hasError) {
      final failure = state.error;
      return Scaffold(
        body: SafeArea(
          child: ErrorView(
            message: failure is AccountFailure
                ? accountFailureMessage(l10n, failure)
                : l10n.errorGeneric,
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.read(accountProvider.notifier).refresh(),
          ),
        ),
      );
    }
    final account = state.value;
    if (account == null) {
      return const Scaffold(body: SafeArea(child: LoadingView()));
    }
    return account.activeRole.isPro
        ? ProHomeScreen(account: account)
        : CustomerHomeScreen(account: account);
  }
}
