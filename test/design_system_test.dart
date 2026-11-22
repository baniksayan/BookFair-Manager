import 'package:bookfair_manager/app/theme/app_colors.dart';
import 'package:bookfair_manager/app/theme/app_radius.dart';
import 'package:bookfair_manager/app/theme/app_spacing.dart';
import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Strict Palette Compliance Tests', () {
    const approvedHexValues = <int>{
      0xFF03071E,
      0xFF370617,
      0xFF6A040F,
      0xFF9D0208,
      0xFFD00000,
      0xFFDC2F02,
      0xFFE85D04,
      0xFFF48C06,
      0xFFFAA307,
      0xFFFFBA08,
      0xFF000000,
      0xFFFFFFFF,
    };

    test('All AppColors constants match the 12 approved palette values', () {
      final constants = [
        AppColors.c03071E,
        AppColors.c370617,
        AppColors.c6A040F,
        AppColors.c9D0208,
        AppColors.cD00000,
        AppColors.cDC2F02,
        AppColors.cE85D04,
        AppColors.cF48C06,
        AppColors.cFAA307,
        AppColors.cFFBA08,
        AppColors.c000000,
        AppColors.cFFFFFF,
      ];

      for (final color in constants) {
        expect(
          approvedHexValues.contains(color.toARGB32()),
          isTrue,
          reason:
              'Color 0x${color.toARGB32().toRadixString(16)} must be in approved palette',
        );
      }
    });

    test('All semantic tokens in Light Mode use approved palette colors', () {
      final light = AppColors.light;
      final tokens = [
        light.primary,
        light.primaryDark,
        light.secondary,
        light.accent,
        light.background,
        light.surface,
        light.surfaceSecondary,
        light.textPrimary,
        light.textSecondary,
        light.border,
        light.divider,
        light.success,
        light.warning,
        light.error,
        light.info,
        light.disabled,
      ];

      for (final color in tokens) {
        expect(
          approvedHexValues.contains(color.toARGB32()),
          isTrue,
          reason:
              'Light token 0x${color.toARGB32().toRadixString(16)} must be approved',
        );
      }

      // Ensure light mode secondary surface is never a dark/inverted color
      expect(
        light.surfaceSecondary.computeLuminance(),
        greaterThan(0.70),
        reason: 'Light mode surfaceSecondary must be high-luminance to prevent dark-on-dark UI defects',
      );
    });

    test('All semantic tokens in Dark Mode use approved palette colors', () {
      final dark = AppColors.dark;
      final tokens = [
        dark.primary,
        dark.primaryDark,
        dark.secondary,
        dark.accent,
        dark.background,
        dark.surface,
        dark.surfaceSecondary,
        dark.textPrimary,
        dark.textSecondary,
        dark.border,
        dark.divider,
        dark.success,
        dark.warning,
        dark.error,
        dark.info,
        dark.disabled,
      ];

      for (final color in tokens) {
        expect(
          approvedHexValues.contains(color.toARGB32()),
          isTrue,
          reason:
              'Dark token 0x${color.toARGB32().toRadixString(16)} must be approved',
        );
      }
    });
  });

  group('Spacing and Radius Tokens Tests', () {
    test('Spacing values match specification', () {
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s20, 20.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
      expect(AppSpacing.s40, 40.0);
      expect(AppSpacing.s48, 48.0);
    });

    test('Radius values match specification', () {
      expect(AppRadius.small, 6.0);
      expect(AppRadius.medium, 10.0);
      expect(AppRadius.large, 16.0);
      expect(AppRadius.extraLarge, 24.0);
      expect(AppRadius.full, 999.0);
    });
  });

  group('Reusable Components Widget Tests', () {
    testWidgets('AppButton renders properly across variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: Column(
                children: [
                  AppButton(text: 'Primary Button', onPressed: () {}),
                  AppButton.outlined(text: 'Outlined Button', onPressed: () {}),
                  AppButton.destructive(text: 'Delete', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Primary Button'), findsOneWidget);
      expect(find.text('Outlined Button'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('AppTextField renders label, hint, and accepts input', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AppTextField(
                controller: controller,
                label: 'Test Label',
                hint: 'Test Hint',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.text('Test Hint'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello BookFair');
      expect(controller.text, 'Hello BookFair');
    });

    testWidgets('AppBadge renders variant correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Center(child: AppBadge.sampleData())),
        ),
      );

      expect(find.text('SAMPLE DATA'), findsOneWidget);
    });

    testWidgets(
      'DEF-001 GPU fix: AppCard with gradient leaves BoxDecoration color null to prevent shader clearing',
      (tester) async {
        const testGradient = LinearGradient(
          colors: [Color(0xFF370617), Color(0xFF6A040F)],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: AppCard(
                  gradient: testGradient,
                  child: Text('Gradient Card'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Gradient Card'), findsOneWidget);

        // Find Container inside AppCard
        final containerFinder = find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        );
        expect(containerFinder, findsOneWidget);

        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(
          decoration!.color,
          isNull,
          reason: 'color must be null when gradient is present so GPU rasterizer does not multiply shader by 0 alpha',
        );
        expect(decoration.gradient, equals(testGradient));
      },
    );

    testWidgets(
      'AppCard without gradient sets Material color to surface background and leaves BoxDecoration color null',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(child: AppCard(child: Text('Standard Card'))),
            ),
          ),
        );

        expect(find.text('Standard Card'), findsOneWidget);

        final containerFinder = find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, isNull);
        expect(decoration.gradient, isNull);

        final materialFinder = find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Material),
        );
        final material = tester.widget<Material>(materialFinder);
        expect(material.color, equals(AppTheme.lightTheme.colorScheme.surface));
      },
    );
  });
}
