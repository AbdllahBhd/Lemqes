import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../data/pro_providers.dart';
import 'pro_failure_message.dart';

/// Shows a snackbar when a pro action fails while the profile is still on
/// screen ([MyProController] keeps the previous profile on error). A failed
/// first load has nothing to keep, so it is left to the screen's error view.
///
/// While a sheet or dialog covers the screen, that route says why in place,
/// so the snackbar is skipped.
class ProFailureListener extends ConsumerWidget {
  const ProFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(myProProvider, (previous, next) {
      // The controller goes error -> error on repeated failures, never
      // through loading, so every settled error notification is new.
      if (!next.hasError || !next.hasValue || next.isLoading) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(proFailureMessage(context.l10n, next.error))),
        );
    });
    return child;
  }
}
