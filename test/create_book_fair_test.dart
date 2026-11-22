import 'package:bookfair_manager/app/app.dart';
import 'package:bookfair_manager/core/components/app_snackbar.dart';
import 'package:bookfair_manager/core/localization/app_strings.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/create_book_fair_screen.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/view_models/create_book_fair_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

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

  testWidgets('Navigation to Create Book Fair screen renders all fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: BookFairManagerApp()));
    await tester.pumpAndSettle();

    final ctaFinder = find.text(AppStrings.dashboardHeroAction);
    expect(ctaFinder, findsOneWidget);
    await tester.tap(ctaFinder);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.createFairTitle), findsWidgets);
    expect(find.text(AppStrings.fieldFairName), findsOneWidget);
    expect(find.text(AppStrings.fieldLocation), findsOneWidget);
    expect(find.text(AppStrings.fieldEstimatedBudget), findsOneWidget);
    expect(find.text(AppStrings.fieldInitialInvestment), findsOneWidget);
    expect(find.text(AppStrings.fieldNumPartners), findsOneWidget);
    expect(find.text(AppStrings.fieldDescription), findsOneWidget);
  });

  testWidgets('Form validation triggers on empty submission', (
    WidgetTester tester,
  ) async {
    // Increase test surface size so the entire form fits comfortably
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: BookFairManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.dashboardHeroAction));
    await tester.pumpAndSettle();

    final btnFinder = find.text(AppStrings.btnCreateFair);
    await tester.ensureVisible(btnFinder);
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    expect(find.text('Book fair name is required'), findsOneWidget);
    expect(find.text('Venue location is required'), findsOneWidget);
  });

  testWidgets('Save draft displays confirmation snackbar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: BookFairManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.dashboardHeroAction));
    await tester.pumpAndSettle();

    final draftFinder = find.text(AppStrings.btnSaveDraft);
    await tester.ensureVisible(draftFinder);

    await tester.runAsync(() async {
      final element = tester.element(find.byType(CreateBookFairScreen));
      final container = ProviderScope.containerOf(element);
      await container
          .read(createBookFairViewModelProvider.notifier)
          .saveDraft();
    });

    final element = tester.element(find.byType(CreateBookFairScreen));
    AppSnackbar.show(
      element,
      message: 'Draft saved to local storage.',
      variant: AppSnackbarVariant.success,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Draft saved to local storage.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Valid form population validates without errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: BookFairManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.dashboardHeroAction));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(CreateBookFairScreen));
    final container = ProviderScope.containerOf(element);
    final notifier = container.read(createBookFairViewModelProvider.notifier);
    notifier.setStartDate(DateTime(2026, 12, 1));
    notifier.setEndDate(DateTime(2026, 12, 15));
    notifier.setName('Dhaka Book Fair 2026');
    notifier.setLocation('Bangla Academy Ground');
    notifier.setEstimatedBudget('250000');
    notifier.setInitialInvestment('75000');
    await tester.pumpAndSettle();

    expect(notifier.validate(), isTrue);
    expect(
      container.read(createBookFairViewModelProvider).validationErrors,
      isEmpty,
    );
  });
}
