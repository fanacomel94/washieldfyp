import 'package:flutter/material.dart';

class AppTheme {
  // 🌿 Green palette (dark teal → mint)
  static const Color gDarkest   = Color(0xFF031F20);
  static const Color gDark2     = Color(0xFF0C3A3B);
  static const Color gDark3     = Color(0xFF146B59);
  static const Color gMid       = Color(0xFF2A8767);
  static const Color gMidLight  = Color(0xFF3CA771);
  static const Color gLight2    = Color(0xFF52C678);
  static const Color gLightest  = Color.fromARGB(255, 197, 233, 209);

  /// 🌞 LIGHT THEME
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,

      colorScheme: const ColorScheme.light(
        primary: gDark3,          // main actions
        secondary: gMid,   // secondary buttons
        tertiary: gLight2,      // accents
        surface: Color.fromARGB(255, 246, 249, 247),     // cards/sheets
        background: gLightest,
        error: Color(0xFFB3261E),
      ),

      scaffoldBackgroundColor: gLightest,

      appBarTheme: const AppBarTheme(
        backgroundColor: gLightest,
        foregroundColor: gDark3,
        elevation: 0,
      ),
    );
  }

  /// 🌙 DARK THEME
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,

      colorScheme: const ColorScheme.dark(
        primary: gLight2,       // buttons pop in dark
        secondary: gMidLight,   // accents
        tertiary: gLightest,    // highlights
        surface: gDark2,        // cards/nav
        background: gDarkest,
        error: Color(0xFFF2B8B5),
      ),

      scaffoldBackgroundColor: gDarkest,

      appBarTheme: const AppBarTheme(
        backgroundColor: gDark2,
        foregroundColor: gLight2,
        elevation: 0,
      ),
    );
  }
}
