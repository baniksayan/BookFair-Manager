import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/inventory/data/datasources/inventory_local_datasource.dart';
import 'package:bookfair_manager/features/inventory/data/models/book_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_batch_model.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_batch.dart';
import 'package:bookfair_manager/features/inventory/presentation/screens/inventory_dashboard_screen.dart';
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
        home: const InventoryDashboardScreen(),
      ),
    );
  }

  group('InventoryDashboardScreen Widget Tests', () {
    const db = AppDatabase();
    final now = DateTime(2026, 11, 21);

    testWidgets('Empty state renders when no inventory or purchases exist', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Inventory Ledger Empty'), findsOneWidget);
      expect(find.text('Create First Purchase Batch'), findsOneWidget);
    });

    testWidgets(
      'Key metric cards and action shortcuts render when records exist',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.runAsync(() async {
          final ds = InventoryLocalDataSourceImpl(db);

          // Insert a sample book
          final book = Book(
            id: 'book-widget-1',
            fairId: 'fair-1',
            title: 'Feluda Omnibus Vol 1',
            author: 'Satyajit Ray',
            publisher: 'Ananda Publishers',
            mrpPaise: 65000,
            defaultSellingPricePaise: 52000,
            condition: BookCondition.brandNew,
            isPreviousStock: true,
            openingStockQuantity: 10,
            estimatedCostPaise: 30000,
            createdAt: now,
            updatedAt: now,
          );
          await ds.createBook(BookModel.fromEntity(book));

          // Insert a sample purchase batch
          final batch = PurchaseBatch(
            id: 'batch-widget-1',
            fairId: 'fair-1',
            purchaseDate: now,
            totalQuantity: 20,
            totalBookCostPaise: 400000,
            additionalChargesPaise: 25000,
            totalAcquisitionCostPaise: 425000,
            paymentStatus: 'Paid',
            paymentMethod: 'Bank Transfer',
            createdAt: now,
          );
          await ds.createPurchaseBatch(
            batch: PurchaseBatchModel.fromEntity(batch),
            items: [],
          );
        });

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        // Dashboard Header
        expect(find.text('Inventory Control'), findsOneWidget);

        // Metrics Grid
        expect(find.text('TOTAL TITLES'), findsOneWidget);
        expect(find.text('PURCHASE VALUE'), findsOneWidget);
        expect(find.text('STOCK VALUATION'), findsOneWidget);
        expect(find.text('PURCHASE BATCHES'), findsOneWidget);

        // Action Cards
        expect(find.text('Book Catalogue'), findsOneWidget);
        expect(find.text('New Purchase Batch'), findsOneWidget);
        expect(find.text('Suppliers & Vendors'), findsOneWidget);
        expect(find.text('Purchase History'), findsOneWidget);
      },
    );
  });
}
