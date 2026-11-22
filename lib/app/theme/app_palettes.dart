import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Represents a validated, branded color palette preset with deterministic
/// light and dark semantic mappings.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
    required this.lightScheme,
    required this.darkScheme,
  });

  final String id;
  final String name;
  final String description;

  /// The 10 distinct brand colors of the preset.
  final List<Color> colors;

  /// Mandatory black neutral (#000000).
  static const Color neutralBlack = Color(0xFF000000);

  /// Mandatory white neutral (#FFFFFF).
  static const Color neutralWhite = Color(0xFFFFFFFF);

  /// All 12 approved colors for this palette (10 brand + 2 neutrals).
  List<Color> get allApprovedColors => [...colors, neutralBlack, neutralWhite];

  final AppColorScheme lightScheme;
  final AppColorScheme darkScheme;
}

/// Centralized repository of all seven approved brand palette presets.
abstract final class AppPalettes {
  // --- Mandatory Neutrals ---
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // ==========================================
  // PALETTE 00 — Original BookFair (Default)
  // ==========================================
  static const AppPalette original = AppPalette(
    id: 'original',
    name: 'Original BookFair',
    description: 'Deep burgundy, burnt orange, and warm gold editorial bookstore identity.',
    colors: [
      Color(0xFF03071E),
      Color(0xFF370617),
      Color(0xFF6A040F),
      Color(0xFF9D0208),
      Color(0xFFD00000),
      Color(0xFFDC2F02),
      Color(0xFFE85D04),
      Color(0xFFF48C06),
      Color(0xFFFAA307),
      Color(0xFFFFBA08),
    ],
    lightScheme: AppColors.light,
    darkScheme: AppColors.dark,
  );

