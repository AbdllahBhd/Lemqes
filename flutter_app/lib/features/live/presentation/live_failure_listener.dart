import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../data/live_failure.dart';

/// The words for a failed live action; never the raw exception.
String liveFailureMessage(AppLocalizations l10n, LiveFailure failure) =>
    switch (failure) {
      LiveNetworkFailure() => l10n.errorNetwork,
      QueueEmpty() => l10n.liveErrorQueueEmpty,
      NothingServing() => l10n.liveErrorNothingServing,
      NothingToUndo() => l10n.liveErrorNothingToUndo,
      EntryNotActive() => l10n.liveErrorEntryGone,
      InvalidName() => l10n.liveErrorInvalidName,
      InvalidService() => l10n.liveErrorInvalidService,
      NotOpen() => l10n.liveErrorNotOpen,
      _ => l10n.errorGeneric,
    };

/// One reported failure; a new instance per report, so the same failure
/// twice is said twice.
class LiveFailureReport {
  LiveFailureReport(this.failure);

  final LiveFailure failure;
}

/// The latest failed live action, said by [LiveFailureListener].
final liveFailureReportsProvider =
    NotifierProvider<LiveFailureReports, LiveFailureReport?>(
      LiveFailureReports.new,
    );

class LiveFailureReports extends Notifier<LiveFailureReport?> {
  @override
  LiveFailureReport? build() => null;

  void report(LiveFailure failure) => state = LiveFailureReport(failure);
}

/// Runs a live action; a failure goes to [LiveFailureListener] instead of
/// escaping into the widget tree. The reporter is read before the await, so
/// a widget gone meanwhile still gets its failure said.
Future<void> runLive(WidgetRef ref, Future<void> Function() action) async {
  final reports = ref.read(liveFailureReportsProvider.notifier);
  try {
    await action();
  } on LiveFailure catch (f) {
    reports.report(f);
  }
}

/// Shows a snackbar for each failed live action while the content stays on
/// screen. A failure that lands while a sheet or dialog covers this route is
/// kept, and the latest is shown once this route is on top again.
class LiveFailureListener extends ConsumerStatefulWidget {
  const LiveFailureListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LiveFailureListener> createState() =>
      _LiveFailureListenerState();
}

class _LiveFailureListenerState extends ConsumerState<LiveFailureListener> {
  LiveFailure? _unseen;

  bool get _onTop => ModalRoute.of(context)?.isCurrent ?? true;

  // Runs when the route above is popped: `ModalRoute.of` makes this widget
  // depend on whether its route is current.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final failure = _unseen;
    if (failure == null || !_onTop) return;
    _unseen = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(failure);
    });
  }

  void _show(LiveFailure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(liveFailureMessage(context.l10n, failure))),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveFailureReportsProvider, (_, next) {
      if (next == null) return;
      if (_onTop) {
        _show(next.failure);
      } else {
        _unseen = next.failure;
      }
    });
    return widget.child;
  }
}
