import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';

/// A scripted [DeviceLocation]: the test sets what the OS would answer.
class FakeDeviceLocation implements DeviceLocation {
  FakeDeviceLocation({
    this.status = DevicePermission.notAsked,
    this.onRequest = DevicePermission.approximate,
    this.position = const GeoPoint(36.7538, 3.0588),
  });

  /// What [permission] reports now.
  DevicePermission status;

  /// What the OS prompt resolves to when the user is asked.
  DevicePermission onRequest;

  /// The fix; null reads as "no fix available".
  GeoPoint? position;

  final requests = <bool>[];
  var currentCalls = 0;
  var openSettingsCalls = 0;

  @override
  Future<DevicePermission> permission() async => status;

  @override
  Future<DevicePermission> request({required bool precise}) async {
    requests.add(precise);
    if (!status.granted) status = onRequest;
    return status;
  }

  @override
  Future<GeoPoint?> current() async {
    currentCalls++;
    return status.granted ? position : null;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}
