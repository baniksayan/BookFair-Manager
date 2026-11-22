import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/activity_log.dart';
import 'package:bookfair_manager/features/inventory/data/datasources/inventory_local_datasource.dart';
import 'package:bookfair_manager/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_batch.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_item.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/stock_movement.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/supplier.dart';
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

  group('InventoryRepositoryImpl Hive Persistence Tests', () {
    late InventoryRepositoryImpl repository;
    late ActivityLogRepositoryImpl activityLogRepo;
    late InventoryLocalDataSourceImpl inventoryDataSource;
    const db = AppDatabase();

    final now = DateTime(2026, 11, 21);

    setUp(() {
      inventoryDataSource = InventoryLocalDataSourceImpl(db);
      final bookFairDataSource = BookFairLocalDataSourceImpl(db);
      activityLogRepo = ActivityLogRepositoryImpl(bookFairDataSource);
      repository = InventoryRepositoryImpl(
        inventoryDataSource,
        activityLogRepo,
      );
    });

    final sampleBook = Book(
      id: 'book-001',
      fairId: 'fair-kolkata',
      title: 'Pather Panchali',
      author: 'Bibhutibhushan Bandyopadhyay',
      publisher: 'Signet Press',
      isbn13: '9788172152871',
      genre: 'Classic Fiction',
      language: 'Bengali',
      mrpPaise: 35000,
      defaultSellingPricePaise: 28000,
      condition: BookCondition.brandNew,
      createdAt: now,
      updatedAt: now,
    );

    test('addBook stores book and logs activity', () async {
      await repository.addBook(sampleBook);

      final fetched = await repository.getBookById('book-001');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Pather Panchali'));
      expect(fetched.mrpPaise, equals(35000));
      expect(fetched.defaultSellingPricePaise, equals(28000));

      final activities = await activityLogRepo.getRecentLogs();
      expect(
        activities.any((a) => a.type == ActivityLogType.bookAdded),
        isTrue,
      );
    });

    test(
      'addBook with opening previous stock creates initial stock movement',
      () async {
        final prevStockBook = Book(
          id: 'book-prev-1',
          fairId: 'fair-kolkata',
          title: 'Gitanjali',
          author: 'Rabindranath Tagore',
          mrpPaise: 25000,
          defaultSellingPricePaise: 20000,
          isPreviousStock: true,
          openingStockQuantity: 15,
          estimatedCostPaise: 12000,
          createdAt: now,
          updatedAt: now,
        );

        await repository.addBook(prevStockBook);

        final stock = await repository.getAvailableStockForBook('book-prev-1');
        expect(stock, equals(15));

        final movements = await repository.getAllStockMovements(
          bookId: 'book-prev-1',
        );
        expect(movements.length, equals(1));
        expect(
          movements.first.movementType,
          equals(StockMovementType.openingStock),
        );
        expect(movements.first.quantity, equals(15));
      },
    );

    test(
      'addBook duplicate ISBN validation triggers DuplicateRecordException',
      () async {
        await repository.addBook(sampleBook);

        final duplicateIsbnBook = Book(
          id: 'book-002',
          fairId: 'fair-kolkata',
          title: 'Different Title with Same ISBN',
          author: 'Another Author',
          isbn13: '9788172152871', // Same ISBN
          mrpPaise: 40000,
          defaultSellingPricePaise: 32000,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () async => await repository.addBook(duplicateIsbnBook),
          throwsA(isA<DuplicateRecordException>()),
        );
      },
    );

    test('updateBook updates fields and timestamps', () async {
      await repository.addBook(sampleBook);

      final updated = sampleBook.copyWith(
        defaultSellingPricePaise: 25000,
        publisher: 'Ananda Publishers',
        updatedAt: now.add(const Duration(hours: 1)),
      );

      await repository.updateBook(updated);

      final fetched = await repository.getBookById('book-001');
      expect(fetched!.defaultSellingPricePaise, equals(25000));
      expect(fetched.publisher, equals('Ananda Publishers'));

      final activities = await activityLogRepo.getRecentLogs();
      expect(
        activities.any((a) => a.type == ActivityLogType.bookUpdated),
        isTrue,
      );
    });

    test('deleteBook soft-deletes the record from active lists', () async {
      await repository.addBook(sampleBook);

      var allBooks = await repository.getAllBooks();
      expect(allBooks.length, equals(1));

      await repository.deleteBook('book-001');

      allBooks = await repository.getAllBooks();
      expect(allBooks.isEmpty, isTrue);

      final fetched = await repository.getBookById('book-001');
      expect(fetched!.isActive, isFalse);
    });

    test('createPurchaseBatch atomically persists batch, items, and stock movements', () async {
      await repository.addBook(sampleBook);

      final batch = PurchaseBatch(
        id: 'batch-001',
        fairId: 'fair-kolkata',
        supplierId: 'supplier-01',
        purchaseDate: now,
        invoiceNumber: 'INV-2026-99',
        purchaseReference: 'PO-KOL-01',
        totalQuantity: 20,
        totalBookCostPaise: 300000, // ₹3,000
        additionalChargesPaise: 20000, // ₹200
        totalAcquisitionCostPaise: 320000, // ₹3,200
        paymentStatus: 'Paid',
        paymentMethod: 'Bank Transfer',
        createdAt: now,
      );

      final item = const PurchaseItem(
        id: 'pitem-001',
        batchId: 'batch-001',
        bookId: 'book-001',
        quantity: 20,
        unitPurchaseCostPaise: 15000, // ₹150 / unit
        lineTotalPaise: 300000,
      );

      await repository.createPurchaseBatch(batch: batch, items: [item]);

      // Verify batch
      final fetchedBatch = await repository.getPurchaseBatchById('batch-001');
      expect(fetchedBatch, isNotNull);
      expect(fetchedBatch!.totalAcquisitionCostPaise, equals(320000));

      // Verify items
      final batchItems = await repository.getItemsForBatch('batch-001');
      expect(batchItems.length, equals(1));
      expect(batchItems.first.unitPurchaseCostPaise, equals(15000));

      // Verify automatic stock movement
      final stock = await repository.getAvailableStockForBook('book-001');
      expect(stock, equals(20));

      final movements = await repository.getAllStockMovements(
        bookId: 'book-001',
      );
      expect(
        movements.any(
          (m) =>
              m.movementType == StockMovementType.purchaseIn &&
              m.quantity == 20,
        ),
        isTrue,
      );
    });

    test(
      'recordStockMovement modifies inventory and ledger balances',
      () async {
        await repository.addBook(sampleBook);

        // Record 10 manual units added
        await repository.recordStockMovement(
          StockMovement(
            id: 'sm-adj-1',
            fairId: 'fair-kolkata',
            bookId: 'book-001',
            quantity: 10,
            movementType: StockMovementType.manualAdjustment,
            movementDate: now,
            createdAt: now,
          ),
        );

        var stock = await repository.getAvailableStockForBook('book-001');
        expect(stock, equals(10));

        // Record 2 sold units
        await repository.recordStockMovement(
          StockMovement(
            id: 'sm-sale-1',
            fairId: 'fair-kolkata',
            bookId: 'book-001',
            quantity: 2,
            movementType: StockMovementType.saleOut,
            movementDate: now.add(const Duration(hours: 1)),
            createdAt: now.add(const Duration(hours: 1)),
          ),
        );

        stock = await repository.getAvailableStockForBook('book-001');
        expect(stock, equals(8));
      },
    );

    test(
      'Supplier CRUD operations persist cleanly with audit logging',
      () async {
        final supplier = Supplier(
          id: 'supp-101',
          name: 'Ananda Publishers Pvt Ltd',
          contactNumber: '+91 33 2221 0000',
          email: 'sales@anandapub.in',
          address: '45 Beniatola Lane, College Street, Kolkata',
          notes: '30-day trade credit with 40% wholesale commission',
          createdAt: now,
          updatedAt: now,
        );

        // Create
        await repository.createSupplier(supplier);
        var fetched = await repository.getSupplierById('supp-101');
        expect(fetched, isNotNull);
        expect(fetched!.name, equals('Ananda Publishers Pvt Ltd'));

        // Update
        final updatedSupplier = supplier.copyWith(
          contactNumber: '+91 33 2221 9999',
          notes: 'Updated terms: 45-day credit',
        );
        await repository.updateSupplier(updatedSupplier);

        fetched = await repository.getSupplierById('supp-101');
        expect(fetched!.contactNumber, equals('+91 33 2221 9999'));

        // Delete
        await repository.deleteSupplier('supp-101');
        fetched = await repository.getSupplierById('supp-101');
        expect(fetched, isNull);
      },
    );
  });
}
