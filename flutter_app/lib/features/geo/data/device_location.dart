import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as g;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/shared_preferences_provider.dart';

import 'geo_models.dart';

/// What the app may do with the device position right now.
enum DevicePermission {
  /// Not asked yet (the OS reports "denied" for both this and a first
  /// refusal; only "never ask again" is distinguishable).
  notAsked,
  denied,

  /// The OS will not prompt again: only the system settings can change it.
  deniedForever,

  /// Permission is granted but location is switched off on the device.
  serviceOff,
  approximate,
  precise;

  bool get granted => this == approximate || this == precise;
}

/// The device position behind an interface: geolocator needs a platform
/// service (GeoClue on Linux) that tests cannot assume.
abstract interface class DeviceLocation {
  /// The current permission, never prompting.
  Future<DevicePermission> permission();

  /// Prompts if needed. Customer flows pass `precise: false`; only the pro
  /// place picker asks for precise.
  Future<DevicePermission> request({required bool precise});

  /// One fix, or null when none is available (not granted, service off,
  /// timeout).
  Future<GeoPoint?> current();

  /// Opens the app's page in the system settings, the only way back from
  /// [DevicePermission.deniedForever]. False when it could not be opened.
  Future<bool> openSettings();
}

final deviceLocationProvider = Provider<DeviceLocation>(
  (ref) => GeolocatorDeviceLocation(ref.watch(sharedPreferencesProvider)),
);

/// SharedPreferences flag set the first time the OS prompt is requested.
/// geolocator reports "denied" both before any request and after a refusal,
/// so this is the only way to tell [DevicePermission.notAsked] apart.
const locationRequestedKey = 'location_requested_v1';

/// geolocator's answers as a [DevicePermission]; pure so every branch is
/// testable without the platform plugin.
DevicePermission mapDevicePermission({
  required g.LocationPermission permission,
  required bool everRequested,
  required bool serviceEnabled,
  required g.LocationAccuracyStatus accuracy,
}) {
  if (!serviceEnabled) return DevicePermission.serviceOff;
  switch (permission) {
    case g.LocationPermission.deniedForever:
      return DevicePermission.deniedForever;
    case g.LocationPermission.denied:
    case g.LocationPermission.unableToDetermine:
      return everRequested
          ? DevicePermission.denied
          : DevicePermission.notAsked;
    case g.LocationPermission.whileInUse:
    case g.LocationPermission.always:
      return accuracy == g.LocationAccuracyStatus.reduced
          ? DevicePermission.approximate
          : DevicePermission.precise;
  }
}

/// The only file that imports geolocator.
class GeolocatorDeviceLocation implements DeviceLocation {
  GeolocatorDeviceLocation(this._prefs);

  static const _fixTimeout = Duration(seconds: 10);

  final SharedPreferences _prefs;

  @override
  Future<DevicePermission> permission() => _guard(
    () async => mapDevicePermission(
      serviceEnabled: await g.Geolocator.isLocationServiceEnabled(),
      permission: await g.Geolocator.checkPermission(),
      everRequested: _prefs.getBool(locationRequestedKey) ?? false,
      accuracy: await _guard(
        g.Geolocator.getLocationAccuracy,
        g.LocationAccuracyStatus.precise,
      ),
    ),
    DevicePermission.denied,
  );

  @override
  Future<DevicePermission> request({required bool precise}) async {
    // geolocator cannot ask for coarse only: Android shows the system's
    // approximate/precise choice and iOS its own, so `precise` only matters
    // to a caller that later checks the result.
    final now = await permission();
    if (now.granted ||
        now == DevicePermission.serviceOff ||
        now == DevicePermission.deniedForever) {
      return now;
    }
    // Recorded before asking: a prompt dismissed by killing the app still
    // counts as asked.
    await _prefs.setBool(locationRequestedKey, true);
    return _guard(() async {
      await g.Geolocator.requestPermission();
      return permission();
    }, DevicePermission.denied);
  }

  @override
  Future<GeoPoint?> current() => _guard(() async {
    final p = await g.Geolocator.getCurrentPosition(
      locationSettings: g.LocationSettings(
        accuracy: g.LocationAccuracy.low,
        timeLimit: _fixTimeout,
      ),
    );
    return GeoPoint(p.latitude, p.longitude);
  }, null);

  @override
  Future<bool> openSettings() => _guard(g.Geolocator.openAppSettings, false);

  /// Platform failures (no plugin, DBus refusal, timeout) mean "no position",
  /// never a crash; the cause goes to the log.
  Future<T> _guard<T>(Future<T> Function() body, T fallback) async {
    try {
      return await body();
    } on Object catch (e, st) {
      developer.log('device location failed', error: e, stackTrace: st);
      return fallback;
    }
  }
}
