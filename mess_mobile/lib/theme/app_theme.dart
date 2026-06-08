import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const Color surface = Color(0xFFF8F9FF);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF444653);
  static const Color primaryDark = Color(0xFF00288E);
  static const Color primaryContainer = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF006C49);
  static const Color secondaryContainerTint = Color(0xFFE6F4EA);
  static const Color warningSurface = Color(0xFFFFF4E5);
  static const Color warningOutline = Color(0xFFF59E0B);
  static const Color outlineVariant = Color(0xFFC4C5D5);
  static const Color cardShadowTint = Color(0x331E40AF);
}

ThemeData buildAppTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryContainer,
    brightness: Brightness.light,
    primary: AppColors.primaryDark,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
  ).copyWith(secondary: AppColors.secondary, outlineVariant: AppColors.outlineVariant);

  return ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: GoogleFonts.interTextTheme(),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.72)),
      contentPadding: const EdgeInsets.fromLTRB(48, 14, 16, 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.25),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: AppColors.cardShadowTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.04)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryContainer),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      indicatorColor: AppColors.primaryDark.withOpacity(0.08),
      backgroundColor: Colors.white,
      height: 64,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      disabledColor: AppColors.surface.withOpacity(0.5),
      selectedColor: AppColors.primaryDark.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      side: BorderSide(color: Colors.black.withOpacity(0.05)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );
}

BoxShadow cardGlow() =>
    BoxShadow(color: AppColors.cardShadowTint.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 14));
