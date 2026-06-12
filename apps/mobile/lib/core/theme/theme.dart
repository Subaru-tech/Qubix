import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

/// Qubix Material theme — dark-first with custom component styles.
class QubixTheme {
  QubixTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: QubixColors.background,
      colorScheme: const ColorScheme.dark(
        primary: QubixColors.primary,
        secondary: QubixColors.accent,
        surface: QubixColors.surface,
        error: QubixColors.error,
        onPrimary: QubixColors.textInverse,
        onSecondary: QubixColors.textInverse,
        onSurface: QubixColors.textPrimary,
        onError: Colors.white,
        outline: QubixColors.divider,
      ),

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: QubixColors.background,
        foregroundColor: QubixColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: QubixTypography.displaySmall,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: QubixColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      // ── Bottom Nav Bar ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: QubixColors.surface,
        selectedItemColor: QubixColors.primary,
        unselectedItemColor: QubixColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: QubixColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: QubixColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: QubixColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QubixColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QubixColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QubixColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QubixColors.error),
        ),
        hintStyle: QubixTypography.bodyMedium.copyWith(
          color: QubixColors.textTertiary,
        ),
        labelStyle: QubixTypography.labelMedium,
      ),

      // ── Elevated Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QubixColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: QubixTypography.button,
        ),
      ),

      // ── Outlined Buttons ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: QubixColors.primary,
          side: const BorderSide(color: QubixColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: QubixTypography.button,
        ),
      ),

      // ── Text Buttons ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: QubixColors.primary,
          textStyle: QubixTypography.button,
        ),
      ),

      // ── Icon ──
      iconTheme: const IconThemeData(
        color: QubixColors.textSecondary,
        size: 22,
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: QubixColors.divider,
        thickness: 1,
        space: 0,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: QubixColors.surfaceLight,
        contentTextStyle: QubixTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: QubixColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: QubixTypography.displaySmall,
        contentTextStyle: QubixTypography.bodyMedium,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: QubixColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: QubixColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }
}
