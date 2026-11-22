import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/components/palette_switcher_sheet.dart';
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

    testWidgets(
      'Selecting a palette in PaletteSwitcherSheet renders high contrast and SELECTED badge',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        // Open palette switcher
        await tester.tap(find.text('Switch Palette'));
        await tester.pumpAndSettle();

        // Initially in PaletteSwitcherSheet Original BookFair is ACTIVE
        expect(
          find.descendant(
            of: find.byType(PaletteSwitcherSheet),
            matching: find.text('ACTIVE'),
          ),
          findsOneWidget,
        );
        expect(find.text('SELECTED'), findsNothing);

        // Select Romantic Pink
        await tester.tap(find.text('Romantic Pink'));
        await tester.pumpAndSettle();

        // Now Romantic Pink shows SELECTED badge
        expect(find.text('SELECTED'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PaletteSwitcherSheet),
            matching: find.text('ACTIVE'),
          ),
          findsOneWidget,
        );

        // Verify checked radio icon exists
        expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);

        // Verify the card's container decoration is NOT dark burgundy
        final inkWellFinder = find.ancestor(
          of: find.text('Romantic Pink'),
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsOneWidget);

        final containerFinder = find.descendant(
          of: inkWellFinder,
          matching: find.byType(Container),
        );
        final containerWidget = tester.widget<Container>(containerFinder.first);
        final decoration = containerWidget.decoration as BoxDecoration;

        // Container color must have very high luminance (light tint, not dark burgundy)
        final bg = decoration.color!;
        expect(
          bg.computeLuminance(),
          greaterThan(0.70),
          reason: 'Selected card background must be light and legible in light mode',
        );

        // Title text must use dark textPrimary color
        final titleText = tester.widget<Text>(find.text('Romantic Pink'));
        expect(
          titleText.style?.color?.computeLuminance(),
          lessThan(0.20),
          reason: 'Title text must be dark textPrimary with >= 15:1 contrast against light background',
        );

        // Tap Apply Theme
        await tester.tap(find.text('Apply Theme'));
        await tester.pumpAndSettle();

        // Modal closed and active palette updated on SettingsScreen
        expect(find.text('Color Palette Presets'), findsNothing);
        expect(find.text('Romantic Pink'), findsOneWidget);
      },
    );
  });
}
