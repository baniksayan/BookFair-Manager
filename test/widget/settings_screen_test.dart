import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Widget buildTestableWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen & Theme Switcher Widget Tests', () {
    testWidgets('Renders Appearance settings and theme options', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // App bar & sections
      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('Appearance & Themes'), findsOneWidget);

      // Current brand palette card
      expect(find.text('Original BookFair'), findsOneWidget);
      expect(find.text('Switch Palette'), findsOneWidget);

      // Theme mode selector
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Application Details
      expect(find.text('Application Details'), findsOneWidget);
    });

    testWidgets('Tapping Switch Palette opens PaletteSwitcherSheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final switchPaletteBtn = find.text('Switch Palette');
      expect(switchPaletteBtn, findsOneWidget);

      await tester.tap(switchPaletteBtn);
      await tester.pumpAndSettle();

      // Modal sheet opens with title and presets
      expect(find.text('Color Palette Presets'), findsOneWidget);
      expect(find.text('Original BookFair'), findsWidgets);
      expect(find.text('Dreamy Lavender'), findsOneWidget);
      expect(find.text('Romantic Pink'), findsOneWidget);
      expect(find.text('Forest Green'), findsOneWidget);
    });
  });
}
