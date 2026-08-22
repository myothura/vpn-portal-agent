// File: lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Single source of truth for the agent app's look.
///
/// Two rules this file exists to enforce:
///  1. SOLID ONLY. No BackdropFilter, no translucent fills. Cards are opaque
///     surfaces separated by a hairline border. Blur cost real frames on
///     mid-range Android and buys nothing on a light background.
///  2. ONE TYPEFACE. Plus Jakarta Sans at varying weights, not four families
///     mixed per screen.
class AppTheme {
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  /// The only elevation in the app: a soft, low-contrast lift. Cards rely on
  /// the border for definition; this just stops them floating flat.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0D101828),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ];

  static TextStyle _t(double size, FontWeight weight, Color color,
          {double? height, double? spacing}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,

    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.accentInk,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.border,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.textPrimary,
      centerTitle: false,
      titleTextStyle: _t(18, FontWeight.w700, AppColors.textPrimary),
    ),

    textTheme: TextTheme(
      displaySmall: _t(30, FontWeight.w800, AppColors.textPrimary, height: 1.15),
      headlineMedium: _t(24, FontWeight.w800, AppColors.textPrimary, height: 1.2),
      titleLarge: _t(18, FontWeight.w700, AppColors.textPrimary),
      titleMedium: _t(15, FontWeight.w700, AppColors.textPrimary),
      bodyLarge: _t(15, FontWeight.w500, AppColors.textPrimary, height: 1.45),
      bodyMedium: _t(13, FontWeight.w500, AppColors.textSecondary, height: 1.45),
      bodySmall: _t(12, FontWeight.w500, AppColors.textTertiary),
      labelLarge: _t(14, FontWeight.w700, AppColors.textPrimary),
      // Section eyebrows: "TODAY'S TODOS", "ANALYTICS".
      labelSmall: _t(11, FontWeight.w700, AppColors.textTertiary, spacing: 0.8),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: _t(14, FontWeight.w500, AppColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: _t(14, FontWeight.w700, AppColors.textOnAccent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: const BorderSide(color: AppColors.border),
        textStyle: _t(14, FontWeight.w700, AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentInk,
        textStyle: _t(13, FontWeight.w700, AppColors.accentInk),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.accent,
      side: BorderSide.none,
      labelStyle: _t(12, FontWeight.w600, AppColors.textSecondary),
      secondaryLabelStyle: _t(12, FontWeight.w700, AppColors.textOnAccent),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: const StadiumBorder(),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: _t(13, FontWeight.w600, AppColors.textOnInk),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceAlt,
      circularTrackColor: AppColors.surfaceAlt,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),

    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
  );
}
