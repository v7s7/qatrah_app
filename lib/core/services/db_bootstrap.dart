import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

/// Call this before any DB access on desktop.
Future<void> bootstrapDatabaseForDesktop() async {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI loader
    sqfliteFfiInit();
    // Tell sqflite to use the FFI factory on desktop
    databaseFactory = databaseFactoryFfi;
  }
}
