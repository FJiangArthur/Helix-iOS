import 'package:flutter/material.dart';

class HelixTheme {
  HelixTheme._();

  static const Color background = Color(0xFF090D12);
  static const Color backgroundRaised = Color(0xFF10161D);
  static const Color surface = Color(0xFF151B23);
  static const Color surfaceRaised = Color(0xFF1B232D);
  static const Color surfaceInteractive = Color(0xFF222D38);
  static const Color borderSubtle = Color(0xFF2B3541);
  static const Color borderStrong = Color(0xFF3B4956);
  static const Color cyan = Color(0xFF55C7E8);
  static const Color cyanDeep = Color(0xFF1C7892);
  static const Color purple = Color(0xFF8B96C9);
  static const Color lime = Color(0xFF8CD6A4);
  static const Color amber = Color(0xFFE7AE62);
  static const Color error = Color(0xFFE56C6C);
  static const Color textPrimary = Color(0xFFF1F4F7);
  static const Color textSecondary = Color(0xFFB1BBC6);
  static const Color textMuted = Color(0xFF7D8996);

  static const Color statusListening = Color(0xFF55C7E8);
  static const Color statusThinking = Color(0xFFE7AE62);
  static const Color statusReady = Color(0xFF8CD6A4);
  static const Color statusOffline = Color(0xFF7D8996);
  static const double radiusPanel = 8;
  static const double radiusControl = 10;
  static const double radiusPill = 999;

  static Color panelFill([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(
      surface,
      surfaceRaised,
      strength,
    )!.withValues(alpha: 0.96);
  }

  static Color panelBorder([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(borderSubtle, borderStrong, strength)!;
  }

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      primary: cyan,
      secondary: purple,
      surface: surface,
      onSurface: textPrimary,
      error: error,
    ),
    fontFamily: 'SF Pro Display',
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        color: textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: borderSubtle.withValues(alpha: 0.9),
      space: 24,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceRaised.withValues(alpha: 0.94),
      indicatorColor: cyan.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      height: 62,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? textPrimary : textMuted,
          letterSpacing: 0.2,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: cyan, size: 23);
        }
        return const IconThemeData(color: textMuted, size: 23);
      }),
    ),
    cardTheme: CardThemeData(
      color: panelFill(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusPanel),
        side: const BorderSide(color: borderSubtle),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceRaised,
      contentTextStyle: const TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        side: const BorderSide(color: borderStrong),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceInteractive,
      hintStyle: const TextStyle(
        color: textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: cyan),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
