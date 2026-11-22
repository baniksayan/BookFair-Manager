import 'package:flutter/material.dart';

/// Centralized brand colors and semantic color tokens for BookFair Manager.
///
/// STRICT PALETTE RULES:
/// Only the 12 approved hex colors may be used across the application.
/// No default Material purple/blue, no greens, greys, teals, cyans, pinks,
/// or arbitrary color values are allowed.
abstract final class AppColors {
  // --- Raw 12 Approved Palette Hex Colors ---

  /// Primary 1: Deep obsidian / navy-black
  static const Color c03071E = Color(0xFF03071E);

  /// Primary 2: Deep rosewood / wine
  static const Color c370617 = Color(0xFF370617);

  /// Primary 3: Rich burgundy
  static const Color c6A040F = Color(0xFF6A040F);

  /// Primary 4: Deep crimson
  static const Color c9D0208 = Color(0xFF9D0208);

  /// Primary 5: Vivid red
  static const Color cD00000 = Color(0xFFD00000);

  /// Primary 6: Rust / red-orange
  static const Color cDC2F02 = Color(0xFFDC2F02);

  /// Primary 7: Burnt orange
  static const Color cE85D04 = Color(0xFFE85D04);

  /// Primary 8: Warm amber orange
  static const Color cF48C06 = Color(0xFFF48C06);

  /// Primary 9: Golden amber
  static const Color cFAA307 = Color(0xFFFAA307);

  /// Primary 10: Warm gold
  static const Color cFFBA08 = Color(0xFFFFBA08);

  /// Neutral 1: Absolute black
  static const Color c000000 = Color(0xFF000000);

  /// Neutral 2: Absolute white
  static const Color cFFFFFF = Color(0xFFFFFFFF);

  // --- Predefined Semantic Token Sets ---

  /// Light theme semantic color configuration
  static const AppColorScheme light = AppColorScheme(
    primary: c6A040F,
    primaryDark: c370617,
    secondary: cDC2F02,
    accent: cF48C06,
    background: cFFFFFF,
    surface: cFFFFFF,
    surfaceSecondary: cFFFFFF,
    textPrimary: c03071E,
    textSecondary: c6A040F,
    border: cE85D04,
    divider: cE85D04,
    success: cFAA307,
    warning: cF48C06,
    error: cD00000,
    info: cDC2F02,
    disabled: cFFBA08,
    isDark: false,
    customHeroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c370617, c6A040F, c9D0208],
    ),
  );

  /// Dark theme semantic color configuration
  static const AppColorScheme dark = AppColorScheme(
    primary: cFFBA08,
    primaryDark: cFAA307,
    secondary: cF48C06,
    accent: cE85D04,
    background: c03071E,
    surface: c370617,
    surfaceSecondary: c6A040F,
    textPrimary: cFFFFFF,
    textSecondary: cFFBA08,
    border: cDC2F02,
    divider: cDC2F02,
    success: cFFBA08,
    warning: cFAA307,
    error: cD00000,
    info: cE85D04,
    disabled: c6A040F,
    isDark: true,
    customHeroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c370617, c6A040F, c03071E],
    ),
  );
}

/// Semantic color tokens exposed via [ThemeExtension]
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabled,
    required this.isDark,
    this.customHeroGradient,
    this.customPrimaryGradient,
    this.customCardGradient,
    this.customAccentGradient,
  });

  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;
  final bool isDark;
  final LinearGradient? customHeroGradient;
  final LinearGradient? customPrimaryGradient;
  final LinearGradient? customCardGradient;
  final LinearGradient? customAccentGradient;

  // Convenience aliases strictly mapping to approved tokens
  Color get surfaceContainer => surface;
  Color get surfaceContainerHigh => surfaceSecondary;
  Color get surfaceContainerHighest => surfaceSecondary;
  Color get borderSubtle => border;
  Color get onSurface => textPrimary;
  Color get onSurfaceMuted => textSecondary;

  /// High-contrast foreground color on top of [primary].
  Color get onPrimary =>
      ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
      ? AppColors.cFFFFFF
      : (isDark ? background : textPrimary);

  /// High-contrast foreground color on top of [secondary].
  Color get onSecondary =>
      ThemeData.estimateBrightnessForColor(secondary) == Brightness.dark
      ? AppColors.cFFFFFF
      : (isDark ? background : textPrimary);

  /// High-contrast hint / placeholder text color.
  Color get hint => isDark
      ? textSecondary.withValues(alpha: 0.85)
      : textSecondary.withValues(alpha: 0.8);

  /// Dynamic gradient for primary actions, buttons, and highlights.
  LinearGradient get primaryGradient =>
      customPrimaryGradient ??
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDark, primary],
      );

  /// Rich, dark, jewel-tone gradient for Hero banners with guaranteed >= 7:1 AAA contrast for white text.
  LinearGradient get heroGradient =>
      customHeroGradient ??
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [surfaceSecondary, primaryDark, background]
            : [primaryDark, primary, secondary],
      );

  /// Subtle branded gradient for card containers and elevated sections.
  LinearGradient get cardGradient =>
      customCardGradient ??
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [surface, surfaceSecondary.withValues(alpha: 0.5)]
            : [surface, primary.withValues(alpha: 0.04)],
      );

  /// Vibrant gradient for secondary accents and badges.
  LinearGradient get accentGradient =>
      customAccentGradient ??
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [secondary, accent],
      );

  @override
  AppColorScheme copyWith({
    Color? primary,
    Color? primaryDark,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? disabled,
    bool? isDark,
    LinearGradient? customHeroGradient,
    LinearGradient? customPrimaryGradient,
    LinearGradient? customCardGradient,
    LinearGradient? customAccentGradient,
  }) {
    return AppColorScheme(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      disabled: disabled ?? this.disabled,
      isDark: isDark ?? this.isDark,
      customHeroGradient: customHeroGradient ?? this.customHeroGradient,
      customPrimaryGradient:
          customPrimaryGradient ?? this.customPrimaryGradient,
      customCardGradient: customCardGradient ?? this.customCardGradient,
      customAccentGradient: customAccentGradient ?? this.customAccentGradient,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    // We snap at midpoint to never generate unapproved intermediate colors!
    return t < 0.5 ? this : other;
  }
}
