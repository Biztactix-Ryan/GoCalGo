import 'package:flutter/material.dart';

/// Pokemon Go-inspired colour palette and theme configuration.
class AppTheme {
  const AppTheme._();

  // Primary colours — Pokemon Go blue/teal tones
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color teal = Color(0xFF00ACC1);

  // Accent colours — Pokemon Go warm tones
  static const Color pokemonYellow = Color(0xFFFFCB05);
  static const Color pokemonRed = Color(0xFFCC0000);

  // Background shades
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Neutral
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: teal,
      tertiary: pokemonYellow,
      error: pokemonRed,
      surface: surfaceWhite,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: teal,
      tertiary: pokemonYellow,
      error: pokemonRed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
