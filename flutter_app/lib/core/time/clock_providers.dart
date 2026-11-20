import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'country_clock.dart';

/// The country the app runs in (M1 ships Algeria only).
const defaultCountryTimezone = 'Africa/Algiers';

/// The device clock as a UTC instant. The one place in the app that reads
/// `DateTime.now()`; tests override it with a fake.
final utcClockProvider = Provider<DateTime Function()>(
  (_) =>
      () => DateTime.now().toUtc(),
);

/// Server time minus device time, learned from snapshot `server_now`. Zero
/// until a snapshot arrives.
final serverOffsetProvider = NotifierProvider<ServerOffset, Duration>(
  ServerOffset.new,
);

class ServerOffset extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  /// Records the offset seen when a snapshot stamped [serverNow] arrived.
  void observe(DateTime serverNow) =>
      state = serverNow.toUtc().difference(ref.read(utcClockProvider)());
}

/// The best known server instant: device clock corrected by the offset.
final serverNowProvider = Provider<DateTime Function()>((ref) {
  final utc = ref.watch(utcClockProvider);
  final offset = ref.watch(serverOffsetProvider);
  return () => utc().add(offset);
});

/// The country's wall clock ("today" for hours tables), independent of the
/// device zone.
final countryClockProvider = Provider<DateTime Function()>((ref) {
  final now = ref.watch(serverNowProvider);
  return () => countryNow(defaultCountryTimezone, now());
});
