// lib/core/services/ble_permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> ensureBlePermissions() async {
  if (!Platform.isAndroid) return;

  final info = await DeviceInfoPlugin().androidInfo;
  final sdk = info.version.sdkInt; // non-null, no ?? 0

  if (sdk >= 31) {
    // Android 12+ : request new BLE permissions
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final okScan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final okConn = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    if (!okScan || !okConn) {
      throw Exception('Bluetooth permissions denied');
    }
  } else {
    // Android 11 and below: Location is required for BLE scan results (names/RSSI)
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      throw Exception(
        'Location permission is required for BLE scanning on this Android version.',
      );
    }
    // Many Huawei devices also require the system Location toggle to be ON
    final svc = await Permission.location.serviceStatus;
    if (!svc.isEnabled) {
      throw Exception('Turn ON the system Location toggle for BLE scanning.');
    }
  }
}
