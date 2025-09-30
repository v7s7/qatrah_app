import 'package:flutter/material.dart';

class AppGradient {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF00B8FF), Color(0xFF3CF6C8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppThemeV2 {
  static const bgNavy = Color(0xFF071C2A);

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgNavy,
  );
}
