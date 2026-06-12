import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF121212);
  static const sidebar = Color(0xFF000000);
  static const surface = Color(0xFF181818);
  static const surfaceVariant = Color(0xFF1F1F1F);
  static const surfaceElevated = Color(0xFF282828);
  static const highlight = Color(0xFF2A2A2A);

  static const accent = Color(0xFFFFFFFF);
  static const accentHover = Color(0xFFE5E5E5);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textMuted = Color(0xFF6A6A6A);

  static const divider = Color(0x1AFFFFFF);
}

class AppFonts {
  static const String family = 'Onest';
}

class AppTheme {
  static ThemeData dark() {
    const base = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: Color(0xFFE22134),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      fontFamily: AppFonts.family,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.family,
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.3),
        headlineSmall: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        titleLarge: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        bodyLarge: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontSize: 14),
        bodySmall: TextStyle(fontFamily: AppFonts.family, color: AppColors.textSecondary, fontSize: 12),
        labelLarge: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontFamily: AppFonts.family, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.5),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.textPrimary,
        inactiveTrackColor: AppColors.textMuted,
        thumbColor: AppColors.textPrimary,
        overlayColor: Color(0x33FFFFFF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary, fontSize: 12),
        preferBelow: false,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.highlight,
        circularTrackColor: AppColors.highlight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(fontFamily: AppFonts.family, color: AppColors.textMuted),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontFamily: AppFonts.family, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.family,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        textStyle: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: TextStyle(fontFamily: AppFonts.family, color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
