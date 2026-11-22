import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/book_fair_model.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/book_fair_list_screen.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/widgets/book_fair_card.dart';
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
    return const ProviderScope(child: MaterialApp(home: BookFairListScreen()));
  }

  group('BookFairListScreen Widget Tests', () {
    final now = DateTime.now();

    final fairActive = BookFair(
      id: 'fair-act',
      name: 'Delhi World Book Fair',
      location: 'Hall 5, Pragati Maidan',
      city: 'New Delhi',
      state: 'Delhi',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 6)),
      estimatedBudgetPaise: 30000000,
      initialInvestmentPaise: 15000000,
      isArchived: false,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    );

    final fairUpcoming = BookFair(
      id: 'fair-upc',
      name: 'Kolkata International Book Fair',
      location: 'Milan Mela Grounds',
      city: 'Kolkata',
      state: 'West Bengal',
      startDate: now.add(const Duration(days: 14)),
      endDate: now.add(const Duration(days: 25)),
      estimatedBudgetPaise: 40000000,
      initialInvestmentPaise: 20000000,
      isArchived: false,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
    );

    testWidgets(
      'Empty state is displayed when database has no registered fairs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        expect(find.text('No Book Fairs Registered'), findsOneWidget);
        expect(find.text('Add Your First Book Fair'), findsOneWidget);
        expect(find.byType(BookFairCard), findsNothing);
      },
    );

    testWidgets('Renders fair cards when records exist in database', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        const db = AppDatabase();
        final ds = BookFairLocalDataSourceImpl(db);
        await ds.createBookFair(BookFairModel.fromEntity(fairActive));
        await ds.createBookFair(BookFairModel.fromEntity(fairUpcoming));
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Delhi World Book Fair'), findsOneWidget);
      expect(find.text('Kolkata International Book Fair'), findsOneWidget);
      expect(find.byType(BookFairCard), findsNWidgets(2));
    });

    testWidgets('Search bar input dynamically filters rendered cards', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        const db = AppDatabase();
        final ds = BookFairLocalDataSourceImpl(db);
        await ds.createBookFair(BookFairModel.fromEntity(fairActive));
        await ds.createBookFair(BookFairModel.fromEntity(fairUpcoming));
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(BookFairCard), findsNWidgets(2));

      // Enter search text
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Delhi');
      await tester.pumpAndSettle();

      expect(find.text('Delhi World Book Fair'), findsOneWidget);
      expect(find.text('Kolkata International Book Fair'), findsNothing);
      expect(find.byType(BookFairCard), findsOneWidget);
    });

    testWidgets('Filter tab switching filters cards by status', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        const db = AppDatabase();
        final ds = BookFairLocalDataSourceImpl(db);
        await ds.createBookFair(BookFairModel.fromEntity(fairActive));
        await ds.createBookFair(BookFairModel.fromEntity(fairUpcoming));
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap on "Active" tab
      final activeChip = find.text('Active');
      expect(activeChip, findsOneWidget);
      await tester.tap(activeChip);
      await tester.pumpAndSettle();

      expect(find.text('Delhi World Book Fair'), findsOneWidget);
      expect(find.text('Kolkata International Book Fair'), findsNothing);

      // Tap on "Upcoming" tab
      final upcomingChip = find.text('Upcoming');
      expect(upcomingChip, findsOneWidget);
      await tester.tap(upcomingChip);
      await tester.pumpAndSettle();

      expect(find.text('Delhi World Book Fair'), findsNothing);
      expect(find.text('Kolkata International Book Fair'), findsOneWidget);
    });
  });
}
