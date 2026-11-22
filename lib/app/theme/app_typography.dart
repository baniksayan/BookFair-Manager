import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized editorial typography system.
///
/// Features a distinguished editorial serif for headings and display titles,
/// paired with crisp, clean sans-serif for body and metadata.
abstract final class AppTypography {
  /// Primary editorial serif font family name
  static const String editorialFontFamily = 'Georgia';

  /// Generates a complete [TextTheme] mapped to the given [AppColorScheme].
  static TextTheme createTextTheme(AppColorScheme colors) {
    return TextTheme(
      // --- Display Styles (Editorial Serif) ---
      displayLarge: TextStyle(
        fontFamily: editorialFontFamily,
        fontSize: 34.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: colors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: editorialFontFamily,
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        color: colors.textPrimary,
      ),

      // --- Headline Styles (Editorial Serif) ---
      headlineLarge: TextStyle(
        fontFamily: editorialFontFamily,
        fontSize: 24.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: editorialFontFamily,
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: colors.textPrimary,
      ),

      // --- Title Styles (Editorial Serif & Crisp Sans) ---
      titleLarge: TextStyle(
        fontFamily: editorialFontFamily,
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.4,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: colors.textPrimary,
      ),

      // --- Body Styles (Clean Sans-Serif) ---
      bodyLarge: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        color: colors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        height: 1.4,
        color: colors.textSecondary,
      ),

      // --- Label Styles (Uppercase & Metadata) ---
      labelLarge: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
        color: colors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
        color: colors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.2,
        color: colors.textSecondary,
      ),
    );
  }
}
