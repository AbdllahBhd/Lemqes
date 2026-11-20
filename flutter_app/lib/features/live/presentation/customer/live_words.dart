import '../../../../core/l10n/gen/app_localizations.dart';
import '../../data/live_derive.dart';
import '../../data/live_models.dart';

/// Keeps [text] (a time, a pro-typed name) in its own direction inside a
/// sentence of the other one: "retour 14:30" in Arabic, an Arabic name in
/// French.
String isolate(String text) => '\u2068$text\u2069';

/// A left-to-right island ("14:30" inside Arabic).
String ltrIsolate(String text) => '\u2066$text\u2069';

/// "il y a 10 min", "il y a 2 h", "à l’instant". Floored to 5 min: the
/// server already rounds the activity time down (coarse presence).
String liveAgeText(AppLocalizations l10n, Duration age) {
  final minutes = age.inMinutes;
  if (minutes >= 60) return l10n.liveAgeHours(minutes ~/ 60);
  final coarse = minutes ~/ 5 * 5;
  return coarse == 0 ? l10n.liveAgeNow : l10n.liveAgeMinutes(coarse);
}

/// "~40 min"; null when there is nothing to wait for.
String? liveWaitText(AppLocalizations l10n, int? minutes) =>
    minutes == null || minutes <= 0 ? null : l10n.liveWaitApprox(minutes);

/// Whether the view can be trusted as a live status: not closed, not stale.
bool isLiveNow(LiveView v) => v.status != LiveStatus.closed && !v.stale;

/// The queue line under the status: "3 en attente · ~40 min", "File ouverte
/// · ~40 min" (count hidden), "File complète" (paused); null when closed or
/// uncertain. Without [withWait] (the customer holds a place there, and the
/// ticket says their own wait) the line carries no wait.
String? queueLineText(
  AppLocalizations l10n,
  LiveView v, {
  bool withWait = true,
}) {
  if (!isLiveNow(v)) return null;
  final s = v.snapshot;
  if (s.queueMode != QueueMode.open) return l10n.liveQueueFull;
  final wait = withWait ? liveWaitText(l10n, v.waitMin) : null;
  final count = s.waitingCount;
  if (count == null) {
    return wait == null ? l10n.liveQueueOpen : l10n.liveQueueOpenWait(wait);
  }
  if (count == 0) {
    // Nobody waiting, someone in the chair: the wait is that chair's.
    return wait == null ? l10n.liveQueueNoWait : l10n.liveQueueNoWaitWait(wait);
  }
  return wait == null
      ? l10n.liveQueueCount(count)
      : l10n.liveQueueWaiting(count, wait);
}

/// Whether a customer may try to join: the server's pro-side conditions
/// ([LiveSnapshot.joinBlock]) and what time alone changed since (closed,
/// uncertain, break over).
bool canTryJoin(LiveView v) =>
    v.snapshot.joinBlock == null && isLiveNow(v) && !v.breakOverdue;
