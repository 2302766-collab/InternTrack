import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brandColor = Color(0xFF0F4C5C);
  static const Color brandBlue = Color(0xFF326DE6);
  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightTextPrimary = Color(0xFF102A56);
  static const Color lightTextSecondary = Color(0xFF4A6480);
  static const Color lightBorderColor = Color(0xFFD8E2EC);
  static const Color darkBackground = Color(0xFF09151D);
  static const Color darkSurface = Color(0xFF132532);
  static const Color darkTextPrimary = Color(0xFFF3F7FB);
  static const Color darkTextSecondary = Color(0xFFB9C8D7);
  static const Color darkBorderColor = Color(0xFF274150);
  static final String _fontFamily =
      GoogleFonts.manrope().fontFamily ?? 'Manrope';

  static ThemeData lightTheme() {
    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBackground: lightBackground,
      surface: Colors.white,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
      borderColor: lightBorderColor,
      dividerColor: const Color(0xFFE7EBF0),
      hintColor: const Color(0xFF8A98A8),
      prefixIconColor: const Color(0xFF57707A),
      disabledBorderColor: const Color(0xFFE2E8F0),
      tooltipColor: lightTextPrimary,
      progressTrackColor: const Color(0xFFDDE2EA),
      shadowColor: const Color(0x330F4C5C),
    );
  }

  static ThemeData darkTheme() {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackground: darkBackground,
      surface: darkSurface,
      textPrimary: darkTextPrimary,
      textSecondary: darkTextSecondary,
      borderColor: darkBorderColor,
      dividerColor: const Color(0xFF213746),
      hintColor: const Color(0xFF8EA3B6),
      prefixIconColor: darkTextSecondary,
      disabledBorderColor: const Color(0xFF20323F),
      tooltipColor: const Color(0xFF041017),
      progressTrackColor: const Color(0xFF213746),
      shadowColor: const Color(0x00000000),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color dividerColor,
    required Color hintColor,
    required Color prefixIconColor,
    required Color disabledBorderColor,
    required Color tooltipColor,
    required Color progressTrackColor,
    required Color shadowColor,
  }) {
    final textTheme = _buildTextTheme(
      textPrimary: textPrimary,
      textSecondary: textSecondary,
    );

    return ThemeData(
      brightness: brightness,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: brandColor,
        surface: surface,
        primary: brandColor,
        secondary: brandBlue,
        error: const Color(0xFFB42318),
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: surface,
        elevation: brightness == Brightness.light ? 1.5 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: dividerColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: hintColor,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: brandColor,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: const Color(0xFF667085),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: Color(0xFFB42318),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: prefixIconColor,
        suffixIconColor: prefixIconColor,
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF04438)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF7FAAB5),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: brightness == Brightness.light ? 1.5 : 0,
          shadowColor: shadowColor,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandColor,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandColor,
        linearTrackColor: progressTrackColor,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: tooltipColor,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final baseTextTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.02,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.08,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: textSecondary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: textSecondary,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: 0,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
    );
  }
}
