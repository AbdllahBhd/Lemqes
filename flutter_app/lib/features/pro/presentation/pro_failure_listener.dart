import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../data/pro_providers.dart';
import 'pro_failure_message.dart';

/// Shows a snackbar when a pro action fails while the profile is still on
/// screen ([MyProController] keeps the previous profile on error). A failed
/// first load has nothing to keep, so it is left to the screen's error view.
///
/// A failure that lands while a sheet, dialog or pushed screen covers this
/// one is kept, and the latest is shown once this screen is on top again:
/// nothing on those routes says why in place.
class ProFailureListener extends ConsumerStatefulWidget {
  const ProFailureListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProFailureListener> createState() => _ProFailureListenerState();
}

class _ProFailureListenerState extends ConsumerState<ProFailureListener> {
  Object? _unseen;

  bool get _onTop => ModalRoute.of(context)?.isCurrent ?? true;

  // Runs when the route above is popped: `ModalRoute.of` makes this widget
  // depend on whether its route is current.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final error = _unseen;
    if (error == null || !_onTop) return;
    _unseen = null;
    // Not during the build that the route change triggers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(error);
    });
  }

  void _show(Object? error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(proFailureMessage(context.l10n, error))),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myProProvider, (previous, next) {
      // The controller goes error -> error on repeated failures, never
      // through loading, so every settled error notification is new.
      if (!next.hasError || !next.hasValue || next.isLoading) return;
      if (_onTop) {
        _show(next.error);
      } else {
        _unseen = next.error;
      }
    });
    return widget.child;
  }
}
