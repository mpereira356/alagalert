import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5), // indigo-600
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,

    scaffoldBackgroundColor:
        isDark ? const Color(0xFF0F1115) : const Color(0xFFF6F7FB),

    // >>> AQUI: CardThemeData (não CardTheme)
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),

    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? colorScheme.primaryContainer.withOpacity(0.18)
          : colorScheme.primaryContainer.withOpacity(0.30),
      labelStyle: TextStyle(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    iconTheme: IconThemeData(color: colorScheme.onSurface),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
      labelStyle: TextStyle(color: colorScheme.onSurface),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
  );
}
