import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Strict visual system palette
  static const Color primaryText = Color(0xFF111111);
  static const Color mainBackground = Color(0xFFFFFFFF);
  static const Color secondaryBackground = Color(0xFFF7F7F7);
  static const Color primaryBorder = Color(0xFFE5E5E5);
  static const Color secondaryBorder = Color(0xFFD4D4D4);
  static const Color secondaryText = Color(0xFF737373);
  static const Color mutedText = Color(0xFFA3A3A3);
  static const Color accent = Color(0xFF10A37F);

  // Subtle semantic colors
  static const Color statusSuccess = Color(0xFF10A37F);
  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusError = Color(0xFFDC2626);
  static const Color statusInfo = Color(0xFF2563EB);
  static const Color statusNeutral = Color(0xFF737373);
}

class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Switzer';
  static const List<String> fallbackFonts = ['system-ui', '-apple-system', 'sans-serif'];

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.5,
    color: AppColors.primaryText,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.primaryText,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.primaryText,
  );

  static const TextStyle subsectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: -0.1,
    color: AppColors.primaryText,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.primaryText,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.primaryText,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.secondaryText,
  );

  static const TextStyle compactTable = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.primaryText,
  );

  static const TextStyle compactTableMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.primaryText,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.1,
    color: AppColors.secondaryText,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.mutedText,
  );
}

ThemeData buildSchoolicTheme() {
  const font = AppTypography.fontFamily;
  const fallbacks = AppTypography.fallbackFonts;

  return ThemeData(
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: fallbacks,
    scaffoldBackgroundColor: AppColors.mainBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryText,
      onPrimary: AppColors.mainBackground,
      secondary: AppColors.accent,
      onSecondary: AppColors.mainBackground,
      error: AppColors.statusError,
      onError: AppColors.mainBackground,
      surface: AppColors.mainBackground,
      onSurface: AppColors.primaryText,
      outline: AppColors.primaryBorder,
      outlineVariant: AppColors.secondaryBorder,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.primaryBorder,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      displayLarge: AppTypography.display,
      headlineMedium: AppTypography.pageTitle,
      titleLarge: AppTypography.sectionHeading,
      titleMedium: AppTypography.subsectionHeading,
      bodyLarge: AppTypography.bodyMedium,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.compactTable,
      labelLarge: AppTypography.label,
      labelMedium: AppTypography.metadata,
      labelSmall: AppTypography.metadata,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.mainBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: AppTypography.bodySecondary,
      hintStyle: AppTypography.metadata,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryText, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.statusError),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.mainBackground,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primaryText,
        foregroundColor: AppColors.mainBackground,
        textStyle: AppTypography.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryText,
        textStyle: AppTypography.bodyMedium,
        side: const BorderSide(color: AppColors.primaryBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryText,
        textStyle: AppTypography.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: AppTypography.body,
    ),
  );
}
