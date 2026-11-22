import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as g;

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
}

final deviceLocationProvider = Provider<DeviceLocation>(
  (_) => GeolocatorDeviceLocation(),
);

/// The only file that imports geolocator.
class GeolocatorDeviceLocation implements DeviceLocation {
  static const _fixTimeout = Duration(seconds: 10);

  @override
  Future<DevicePermission> permission() => _guard(() async {
    if (!await g.Geolocator.isLocationServiceEnabled()) {
      return DevicePermission.serviceOff;
    }
    return _map(await g.Geolocator.checkPermission());
  }, DevicePermission.denied);

  @override
  Future<DevicePermission> request({required bool precise}) async {
    // geolocator cannot ask for coarse only: Android shows the system's
    // approximate/precise choice and iOS its own, so `precise` only matters
    // to a caller that later checks the result.
    final now = await permission();
    if (now.granted || now == DevicePermission.serviceOff) return now;
    if (now == DevicePermission.deniedForever) return now;
    return _guard(() async {
      final asked = await g.Geolocator.requestPermission();
      return _map(asked);
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

  Future<DevicePermission> _map(g.LocationPermission p) async {
    switch (p) {
      case g.LocationPermission.deniedForever:
        return DevicePermission.deniedForever;
      case g.LocationPermission.denied:
      case g.LocationPermission.unableToDetermine:
        return DevicePermission.denied;
      case g.LocationPermission.whileInUse:
      case g.LocationPermission.always:
        final accuracy = await _guard(
          g.Geolocator.getLocationAccuracy,
          g.LocationAccuracyStatus.precise,
        );
        return accuracy == g.LocationAccuracyStatus.reduced
            ? DevicePermission.approximate
            : DevicePermission.precise;
    }
  }

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
