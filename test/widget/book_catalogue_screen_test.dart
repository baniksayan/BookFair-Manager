import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/inventory/data/datasources/inventory_local_datasource.dart';
import 'package:bookfair_manager/features/inventory/data/models/book_model.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/presentation/screens/book_catalogue_screen.dart';
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
        home: const BookCatalogueScreen(),
      ),
    );
  }

  group('BookCatalogueScreen Widget Tests', () {
    const db = AppDatabase();
    final now = DateTime(2026, 11, 21);

    testWidgets('Renders search bar, filter chips, and empty state initially', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Book Catalogue'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Conditions'), findsOneWidget);
      expect(find.text('Brand New'), findsOneWidget);
      expect(find.text('No Books in Catalogue'), findsOneWidget);
    });

    testWidgets('Renders book cards with details and filters by search query', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final book1 = Book(
        id: 'book-c1',
        fairId: 'fair-1',
        title: 'Shonku Samagra',
        author: 'Satyajit Ray',
        publisher: 'Ananda',
        mrpPaise: 45000,
        defaultSellingPricePaise: 38000,
        condition: BookCondition.brandNew,
        createdAt: now,
        updatedAt: now,
      );

      final book2 = Book(
        id: 'book-c2',
        fairId: 'fair-1',
        title: 'Byomkesh Bakshi',
        author: 'Sharadindu Bandyopadhyay',
        publisher: 'Patra Bharati',
        mrpPaise: 50000,
        defaultSellingPricePaise: 40000,
        condition: BookCondition.veryGood,
        createdAt: now,
        updatedAt: now,
      );

      await tester.runAsync(() async {
        final ds = InventoryLocalDataSourceImpl(db);
        await ds.createBook(BookModel.fromEntity(book1));
        await ds.createBook(BookModel.fromEntity(book2));
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Both books render
      expect(find.text('Shonku Samagra'), findsOneWidget);
      expect(find.text('Byomkesh Bakshi'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Byomkesh');
      await tester.pumpAndSettle();

      // Only Byomkesh should remain
      expect(find.text('Byomkesh Bakshi'), findsOneWidget);
      expect(find.text('Shonku Samagra'), findsNothing);
    });
  });
}
