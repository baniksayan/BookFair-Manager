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
      primary: Color(0xFF6B2D9E),
      primaryDark: Color(0xFF4A1A75),
      secondary: Color(0xFF8E44AD),
      accent: Color(0xFFDEAAFF),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFF8F0FF),
      textPrimary: black,
      textSecondary: Color(0xFF5A2D82),
      border: Color(0xFF9565C4),
      divider: Color(0xFF9565C4),
      success: Color(0xFF27AE60),
      warning: Color(0xFFE67E22),
      error: Color(0xFFD00000),
      info: Color(0xFF6B2D9E),
      disabled: Color(0xFF8C71A5),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E0F54), Color(0xFF441A75), Color(0xFF5D2699)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFD8BBFF),
      primaryDark: Color(0xFFDEAAFF),
      secondary: Color(0xFFC0FDFF),
      accent: Color(0xFFFFCBF2),
      background: Color(0xFF120824),
      surface: Color(0xFF1F1035),
      surfaceSecondary: Color(0xFF2C1948),
      textPrimary: white,
      textSecondary: Color(0xFFD8BBFF),
      border: Color(0xFF8452BD),
      divider: Color(0xFF8452BD),
      success: Color(0xFF31C48D),
      warning: Color(0xFFF3C4FB),
      error: Color(0xFFFF477E),
      info: Color(0xFFC0FDFF),
      disabled: Color(0xFF603C87),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2C1948), Color(0xFF1F1035), Color(0xFF120824)],
      ),
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
      primary: Color(0xFFD80045),
      primaryDark: Color(0xFF990033),
      secondary: Color(0xFFFF477E),
      accent: Color(0xFFFF7096),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFFFF0F3),
      textPrimary: black,
      textSecondary: Color(0xFF8B1038),
      border: Color(0xFFC74B70),
      divider: Color(0xFFC74B70),
      success: Color(0xFF0E9F6E),
      warning: Color(0xFFE85D04),
      error: Color(0xFFFF0A54),
      info: Color(0xFFFF477E),
      disabled: Color(0xFFA66074),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A071E), Color(0xFF750C31), Color(0xFF9C1242)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFFF7096),
      primaryDark: Color(0xFFFF477E),
      secondary: Color(0xFFFF99AC),
      accent: Color(0xFFFAE0E4),
      background: Color(0xFF18050B),
      surface: Color(0xFF2D0B16),
      surfaceSecondary: Color(0xFF3F1321),
      textPrimary: white,
      textSecondary: Color(0xFFF9BEC7),
      border: Color(0xFFB83B65),
      divider: Color(0xFFB83B65),
      success: Color(0xFF31C48D),
      warning: Color(0xFFFF85A1),
      error: Color(0xFFFF0A54),
      info: Color(0xFFFF7096),
      disabled: Color(0xFF70263C),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3F1321), Color(0xFF2D0B16), Color(0xFF18050B)],
      ),
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
      primary: Color(0xFFB84E38),
      primaryDark: Color(0xFF8C3422),
      secondary: Color(0xFFD46D55),
      accent: Color(0xFFFEC89A),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFFFF6F4),
      textPrimary: black,
      textSecondary: Color(0xFF7D382B),
      border: Color(0xFFB56B5C),
      divider: Color(0xFFB56B5C),
      success: Color(0xFF0E9F6E),
      warning: Color(0xFFE85D04),
      error: Color(0xFFD00000),
      info: Color(0xFFB84E38),
      disabled: Color(0xFFA17268),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3E160E), Color(0xFF632519), Color(0xFF853525)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFFFEC89A),
      primaryDark: Color(0xFFFCD2AF),
      secondary: Color(0xFFFFB5A7),
      accent: Color(0xFFF9DCC4),
      background: Color(0xFF150B08),
      surface: Color(0xFF241410),
      surfaceSecondary: Color(0xFF35201A),
      textPrimary: white,
      textSecondary: Color(0xFFF9DCC4),
      border: Color(0xFF945647),
      divider: Color(0xFF945647),
      success: Color(0xFF31C48D),
      warning: Color(0xFFFFB5A7),
      error: Color(0xFFE85D04),
      info: Color(0xFFFEC89A),
      disabled: Color(0xFF6E4035),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF35201A), Color(0xFF241410), Color(0xFF150B08)],
      ),
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
      primaryDark: Color(0xFF022047),
      secondary: Color(0xFF1368AA),
      accent: Color(0xFFEF3C2D),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFF0F7FC),
      textPrimary: Color(0xFF033270),
      textSecondary: Color(0xFF0E4D7E),
      border: Color(0xFF3A8AC9),
      divider: Color(0xFF3A8AC9),
      success: Color(0xFF0E9F6E),
      warning: Color(0xFFF29479),
      error: Color(0xFFCB1B16),
      info: Color(0xFF1368AA),
      disabled: Color(0xFF6693B8),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF011838), Color(0xFF022654), Color(0xFF043B7A)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF4091C9),
      primaryDark: Color(0xFF1368AA),
      secondary: Color(0xFFF26A4F),
      accent: Color(0xFFEF3C2D),
      background: Color(0xFF02172E),
      surface: Color(0xFF06284F),
      surfaceSecondary: Color(0xFF0A376B),
      textPrimary: white,
      textSecondary: Color(0xFF9DCEE2),
      border: Color(0xFF387BBD),
      divider: Color(0xFF387BBD),
      success: Color(0xFF31C48D),
      warning: Color(0xFFF29479),
      error: Color(0xFFEF3C2D),
      info: Color(0xFF4091C9),
      disabled: Color(0xFF184E7A),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A376B), Color(0xFF06284F), Color(0xFF02172E)],
      ),
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
      primary: Color(0xFF1668A0),
      primaryDark: Color(0xFF0D4770),
      secondary: Color(0xFF2E8B57),
      accent: Color(0xFF78C6F7),
      background: white,
      surface: white,
      surfaceSecondary: Color(0xFFF2FAF0),
      textPrimary: black,
      textSecondary: Color(0xFF194C72),
      border: Color(0xFF5097C7),
      divider: Color(0xFF5097C7),
      success: Color(0xFF2E8B57),
      warning: Color(0xFFD48806),
      error: Color(0xFFD00000),
      info: Color(0xFF1668A0),
      disabled: Color(0xFF5C8FA8),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF082438), Color(0xFF0E3B5C), Color(0xFF14527D)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF78C6F7),
      primaryDark: Color(0xFF89CCF6),
      secondary: Color(0xFFA1EF7A),
      accent: Color(0xFF9CD2F7),
      background: Color(0xFF051420),
      surface: Color(0xFF0B2136),
      surfaceSecondary: Color(0xFF13324F),
      textPrimary: white,
      textSecondary: Color(0xFFBBDEF9),
      border: Color(0xFF2F74A8),
      divider: Color(0xFF2F74A8),
      success: Color(0xFFA1EF7A),
      warning: Color(0xFFBAF19C),
      error: Color(0xFFFF5C8A),
      info: Color(0xFF89CCF6),
      disabled: Color(0xFF1C496B),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF13324F), Color(0xFF0B2136), Color(0xFF051420)],
      ),
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
      surfaceSecondary: Color(0xFFF0F9F5),
      textPrimary: Color(0xFF014737),
      textSecondary: Color(0xFF046C4E),
      border: Color(0xFF229A6E),
      divider: Color(0xFF229A6E),
      success: Color(0xFF0E9F6E),
      warning: Color(0xFFE85D04),
      error: Color(0xFFD00000),
      info: Color(0xFF057A55),
      disabled: Color(0xFF56947F),
      isDark: false,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF012B21), Color(0xFF013D2F), Color(0xFF025742)],
      ),
    ),
    darkScheme: AppColorScheme(
      primary: Color(0xFF31C48D),
      primaryDark: Color(0xFF0E9F6E),
      secondary: Color(0xFF84E1BC),
      accent: Color(0xFFBCF0DA),
      background: Color(0xFF01241C),
      surface: Color(0xFF024535),
      surfaceSecondary: Color(0xFF045944),
      textPrimary: white,
      textSecondary: Color(0xFFBCF0DA),
      border: Color(0xFF0E9F6E),
      divider: Color(0xFF0E9F6E),
      success: Color(0xFF31C48D),
      warning: Color(0xFF84E1BC),
      error: Color(0xFFFF5C8A),
      info: Color(0xFF31C48D),
      disabled: Color(0xFF065C45),
      isDark: true,
      customHeroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF045944), Color(0xFF024535), Color(0xFF01241C)],
      ),
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
