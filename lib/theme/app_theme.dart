import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const oliveGreen = Color(0xFF6B8E23);
    const white = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: oliveGreen,
        secondary: oliveGreen,
        tertiary: Color(0xFF8B9D3F),
        surface: white,
        error: Color(0xFFB3261E),
      ),
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: oliveGreen,
        foregroundColor: white,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    const oliveGreen = Color(0xFF8B9D3F);
    const grey = Color(0xFF2C2C2C);
    const darkGreyBg = Color(0xFF1A1A1A);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: oliveGreen,
        secondary: oliveGreen,
        tertiary: Color(0xFFAABF3F),
        surface: grey,
        error: Color(0xFFF2B8B5),
      ),
      scaffoldBackgroundColor: darkGreyBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: grey,
        foregroundColor: oliveGreen,
        elevation: 0,
      ),
    );
  }
}
