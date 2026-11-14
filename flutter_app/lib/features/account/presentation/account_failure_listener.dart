import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../data/account_providers.dart';
import '../data/account_repository.dart';

/// The words for whatever an account action threw; never the raw exception.
String accountErrorMessage(AppLocalizations l10n, Object? error) =>
    error is AccountFailure
    ? accountFailureMessage(l10n, error)
    : l10n.errorGeneric;

/// Shows a snackbar when an account action fails while the account is still
/// known (a role, space or add-role change). A failed first load has no
/// account to keep on screen, so it is left to the screen's error view.
class AccountFailureListener extends ConsumerWidget {
  const AccountFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(accountProvider, (previous, next) {
      // Every notification into an error is a new failure: the controller
      // goes error -> error on repeated failures, never through loading.
      if (!next.hasError || !next.hasValue) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(accountErrorMessage(context.l10n, next.error)),
          ),
        );
    });
    return child;
  }
}
