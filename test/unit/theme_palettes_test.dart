import 'package:bookfair_manager/app/theme/app_palettes.dart';
import 'package:bookfair_manager/app/theme/theme_controller.dart';
import 'package:bookfair_manager/core/database/database_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestDatabaseHelper.setUpSuiteDatabase();
  });

  tearDownAll(() async {
    await TestDatabaseHelper.tearDownSuiteDatabase();
  });

  setUp(() async {
    await TestDatabaseHelper.resetDatabase();
  });

  group('Dynamic Multi-Color Theme Engine Exhaustive Unit Tests', () {
    test('all 7 approved palettes are registered with stable identifiers', () {
      expect(AppPalettes.values.length, equals(7));
      final ids = AppPalettes.values.map((p) => p.id).toSet();
      expect(ids.length, equals(7));

      expect(
        ids,
        containsAll([
          'original',
          'dreamy_lavender',
          'romantic_pink',
          'soft_peach',
          'ocean_coral',
          'fresh_pastel',
          'forest_green',
        ]),
      );
    });

    test('all 7 palettes include exact names and 10 brand colors + black/white neutrals', () {
      for (final palette in AppPalettes.values) {
        expect(palette.colors.length, equals(10));
        expect(AppPalette.neutralBlack, equals(const Color(0xFF000000)));
        expect(AppPalette.neutralWhite, equals(const Color(0xFFFFFFFF)));
        expect(palette.allApprovedColors.length, equals(12));
      }
    });

    test(
      'Palette 01: Original BookFair matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.original;
        expect(p.id, 'original');
        expect(p.name, 'Original BookFair');
        expect(p.colors[0].toARGB32(), equals(0xFF03071E));
        expect(p.colors[1].toARGB32(), equals(0xFF370617));
        expect(p.colors[2].toARGB32(), equals(0xFF6A040F));
        expect(p.colors[3].toARGB32(), equals(0xFF9D0208));
        expect(p.colors[4].toARGB32(), equals(0xFFD00000));
        expect(p.colors[5].toARGB32(), equals(0xFFDC2F02));
        expect(p.colors[6].toARGB32(), equals(0xFFE85D04));
        expect(p.colors[7].toARGB32(), equals(0xFFF48C06));
        expect(p.colors[8].toARGB32(), equals(0xFFFAA307));
        expect(p.colors[9].toARGB32(), equals(0xFFFFBA08));
      },
    );

    test(
      'Palette 02: Dreamy Lavender matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.dreamyLavender;
        expect(p.id, 'dreamy_lavender');
        expect(p.name, 'Dreamy Lavender');
        expect(p.colors[0].toARGB32(), equals(0xFFFFCBF2));
        expect(p.colors[1].toARGB32(), equals(0xFFF3C4FB));
        expect(p.colors[2].toARGB32(), equals(0xFFECBCFD));
        expect(p.colors[3].toARGB32(), equals(0xFFE5B3FE));
        expect(p.colors[4].toARGB32(), equals(0xFFE2AFFF));
        expect(p.colors[5].toARGB32(), equals(0xFFDEAAFF));
        expect(p.colors[6].toARGB32(), equals(0xFFD8BBFF));
        expect(p.colors[7].toARGB32(), equals(0xFFD0D1FF));
        expect(p.colors[8].toARGB32(), equals(0xFFC8E7FF));
        expect(p.colors[9].toARGB32(), equals(0xFFC0FDFF));
      },
    );

    test(
      'Palette 03: Romantic Pink matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.romanticPink;
        expect(p.id, 'romantic_pink');
        expect(p.name, 'Romantic Pink');
        expect(p.colors[0].toARGB32(), equals(0xFFFF0A54));
        expect(p.colors[1].toARGB32(), equals(0xFFFF477E));
        expect(p.colors[2].toARGB32(), equals(0xFFFF5C8A));
        expect(p.colors[3].toARGB32(), equals(0xFFFF7096));
        expect(p.colors[4].toARGB32(), equals(0xFFFF85A1));
        expect(p.colors[5].toARGB32(), equals(0xFFFF99AC));
        expect(p.colors[6].toARGB32(), equals(0xFFFBB1BD));
        expect(p.colors[7].toARGB32(), equals(0xFFF9BEC7));
        expect(p.colors[8].toARGB32(), equals(0xFFF7CAD0));
        expect(p.colors[9].toARGB32(), equals(0xFFFAE0E4));
      },
    );

    test(
      'Palette 04: Soft Peach matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.softPeach;
        expect(p.id, 'soft_peach');
        expect(p.name, 'Soft Peach');
        expect(p.colors[0].toARGB32(), equals(0xFFE8A598));
        expect(p.colors[1].toARGB32(), equals(0xFFFFB5A7));
        expect(p.colors[2].toARGB32(), equals(0xFFFEC5BB));
        expect(p.colors[3].toARGB32(), equals(0xFFFCD5CE));
        expect(p.colors[4].toARGB32(), equals(0xFFFAE1DD));
        expect(p.colors[5].toARGB32(), equals(0xFFF8EDEB));
        expect(p.colors[6].toARGB32(), equals(0xFFF9E5D8));
        expect(p.colors[7].toARGB32(), equals(0xFFF9DCC4));
        expect(p.colors[8].toARGB32(), equals(0xFFFCD2AF));
        expect(p.colors[9].toARGB32(), equals(0xFFFEC89A));
      },
    );

    test(
      'Palette 05: Ocean & Coral matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.oceanCoral;
        expect(p.id, 'ocean_coral');
        expect(p.name, 'Ocean & Coral');
        expect(p.colors[0].toARGB32(), equals(0xFF033270));
        expect(p.colors[1].toARGB32(), equals(0xFF1368AA));
        expect(p.colors[2].toARGB32(), equals(0xFF4091C9));
        expect(p.colors[3].toARGB32(), equals(0xFF9DCEE2));
        expect(p.colors[4].toARGB32(), equals(0xFFFEDFD4));
        expect(p.colors[5].toARGB32(), equals(0xFFF29479));
        expect(p.colors[6].toARGB32(), equals(0xFFF26A4F));
        expect(p.colors[7].toARGB32(), equals(0xFFEF3C2D));
        expect(p.colors[8].toARGB32(), equals(0xFFCB1B16));
        expect(p.colors[9].toARGB32(), equals(0xFF65010C));
      },
    );

    test(
      'Palette 06: Fresh Pastel matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.freshPastel;
        expect(p.id, 'fresh_pastel');
        expect(p.name, 'Fresh Pastel');
        expect(p.colors[0].toARGB32(), equals(0xFFA1EF7A));
        expect(p.colors[1].toARGB32(), equals(0xFFB0EF8E));
        expect(p.colors[2].toARGB32(), equals(0xFFBAF19C));
        expect(p.colors[3].toARGB32(), equals(0xFFD0F4BA));
        expect(p.colors[4].toARGB32(), equals(0xFFEAF8DA));
        expect(p.colors[5].toARGB32(), equals(0xFFDCE9FC));
        expect(p.colors[6].toARGB32(), equals(0xFFBBDEF9));
        expect(p.colors[7].toARGB32(), equals(0xFF9CD2F7));
        expect(p.colors[8].toARGB32(), equals(0xFF89CCF6));
        expect(p.colors[9].toARGB32(), equals(0xFF78C6F7));
      },
    );

    test(
      'Palette 07: Forest Green matches all 10 hex specifications exactly',
      () {
        final p = AppPalettes.forestGreen;
        expect(p.id, 'forest_green');
        expect(p.name, 'Forest Green');
        expect(p.colors[0].toARGB32(), equals(0xFF014737));
        expect(p.colors[1].toARGB32(), equals(0xFF03543F));
        expect(p.colors[2].toARGB32(), equals(0xFF046C4E));
        expect(p.colors[3].toARGB32(), equals(0xFF057A55));
        expect(p.colors[4].toARGB32(), equals(0xFF0E9F6E));
        expect(p.colors[5].toARGB32(), equals(0xFF31C48D));
        expect(p.colors[6].toARGB32(), equals(0xFF84E1BC));
        expect(p.colors[7].toARGB32(), equals(0xFFBCF0DA));
        expect(p.colors[8].toARGB32(), equals(0xFFDEF7EC));
        expect(p.colors[9].toARGB32(), equals(0xFFF3FAF7));
      },
    );

    test('deterministic Light and Dark AppColorSchemes are generated for all presets', () {
      for (final palette in AppPalettes.values) {
        final light = palette.lightScheme;
        final dark = palette.darkScheme;

        expect(light.isDark, isFalse);
        expect(dark.isDark, isTrue);

        expect(light.primary, isNotNull);
        expect(light.background, isNotNull);
        expect(light.surface, isNotNull);
        expect(light.textPrimary, isNotNull);
        expect(light.textSecondary, isNotNull);
        expect(light.accent, isNotNull);
        expect(light.border, isNotNull);

        expect(dark.primary, isNotNull);
        expect(dark.background, isNotNull);
        expect(dark.surface, isNotNull);
        expect(dark.textPrimary, isNotNull);
        expect(dark.textSecondary, isNotNull);
        expect(dark.accent, isNotNull);
        expect(dark.border, isNotNull);
      }
    });

    test('fromId correctly retrieves palette and defaults to original on unknown key', () {
      expect(AppPalettes.fromId('forest_green').id, equals('forest_green'));
      expect(
        AppPalettes.fromId('dreamy_lavender').id,
        equals('dreamy_lavender'),
      );
      expect(AppPalettes.fromId('romantic_pink').id, equals('romantic_pink'));
      expect(AppPalettes.fromId('soft_peach').id, equals('soft_peach'));
      expect(AppPalettes.fromId('ocean_coral').id, equals('ocean_coral'));
      expect(AppPalettes.fromId('fresh_pastel').id, equals('fresh_pastel'));
      expect(AppPalettes.fromId('original').id, equals('original'));
      expect(AppPalettes.fromId('non_existent').id, equals('original'));
      expect(AppPalettes.fromId(null).id, equals('original'));
    });

    test('ThemeController switches palette and persists preference to Hive metadata', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(themeControllerProvider.notifier);

      // Default is original
      expect(container.read(themeControllerProvider).palette.id, 'original');

      // Switch to Romantic Pink
      await controller.setPalette(AppPalettes.romanticPink);
      expect(
        container.read(themeControllerProvider).palette.id,
        'romantic_pink',
      );

      // Verify Hive metadata box persisted the change
      final metaBox = Hive.box<dynamic>(DatabaseConstants.metadataBox);
      expect(
        metaBox.get(DatabaseConstants.selectedPaletteKey),
        'romantic_pink',
      );

      // Switch to Forest Green
      await controller.setPalette(AppPalettes.forestGreen);
      expect(
        container.read(themeControllerProvider).palette.id,
        'forest_green',
      );
      expect(metaBox.get(DatabaseConstants.selectedPaletteKey), 'forest_green');
    });
  });
}