  // ==========================================
  // PALETTE 01 — Dreamy Lavender
  // ==========================================
  static const AppPalette dreamyLavender = AppPalette(
    id: 'dreamy_lavender',
    name: 'Dreamy Lavender',
    description:
        'Ethereal pastel violets, soft lilacs, and calm periwinkle tints.',
    colors: [
      Color(0xFFFFCBF2),
      Color(0xFFF3C4FB),
      Color(0xFFECBCFD),
      Color(0xFFE5B3FE),
      Color(0xFFE2AFFF),
      Color(0xFFDEAAFF),
      Color(0xFFD8BBFF),
      Color(0xFFD0D1FF),
      Color(0xFFC8E7FF),
      Color(0xFFC0FDFF),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFFDEAAFF),
      primaryDark: Color(0xFFD8BBFF),
      secondary: Color(0xFFD0D1FF),
      accent: Color(0xFFC0FDFF),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFFFCBF2),
      textPrimary: black,
      textSecondary: Color(0xFFD8BBFF),
      border: Color(0xFFE5B3FE),
      divider: Color(0xFFE5B3FE),
      success: Color(0xFFC0FDFF),
      warning: Color(0xFFF3C4FB),
      error: Color(0xFFDEAAFF),
      info: Color(0xFFD0D1FF),
      disabled: Color(0xFFC8E7FF),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFE2AFFF),
      primaryDark: Color(0xFFDEAAFF),
      secondary: Color(0xFFD8BBFF),
      accent: Color(0xFFC0FDFF),
      background: black,
      surface: Color(0xFFDEAAFF),
      surfaceSecondary: Color(0xFFD8BBFF),
      textPrimary: white,
      textSecondary: Color(0xFFC8E7FF),
      border: Color(0xFFD8BBFF),
      divider: Color(0xFFD8BBFF),
      success: Color(0xFFC0FDFF),
      warning: Color(0xFFFFCBF2),
      error: Color(0xFFE2AFFF),
      info: Color(0xFFD0D1FF),
      disabled: Color(0xFFD8BBFF),
      isDark: true,
    ),
  );

  // ==========================================
  // PALETTE 02 — Romantic Pink
  // ==========================================
  static const AppPalette romanticPink = AppPalette(
    id: 'romantic_pink',
    name: 'Romantic Pink',
    description:
        'Vibrant fuchsias, tender blush roses, and passionate crimson accents.',
    colors: [
      Color(0xFFFF0A54),
      Color(0xFFFF477E),
      Color(0xFFFF5C8A),
      Color(0xFFFF7096),
      Color(0xFFFF85A1),
      Color(0xFFFF99AC),
      Color(0xFFFBB1BD),
      Color(0xFFF9BEC7),
      Color(0xFFF7CAD0),
      Color(0xFFFAE0E4),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFFFF0A54),
      primaryDark: Color(0xFFFF477E),
      secondary: Color(0xFFFF5C8A),
      accent: Color(0xFFFF7096),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFFAE0E4),
      textPrimary: black,
      textSecondary: Color(0xFFFF0A54),
      border: Color(0xFFF7CAD0),
      divider: Color(0xFFF7CAD0),
      success: Color(0xFFFF7096),
      warning: Color(0xFFFF85A1),
      error: Color(0xFFFF0A54),
      info: Color(0xFFFF477E),
      disabled: Color(0xFFFBB1BD),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFFF7096),
      primaryDark: Color(0xFFFF477E),
      secondary: Color(0xFFFF85A1),
      accent: Color(0xFFFF99AC),
      background: black,
      surface: Color(0xFFFF0A54),
      surfaceSecondary: Color(0xFFFF477E),
      textPrimary: white,
      textSecondary: Color(0xFFFAE0E4),
      border: Color(0xFFFF477E),
      divider: Color(0xFFFF477E),
      success: Color(0xFFFBB1BD),
      warning: Color(0xFFFF85A1),
      error: Color(0xFFFF0A54),
      info: Color(0xFFFF5C8A),
      disabled: Color(0xFFFF477E),
      isDark: true,
    ),
  );

  // ==========================================
  // PALETTE 03 — Soft Peach
  // ==========================================
  static const AppPalette softPeach = AppPalette(
    id: 'soft_peach',
    name: 'Soft Peach',
    description:
        'Warm apricot undertones, dusty terracotta, and velvety peach creams.',
    colors: [
      Color(0xFFE8A598),
      Color(0xFFFFB5A7),
      Color(0xFFFEC5BB),
      Color(0xFFFCD5CE),
      Color(0xFFFAE1DD),
      Color(0xFFF8EDEB),
      Color(0xFFF9E5D8),
      Color(0xFFF9DCC4),
      Color(0xFFFCD2AF),
      Color(0xFFFEC89A),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFFE8A598),
      primaryDark: Color(0xFFFFB5A7),
      secondary: Color(0xFFFEC89A),
      accent: Color(0xFFFCD2AF),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFF8EDEB),
      textPrimary: black,
      textSecondary: Color(0xFFE8A598),
      border: Color(0xFFFCD5CE),
      divider: Color(0xFFFCD5CE),
      success: Color(0xFFFEC89A),
      warning: Color(0xFFFFB5A7),
      error: Color(0xFFE8A598),
      info: Color(0xFFFCD2AF),
      disabled: Color(0xFFFEC5BB),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFFEC89A),
      primaryDark: Color(0xFFE8A598),
      secondary: Color(0xFFFCD2AF),
      accent: Color(0xFFFFB5A7),
      background: black,
      surface: Color(0xFFE8A598),
      surfaceSecondary: Color(0xFFFFB5A7),
      textPrimary: white,
      textSecondary: Color(0xFFF8EDEB),
      border: Color(0xFFE8A598),
      divider: Color(0xFFE8A598),
      success: Color(0xFFFEC89A),
      warning: Color(0xFFFFB5A7),
      error: Color(0xFFE8A598),
      info: Color(0xFFFCD2AF),
      disabled: Color(0xFFE8A598),
      isDark: true,
    ),
  );

  // ==========================================
  // PALETTE 04 — Ocean & Coral
  // ==========================================
  static const AppPalette oceanCoral = AppPalette(
    id: 'ocean_coral',
    name: 'Ocean & Coral',
    description:
        'Deep nautical marine sapphire contrasting vivid fiery coral red.',
    colors: [
      Color(0xFF033270),
      Color(0xFF1368AA),
      Color(0xFF4091C9),
      Color(0xFF9DCEE2),
      Color(0xFFFEDFD4),
      Color(0xFFF29479),
      Color(0xFFF26A4F),
      Color(0xFFEF3C2D),
      Color(0xFFCB1B16),
      Color(0xFF65010C),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFF033270),
      primaryDark: Color(0xFF65010C),
      secondary: Color(0xFF1368AA),
      accent: Color(0xFFEF3C2D),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFFEDFD4),
      textPrimary: Color(0xFF033270),
      textSecondary: Color(0xFF1368AA),
      border: Color(0xFF9DCEE2),
      divider: Color(0xFF9DCEE2),
      success: Color(0xFF4091C9),
      warning: Color(0xFFF29479),
      error: Color(0xFFCB1B16),
      info: Color(0xFF1368AA),
      disabled: Color(0xFF9DCEE2),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF4091C9),
      primaryDark: Color(0xFF1368AA),
      secondary: Color(0xFFF26A4F),
      accent: Color(0xFFEF3C2D),
      background: Color(0xFF033270),
      surface: Color(0xFF65010C),
      surfaceSecondary: Color(0xFF1368AA),
      textPrimary: white,
      textSecondary: Color(0xFF9DCEE2),
      border: Color(0xFF1368AA),
      divider: Color(0xFF1368AA),
      success: Color(0xFF9DCEE2),
      warning: Color(0xFFF29479),
      error: Color(0xFFEF3C2D),
      info: Color(0xFF4091C9),
      disabled: Color(0xFF1368AA),
      isDark: true,
    ),
  );

  // ==========================================
  // PALETTE 05 — Fresh Pastel
  // ==========================================
  static const AppPalette freshPastel = AppPalette(
    id: 'fresh_pastel',
    name: 'Fresh Pastel',
    description:
        'Crisp meadow sage, springtime lime zest, and airy azure sky blues.',
    colors: [
      Color(0xFFA1EF7A),
      Color(0xFFB0EF8E),
      Color(0xFFBAF19C),
      Color(0xFFD0F4BA),
      Color(0xFFEAF8DA),
      Color(0xFFDCE9FC),
      Color(0xFFBBDEF9),
      Color(0xFF9CD2F7),
      Color(0xFF89CCF6),
      Color(0xFF78C6F7),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFF78C6F7),
      primaryDark: Color(0xFF89CCF6),
      secondary: Color(0xFFA1EF7A),
      accent: Color(0xFF9CD2F7),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFEAF8DA),
      textPrimary: black,
      textSecondary: Color(0xFF78C6F7),
      border: Color(0xFFBBDEF9),
      divider: Color(0xFFBBDEF9),
      success: Color(0xFFA1EF7A),
      warning: Color(0xFFBAF19C),
      error: Color(0xFF78C6F7),
      info: Color(0xFF89CCF6),
      disabled: Color(0xFFD0F4BA),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF89CCF6),
      primaryDark: Color(0xFF78C6F7),
      secondary: Color(0xFFA1EF7A),
      accent: Color(0xFF9CD2F7),
      background: black,
      surface: Color(0xFF78C6F7),
      surfaceSecondary: Color(0xFF89CCF6),
      textPrimary: white,
      textSecondary: Color(0xFFEAF8DA),
      border: Color(0xFF78C6F7),
      divider: Color(0xFF78C6F7),
      success: Color(0xFFA1EF7A),
      warning: Color(0xFFBAF19C),
      error: Color(0xFF78C6F7),
      info: Color(0xFF89CCF6),
      disabled: Color(0xFF78C6F7),
      isDark: true,
    ),
  );

  // ==========================================
  // PALETTE 06 — Forest Green
  // ==========================================
  static const AppPalette forestGreen = AppPalette(
    id: 'forest_green',
    name: 'Forest Green',
    description:
        'Majestic evergreen pine, deep spruce foliage, and fresh minty dew.',
    colors: [
      Color(0xFF014737),
      Color(0xFF03543F),
      Color(0xFF046C4E),
      Color(0xFF057A55),
      Color(0xFF0E9F6E),
      Color(0xFF31C48D),
      Color(0xFF84E1BC),
      Color(0xFFBCF0DA),
      Color(0xFFDEF7EC),
      Color(0xFFF3FAF7),
    ],
    lightScheme: AppColorScheme(
      primary: Color(0xFF046C4E),
      primaryDark: Color(0xFF014737),
      secondary: Color(0xFF0E9F6E),
      accent: Color(0xFF31C48D),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFDEF7EC),
      textPrimary: Color(0xFF014737),
      textSecondary: Color(0xFF046C4E),
      border: Color(0xFFBCF0DA),
      divider: Color(0xFFBCF0DA),
      success: Color(0xFF0E9F6E),
      warning: Color(0xFF31C48D),
      error: Color(0xFF014737),
      info: Color(0xFF057A55),
      disabled: Color(0xFF84E1BC),
      isDark: false,
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF31C48D),
      primaryDark: Color(0xFF0E9F6E),
      secondary: Color(0xFF84E1BC),
      accent: Color(0xFFBCF0DA),
      background: Color(0xFF014737),
      surface: Color(0xFF03543F),
      surfaceSecondary: Color(0xFF046C4E),
      textPrimary: white,
      textSecondary: Color(0xFFBCF0DA),
      border: Color(0xFF046C4E),
      divider: Color(0xFF046C4E),
      success: Color(0xFF31C48D),
      warning: Color(0xFF84E1BC),
      error: Color(0xFF0E9F6E),
      info: Color(0xFF31C48D),
      disabled: Color(0xFF046C4E),
      isDark: true,
    ),
  );

  /// Complete list of all seven selectable palette presets.
  static const List<AppPalette> values = [
    original,
    dreamyLavender,
    romanticPink,
    softPeach,
    oceanCoral,
    freshPastel,
    forestGreen,
  ];

  /// Alias for [values]
  static const List<AppPalette> all = values;

  /// Resolves an [AppPalette] by its unique string identifier.
  static AppPalette fromId(String? id) {
    if (id == null) return original;
    return values.firstWhere((p) => p.id == id, orElse: () => original);
  }
}
