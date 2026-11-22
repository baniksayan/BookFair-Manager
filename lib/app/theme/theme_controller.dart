import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_constants.dart';
import '../../features/book_fairs/domain/entities/activity_log.dart';
import '../../features/book_fairs/presentation/view_models/book_fair_providers.dart';
import 'app_palettes.dart';

/// State encapsulating current dynamic theme settings.
@immutable
class AppThemeState {
  const AppThemeState({required this.palette, required this.themeMode});

  final AppPalette palette;
  final ThemeMode themeMode;

  AppThemeState copyWith({AppPalette? palette, ThemeMode? themeMode}) {
    return AppThemeState(
      palette: palette ?? this.palette,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeState &&
          runtimeType == other.runtimeType &&
          palette.id == other.palette.id &&
          themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(palette.id, themeMode);
}

/// Dynamic Theme Controller managing theme mode and brand palette with Hive persistence.
final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeState>(ThemeController.new);

class ThemeController extends Notifier<AppThemeState> {
  static const _uuid = Uuid();

  @override
  AppThemeState build() {
    // Read persisted preferences from Hive metadata box if opened
    AppPalette initialPalette = AppPalettes.original;
    ThemeMode initialMode = ThemeMode.system;

    try {
      if (Hive.isBoxOpen(DatabaseConstants.metadataBox)) {
        final box = Hive.box<dynamic>(DatabaseConstants.metadataBox);
        final savedPaletteId =
            box.get(DatabaseConstants.selectedPaletteKey) as String?;
        final savedModeStr =
            box.get(DatabaseConstants.selectedThemeModeKey) as String?;

        if (savedPaletteId != null) {
          initialPalette = AppPalettes.fromId(savedPaletteId);
        }

        if (savedModeStr != null) {
          switch (savedModeStr.toLowerCase()) {
            case 'light':
              initialMode = ThemeMode.light;
              break;
            case 'dark':
              initialMode = ThemeMode.dark;
              break;
            case 'system':
            default:
              initialMode = ThemeMode.system;
              break;
          }
        }
      }
    } catch (_) {
      // In case metadata box is not yet opened, fall back gracefully
    }

    return AppThemeState(palette: initialPalette, themeMode: initialMode);
  }

  /// Updates the active color palette, persists to Hive, and records an audit log.
  Future<void> setPalette(AppPalette palette) async {
    if (state.palette.id == palette.id) return;

    state = state.copyWith(palette: palette);

    try {
      if (Hive.isBoxOpen(DatabaseConstants.metadataBox)) {
        final box = Hive.box<dynamic>(DatabaseConstants.metadataBox);
        await box.put(DatabaseConstants.selectedPaletteKey, palette.id);
      }

      // Log theme change to audit trail
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logEvent(
        ActivityLog(
          id: _uuid.v4(),
          title: 'Theme Changed',
          subtitle: 'Active brand palette changed to ${palette.name}',
          amount: palette.name,
          type: ActivityLogType.themeChanged,
          timestamp: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  /// Updates the application theme mode (System, Light, Dark) and persists to Hive.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;

    state = state.copyWith(themeMode: mode);

    try {
      if (Hive.isBoxOpen(DatabaseConstants.metadataBox)) {
        final box = Hive.box<dynamic>(DatabaseConstants.metadataBox);
        await box.put(DatabaseConstants.selectedThemeModeKey, mode.name);
      }
    } catch (_) {}
  }
}
