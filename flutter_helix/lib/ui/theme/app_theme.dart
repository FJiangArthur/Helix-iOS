// ABOUTME: App theme configuration with light and dark mode definitions
// ABOUTME: Defines colors, typography, and component styling for consistent UI

import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color primaryVariant = Color(0xFF1976D2);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFB00020);
  
  // Dark theme colors
  static const Color darkPrimaryColor = Color(0xFF90CAF9);
  static const Color darkSurfaceColor = Color(0xFF121212);
  static const Color darkBackgroundColor = Color(0xFF121212);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimaryColor,
        secondary: secondaryColor,
        surface: darkSurfaceColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        color: darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimaryColor,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkPrimaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: darkSurfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkPrimaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}