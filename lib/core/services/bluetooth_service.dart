import 'package:flutter/widgets.dart';

abstract class BluetoothService {
  Stream<String> get lines; // newline-terminated text lines
  bool get isConnected;

  /// Show a picker (or any UI) to choose a device and connect.
  Future<void> connectWithPicker(BuildContext context);

  /// Disconnect & stop emitting lines.
  Future<void> disconnect();
}
