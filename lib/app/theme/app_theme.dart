import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_palettes.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'theme_controller.dart';

/// Legacy notifier for managing dynamic theme mode (forwarded to [themeControllerProvider]).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(themeControllerProvider).themeMode;
  }

  void toggleTheme(bool isCurrentlyDark) {
    ref
        .read(themeControllerProvider.notifier)
        .setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Factory for BookFair Manager application themes.
abstract final class AppTheme {
  /// Builds the light [ThemeData] for default original palette (backward compatibility)
  static ThemeData get lightTheme =>
      _buildTheme(AppPalettes.original.lightScheme);

  /// Builds the dark [ThemeData] for default original palette (backward compatibility)
  static ThemeData get darkTheme =>
      _buildTheme(AppPalettes.original.darkScheme);

  /// Dynamic factory: Builds light [ThemeData] for any selected [AppPalette]
  static ThemeData buildLightTheme(AppPalette palette) =>
      _buildTheme(palette.lightScheme);

  /// Dynamic factory: Builds dark [ThemeData] for any selected [AppPalette]
  static ThemeData buildDarkTheme(AppPalette palette) =>
      _buildTheme(palette.darkScheme);

  static ThemeData _buildTheme(AppColorScheme colors) {
    final textTheme = AppTypography.createTextTheme(colors);
    final brightness = colors.isDark ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryDark,
      onPrimaryContainer: AppColors.cFFFFFF,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.accent,
      onSecondaryContainer: colors.isDark
          ? colors.background
          : colors.textPrimary,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.error,
      onError: AppColors.cFFFFFF,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      dividerColor: colors.divider,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],

      // --- AppBar Theme ---
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),

      // --- Card Theme ---
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLarge,
          side: BorderSide(color: colors.border, width: 1.0),
        ),
        margin: AppSpacing.insetZero,
      ),

      // --- Divider Theme ---
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1.0,
        space: 1.0,
      ),

      // --- Dialog Theme ---
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLarge,
          side: BorderSide(color: colors.border, width: 1.0),
        ),
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),

      // --- Bottom Sheet Theme ---
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brTopExtraLarge,
        ),
        dragHandleColor: colors.border,
      ),

      // --- Snack Bar Theme ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.isDark ? AppColors.c370617 : AppColors.c03071E,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.cFFFFFF,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMedium,
          side: BorderSide(color: colors.border, width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // --- Input Decoration Theme ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.hint),
        helperStyle: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: colors.error,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.error, width: 2.0),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMedium,
          borderSide: BorderSide(color: colors.disabled, width: 1.0),
        ),
      ),

      // --- Segmented Button Theme ---
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(
            BorderSide(color: colors.border, width: 1.0),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primary;
            }
            return colors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.onPrimary;
            }
            return colors.textSecondary;
          }),
        ),
      ),

      // --- Navigation Bar Theme ---
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.onPrimary, size: 22.0);
          }
          return IconThemeData(color: colors.textSecondary, size: 22.0);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            );
          }
          return TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          );
        }),
      ),

      // --- Progress Indicator Theme ---
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surface,
        circularTrackColor: colors.border,
      ),
    );
  }
}
