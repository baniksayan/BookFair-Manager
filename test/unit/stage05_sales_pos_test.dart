import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/accounting/domain/services/accounting_calculator.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/financial_operation_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/models/account_transaction_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/financial_operation_model.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/cashbook/domain/services/financial_operation_coordinator.dart';
import 'package:bookfair_manager/features/cashbook/domain/services/financial_recovery_engine.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/inventory/data/datasources/inventory_local_datasource.dart';
import 'package:bookfair_manager/features/inventory/data/models/book_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/stock_movement_model.dart';
import 'package:bookfair_manager/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_batch.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_item.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/stock_movement.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/domain/entities/payment_record.dart';
import 'package:bookfair_manager/features/sales/data/datasources/sales_local_datasource.dart';
import 'package:bookfair_manager/features/sales/data/repositories/sale_repository_impl.dart';
import 'package:bookfair_manager/features/sales/domain/entities/sale_item.dart';
import 'package:bookfair_manager/features/sales/domain/entities/sale_receipt.dart';

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

  const db = AppDatabase();
  final journalDs = const FinancialOperationLocalDataSourceImpl(db);
  final coordinator = FinancialOperationCoordinator(
    journalDataSource: journalDs,
  );
  final recoveryEngine = FinancialRecoveryEngine(
    db: db,
    journalDataSource: journalDs,
  );

  final fairDs = BookFairLocalDataSourceImpl(db);
  final activityRepo = ActivityLogRepositoryImpl(fairDs);
  final cashbookDs = CashbookLocalDataSourceImpl(db);
  final cashbookRepo = CashbookRepositoryImpl(
    cashbookDs,
    activityRepo,
    coordinator: coordinator,
  );
  final paymentDs = PaymentLocalDataSourceImpl(db);
  final inventoryDs = InventoryLocalDataSourceImpl(db);
  final inventoryRepo = InventoryRepositoryImpl(inventoryDs, activityRepo);
  final salesDs = SalesLocalDataSourceImpl(db);
  final salesRepo = SaleRepositoryImpl(
    salesDataSource: salesDs,
    inventoryDataSource: inventoryDs,
    cashbookDataSource: cashbookDs,
    paymentDataSource: paymentDs,
    coordinator: coordinator,
    activityLogRepo: activityRepo,
    db: db,
  );

  const testFairId = 'fair_stage05_01';

  Book createTestBook({
    required String id,
    required String title,
    required int mrpPaise,
    required int defaultSellingPricePaise,
    int? estimatedCostPaise,
    BookCondition condition = BookCondition.brandNew,
  }) {
    return Book(
      id: id,
      fairId: testFairId,
      title: title,
      author: 'Author',
      mrpPaise: mrpPaise,
      defaultSellingPricePaise: defaultSellingPricePaise,
      estimatedCostPaise: estimatedCostPaise,
      condition: condition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  StockMovement createTestMovement({
    required String id,
    required String bookId,
    required StockMovementType movementType,
    required int quantity,
    String? referenceId,
  }) {
    return StockMovement(
      id: id,
      fairId: testFairId,
      bookId: bookId,
      quantity: quantity,
      movementType: movementType,
      referenceId: referenceId,
      movementDate: DateTime.now(),
      notes: 'Test stock movement',
      createdAt: DateTime.now(),
    );
  }

  group('1. Single Cash POS Sales Settlement', () {
    test('atomically logs receipt, items, saleOut stock movement, cashbook inflow, and credits account', () async {
      // 1. Setup Cash Account (Opening ₹5,000)
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_01',
          fairId: testFairId,
          accountName: 'Stall Cashbox',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Setup Book with 10 copies in stock at ₹150 cost, ₹300 MRP
      final book = createTestBook(
        id: 'book_arch_01',
        title: 'Clean Architecture in Practice',
        mrpPaise: 30000,
        defaultSellingPricePaise: 30000,
        estimatedCostPaise: 15000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final initMovement = createTestMovement(
        id: 'sm_initial_01',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 10,
        referenceId: 'batch_init_01',
      );
      await db.stockMovements.put(
        initMovement.id,
        StockMovementModel.fromEntity(initMovement),
      );

      // 3. Perform POS Checkout: 2 copies sold at MRP ₹300 each (Total ₹600)
      const receiptId = 'rcpt_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-2026-0001',
        fairId: testFairId,
        cashierName: 'Cashier Partner A',
        subtotalAmountPaise: 60000,
        discountAmountPaise: 0,
        totalAmountPaise: 60000,
        tenderedAmountPaise: 60000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_001',
          receiptId: receiptId,
          bookId: 'book_arch_01',
          bookTitle: 'Clean Architecture in Practice',
          quantity: 2,
          unitMrpPaise: 30000,
          unitSellingPricePaise: 30000,
          itemDiscountPaise: 0,
          lineTotalPaise: 60000,
          unitCostPaise: 15000,
          lineCogsPaise: 30000,
          lineGrossProfitPaise: 30000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          isCostProvisional: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_rcpt_001',
          fairId: testFairId,
          amountPaise: 60000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_01',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          referenceNumber: 'CASH-0001',
          notes: 'Cash payment at counter',
          createdAt: DateTime.now(),
        ),
      ];

      final committed = await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_pos_sale_001',
      );

      expect(committed.id, equals(receiptId));
      expect(committed.items.length, equals(1));
      expect(committed.totalAmountPaise, equals(60000));

      // 4. Verify Database Records
      final savedReceipt = await salesDs.getReceiptById(receiptId);
      expect(savedReceipt, isNotNull);
      expect(savedReceipt!.totalAmountPaise, equals(60000));

      final savedItems = await salesDs.getItemsForReceipt(receiptId);
      expect(savedItems.length, equals(1));
      expect(savedItems.first.quantity, equals(2));
      expect(savedItems.first.unitCostPaise, equals(15000));
      expect(savedItems.first.lineCogsPaise, equals(30000));
      expect(savedItems.first.lineGrossProfitPaise, equals(30000));

      // 5. Verify Stock Deduction (10 - 2 = 8 available)
      final allMovements = await inventoryDs.getAllStockMovements(
        fairId: testFairId,
      );
      final saleMovement = allMovements.firstWhere(
        (m) => m.referenceId == receiptId,
      );
      expect(saleMovement.movementType, equals(StockMovementType.saleOut.name));
      expect(saleMovement.quantity, equals(2));
      expect(saleMovement.toEntity().netDelta, equals(-2));

      // 6. Verify Cashbook Inflow & Updated Account Balance (₹5,000 + ₹600 = ₹5,600)
      final acc = await cashbookRepo.getAccountById('acc_cash_01');
      expect(acc, isNotNull);
      expect(acc!.currentBalancePaise, equals(560000));

      final txs = await cashbookRepo.getTransactions(
        fairId: testFairId,
        accountId: 'acc_cash_01',
      );
      final saleTx = txs.firstWhere((t) => t.referenceId == receiptId);
      expect(saleTx.direction, equals('inflow'));
      expect(saleTx.amountPaise, equals(60000));
      expect(saleTx.referenceType, equals('sale_receipt'));
    });
  });

  group('2. Split Multi-Account Payment Settlement', () {
    test('splits payment across Cash and UPI accounts with dual inflows matching receipt total', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_split',
          fairId: testFairId,
          accountName: 'Cash Drawer',
          accountType: 'cash',
          openingBalancePaise: 100000, // ₹1,000
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_upi_split',
          fairId: testFairId,
          accountName: 'UPI QR Account',
          accountType: 'upi',
          openingBalancePaise: 200000, // ₹2,000
          currentBalancePaise: 200000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final book = createTestBook(
        id: 'book_split_01',
        title: 'Design Patterns',
        mrpPaise: 100000,
        defaultSellingPricePaise: 100000,
        estimatedCostPaise: 50000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final initMovement = createTestMovement(
        id: 'sm_split_init',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 5,
        referenceId: 'batch_split_init',
      );
      await db.stockMovements.put(
        initMovement.id,
        StockMovementModel.fromEntity(initMovement),
      );

      const receiptId = 'rcpt_split_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-SPLIT-01',
        fairId: testFairId,
        cashierName: 'Cashier Partner B',
        subtotalAmountPaise: 100000,
        discountAmountPaise: 0,
        totalAmountPaise: 100000,
        tenderedAmountPaise: 40000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_split_01',
          receiptId: receiptId,
          bookId: 'book_split_01',
          bookTitle: 'Design Patterns',
          quantity: 1,
          unitMrpPaise: 100000,
          unitSellingPricePaise: 100000,
          itemDiscountPaise: 0,
          lineTotalPaise: 100000,
          unitCostPaise: 50000,
          lineCogsPaise: 50000,
          lineGrossProfitPaise: 50000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          isCostProvisional: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_split_cash',
          fairId: testFairId,
          amountPaise: 40000, // ₹400 Cash
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_split',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          notes: 'Split Cash rail',
          createdAt: DateTime.now(),
        ),
        PaymentRecord(
          id: 'pay_split_upi',
          fairId: testFairId,
          amountPaise: 60000, // ₹600 UPI
          paymentMethod: 'upi',
          paymentDate: DateTime.now(),
          accountId: 'acc_upi_split',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          referenceNumber: 'UPI987654321012',
          notes: 'Split UPI rail',
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_split_001',
      );

      // Verify Cash Account: ₹1,000 + ₹400 = ₹1,400 (140000 paise)
      final cashAcc = await cashbookRepo.getAccountById('acc_cash_split');
      expect(cashAcc!.currentBalancePaise, equals(140000));

      // Verify UPI Account: ₹2,000 + ₹600 = ₹2,600 (260000 paise)
      final upiAcc = await cashbookRepo.getAccountById('acc_upi_split');
      expect(upiAcc!.currentBalancePaise, equals(260000));

      // Total liquid funds increased by exactly ₹1,000 (100000 paise)
      expect(
        cashAcc.currentBalancePaise + upiAcc.currentBalancePaise,
        equals(400000),
      );
    });
  });

  group('3. Cash Change Handling & Inflow Isolation', () {
    test('credits net revenue to cashbook, not tendered amount, when change is given', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_change',
          fairId: testFairId,
          accountName: 'Cash Register',
          accountType: 'cash',
          openingBalancePaise: 300000, // ₹3,000
          currentBalancePaise: 300000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final book = createTestBook(
        id: 'book_change_01',
        title: 'Refactoring',
        mrpPaise: 100000,
        defaultSellingPricePaise: 100000,
        estimatedCostPaise: 50000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final initMovement = createTestMovement(
        id: 'sm_change_init',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 5,
        referenceId: 'batch_change_init',
      );
      await db.stockMovements.put(
        initMovement.id,
        StockMovementModel.fromEntity(initMovement),
      );

      // Customer buys 1 copy for ₹1,000 (100000 paise). Tenders ₹1,200 (120000 paise). Change is ₹200 (20000 paise).
      const receiptId = 'rcpt_change_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-CHANGE-01',
        fairId: testFairId,
        cashierName: 'Cashier Partner C',
        subtotalAmountPaise: 100000,
        discountAmountPaise: 0,
        totalAmountPaise: 100000,
        tenderedAmountPaise: 120000, // ₹1,200 tendered
        changeAmountPaise: 20000, // ₹200 returned
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_change_01',
          receiptId: receiptId,
          bookId: 'book_change_01',
          bookTitle: 'Refactoring',
          quantity: 1,
          unitMrpPaise: 100000,
          unitSellingPricePaise: 100000,
          itemDiscountPaise: 0,
          lineTotalPaise: 100000,
          unitCostPaise: 50000,
          lineCogsPaise: 50000,
          lineGrossProfitPaise: 50000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          isCostProvisional: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_change_cash',
          fairId: testFairId,
          amountPaise: 100000, // Exactly net payable credited
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_change',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          notes: 'Customer tendered ₹1,200; ₹200 returned as change',
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_change_001',
      );

      final cashAcc = await cashbookRepo.getAccountById('acc_cash_change');
      // Account balance must be ₹3,000 + ₹1,000 = ₹4,000 (NOT ₹4,200)
      expect(cashAcc!.currentBalancePaise, equals(400000));

      final txs = await cashbookRepo.getTransactions(
        fairId: testFairId,
        accountId: 'acc_cash_change',
      );
      final tx = txs.firstWhere((t) => t.referenceId == receiptId);
      expect(tx.amountPaise, equals(100000)); // Exactly net revenue
    });
  });

  group('4. Proportional Receipt Discount Allocation', () {
    test('accurately distributes flat receipt discount proportionally across line items', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_disc',
          fairId: testFairId,
          accountName: 'Cash Register',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final bookA = createTestBook(
        id: 'b_disc_1',
        title: 'Book A',
        mrpPaise: 40000, // ₹400
        defaultSellingPricePaise: 40000,
        estimatedCostPaise: 20000,
      );
      final bookB = createTestBook(
        id: 'b_disc_2',
        title: 'Book B',
        mrpPaise: 60000, // ₹600
        defaultSellingPricePaise: 60000,
        estimatedCostPaise: 30000,
      );
      await db.books.put(bookA.id, BookModel.fromEntity(bookA));
      await db.books.put(bookB.id, BookModel.fromEntity(bookB));

      final smA = createTestMovement(
        id: 'sm_disc_1',
        bookId: bookA.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 5,
      );
      final smB = createTestMovement(
        id: 'sm_disc_2',
        bookId: bookB.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 5,
      );
      await db.stockMovements.put(smA.id, StockMovementModel.fromEntity(smA));
      await db.stockMovements.put(smB.id, StockMovementModel.fromEntity(smB));

      // Subtotal = ₹1,000 (100000 paise). Discount = ₹100 (10000 paise). Total = ₹900 (90000 paise).
      // Item 1 (₹400) gets 40% of discount = ₹40 (4000 paise).
      // Item 2 (₹600) gets 60% of discount = ₹60 (6000 paise).
      const receiptId = 'rcpt_disc_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-DISC-01',
        fairId: testFairId,
        cashierName: 'Cashier D',
        subtotalAmountPaise: 100000,
        discountAmountPaise: 10000,
        totalAmountPaise: 90000,
        tenderedAmountPaise: 90000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_disc_1',
          receiptId: receiptId,
          bookId: 'b_disc_1',
          bookTitle: 'Book A',
          quantity: 1,
          unitMrpPaise: 40000,
          unitSellingPricePaise: 40000,
          itemDiscountPaise: 0,
          lineTotalPaise: 40000,
          unitCostPaise: 20000,
          lineCogsPaise: 20000,
          lineGrossProfitPaise: 16000, // 40000 - 4000 disc - 20000 cogs = 16000
          allocatedReceiptDiscountPaise: 4000,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          isCostProvisional: false,
          createdAt: DateTime.now(),
        ),
        SaleItem(
          id: 'sitem_disc_2',
          receiptId: receiptId,
          bookId: 'b_disc_2',
          bookTitle: 'Book B',
          quantity: 1,
          unitMrpPaise: 60000,
          unitSellingPricePaise: 60000,
          itemDiscountPaise: 0,
          lineTotalPaise: 60000,
          unitCostPaise: 30000,
          lineCogsPaise: 30000,
          lineGrossProfitPaise: 24000, // 60000 - 6000 disc - 30000 cogs = 24000
          allocatedReceiptDiscountPaise: 6000,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          isCostProvisional: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_disc_1',
          fairId: testFairId,
          amountPaise: 90000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_disc',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          notes: 'Discounted sale',
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_disc_001',
      );

      final savedItems = await salesDs.getItemsForReceipt(receiptId);
      final item1 = savedItems.firstWhere((i) => i.id == 'sitem_disc_1');
      final item2 = savedItems.firstWhere((i) => i.id == 'sitem_disc_2');

      expect(item1.allocatedReceiptDiscountPaise, equals(4000));
      expect(item2.allocatedReceiptDiscountPaise, equals(6000));
      expect(
        item1.allocatedReceiptDiscountPaise +
            item2.allocatedReceiptDiscountPaise,
        equals(10000),
      );
    });
  });

  group('5. Stock Guards & Out-of-Stock Validation', () {
    test('strictly blocks non-manager checkout when quantity exceeds available stock', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_guard',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final book = createTestBook(
        id: 'b_guard_1',
        title: 'Rare Book',
        mrpPaise: 50000,
        defaultSellingPricePaise: 50000,
        estimatedCostPaise: 25000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final sm = createTestMovement(
        id: 'sm_guard_1',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 1, // Only 1 copy available
      );
      await db.stockMovements.put(sm.id, StockMovementModel.fromEntity(sm));

      // Attempt to checkout 2 copies without manager override
      const receiptId = 'rcpt_guard_fail';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-GUARD-01',
        fairId: testFairId,
        cashierName: 'Cashier E',
        subtotalAmountPaise: 100000,
        discountAmountPaise: 0,
        totalAmountPaise: 100000,
        tenderedAmountPaise: 40000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_guard_fail',
          receiptId: receiptId,
          bookId: 'b_guard_1',
          bookTitle: 'Rare Book',
          quantity: 2, // Exceeds available 1
          unitMrpPaise: 50000,
          unitSellingPricePaise: 50000,
          itemDiscountPaise: 0,
          lineTotalPaise: 100000,
          unitCostPaise: 25000,
          lineCogsPaise: 50000,
          lineGrossProfitPaise: 50000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false, // NO override
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_guard_fail',
          fairId: testFairId,
          amountPaise: 100000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_guard',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      expect(
        () => salesRepo.recordSale(
          receipt: receipt,
          items: items,
          payments: payments,
          clientRequestId: 'req_guard_fail',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Verify no receipt or movements persisted
      final r = await salesDs.getReceiptById(receiptId);
      expect(r, isNull);
    });
  });

  group('6. Manager Stock Override & Provisional Cost', () {
    test('authorizes unverified negative stock sale with audit fields and provisional cost flag', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_override',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Book with 0 stock and 0 purchase batches (cost unknown/provisional)
      final book = createTestBook(
        id: 'b_override_01',
        title: 'Unregistered Book Found on Stall',
        mrpPaise: 25000,
        defaultSellingPricePaise: 25000,
        estimatedCostPaise: 0,
        condition: BookCondition.good,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      const receiptId = 'rcpt_override_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-OVR-01',
        fairId: testFairId,
        cashierName: 'Cashier F',
        subtotalAmountPaise: 25000,
        discountAmountPaise: 0,
        totalAmountPaise: 25000,
        tenderedAmountPaise: 25000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_override_01',
          receiptId: receiptId,
          bookId: 'b_override_01',
          bookTitle: 'Unregistered Book Found on Stall',
          quantity: 1,
          unitMrpPaise: 25000,
          unitSellingPricePaise: 25000,
          itemDiscountPaise: 0,
          lineTotalPaise: 25000,
          unitCostPaise: 0,
          lineCogsPaise: 0,
          lineGrossProfitPaise: 25000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.good.displayName,
          isUnverifiedStock: true, // Authorized
          isCostProvisional: true, // Flagged provisional
          overrideAuthorizerId: 'partner_lead_01',
          overrideReason:
              'Found physical copy on table; authorized by Lead Partner',
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_ovr_01',
          fairId: testFairId,
          amountPaise: 25000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_override',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      final committed = await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_override_001',
      );

      expect(committed.items.first.isUnverifiedStock, isTrue);
      expect(committed.items.first.isCostProvisional, isTrue);
      expect(
        committed.items.first.overrideAuthorizerId,
        equals('partner_lead_01'),
      );
      expect(
        committed.items.first.overrideReason,
        contains('authorized by Lead Partner'),
      );

      // Check stock movement: quantity = 1, netDelta = -1
      final sm = await inventoryDs.getAllStockMovements(fairId: testFairId);
      final movement = sm.firstWhere((m) => m.referenceId == receiptId);
      expect(movement.toEntity().netDelta, equals(-1));
    });
  });

  group('7. Cost Immutability Across Subsequent Procurement', () {
    test('subsequent higher-cost purchase batch does not retroactively alter snapshotted unitCost on historical sale', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_imm',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 1. Initial Batch at cost ₹200
      final book = createTestBook(
        id: 'b_imm_01',
        title: 'Economics Principles',
        mrpPaise: 50000,
        defaultSellingPricePaise: 50000,
        estimatedCostPaise: 20000, // ₹200
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final initMovement = createTestMovement(
        id: 'sm_imm_init',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 5,
        referenceId: 'batch_imm_1',
      );
      await db.stockMovements.put(
        initMovement.id,
        StockMovementModel.fromEntity(initMovement),
      );

      // 2. Complete Sale: snapshotted unitCost = ₹200
      const receiptId = 'rcpt_imm_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-IMM-01',
        fairId: testFairId,
        cashierName: 'Cashier G',
        subtotalAmountPaise: 50000,
        discountAmountPaise: 0,
        totalAmountPaise: 50000,
        tenderedAmountPaise: 50000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_imm_01',
          receiptId: receiptId,
          bookId: 'b_imm_01',
          bookTitle: 'Economics Principles',
          quantity: 1,
          unitMrpPaise: 50000,
          unitSellingPricePaise: 50000,
          itemDiscountPaise: 0,
          lineTotalPaise: 50000,
          unitCostPaise: 20000, // ₹200
          lineCogsPaise: 20000,
          lineGrossProfitPaise: 30000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_imm_01',
          fairId: testFairId,
          amountPaise: 50000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_imm',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_imm_001',
      );

      // 3. Subsequent Procurement at higher cost: ₹350
      await inventoryRepo.createPurchaseBatch(
        batch: PurchaseBatch(
          id: 'batch_imm_2',
          fairId: testFairId,
          supplierId: 'supp_imm_01',
          purchaseDate: DateTime.now(),
          totalQuantity: 10,
          totalBookCostPaise: 350000,
          totalAcquisitionCostPaise: 350000,
          notes: 'New Batch @ ₹350',
          createdAt: DateTime.now(),
        ),
        items: [
          PurchaseItem(
            id: 'pitem_imm_2',
            batchId: 'batch_imm_2',
            bookId: 'b_imm_01',
            quantity: 10,
            unitPurchaseCostPaise: 35000, // ₹350
            lineTotalPaise: 350000,
          ),
        ],
      );

      // 4. Verify historical sale receipt item unitCost remains strictly ₹200 (20000 paise)
      final historicalItems = await salesDs.getItemsForReceipt(receiptId);
      expect(historicalItems.first.unitCostPaise, equals(20000));
      expect(historicalItems.first.lineCogsPaise, equals(20000));
      expect(historicalItems.first.lineGrossProfitPaise, equals(30000));
    });
  });

  group('8. Idempotency & Replay Protection', () {
    test('duplicate submission with identical clientRequestId replays committed receipt without duplicate writes', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_idem',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final book = createTestBook(
        id: 'b_idem_01',
        title: 'Idempotency in Distributed Systems',
        mrpPaise: 40000,
        defaultSellingPricePaise: 40000,
        estimatedCostPaise: 20000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final sm = createTestMovement(
        id: 'sm_idem_init',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 10,
      );
      await db.stockMovements.put(sm.id, StockMovementModel.fromEntity(sm));

      const receiptId = 'rcpt_idem_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-IDEM-01',
        fairId: testFairId,
        cashierName: 'Cashier H',
        subtotalAmountPaise: 40000,
        discountAmountPaise: 0,
        totalAmountPaise: 40000,
        tenderedAmountPaise: 40000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_idem_01',
          receiptId: receiptId,
          bookId: 'b_idem_01',
          bookTitle: 'Idempotency in Distributed Systems',
          quantity: 1,
          unitMrpPaise: 40000,
          unitSellingPricePaise: 40000,
          itemDiscountPaise: 0,
          lineTotalPaise: 40000,
          unitCostPaise: 20000,
          lineCogsPaise: 20000,
          lineGrossProfitPaise: 20000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_idem_01',
          fairId: testFairId,
          amountPaise: 40000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_idem',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      // First submission
      final res1 = await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_stable_idem_001',
      );
      expect(res1.id, equals(receiptId));

      // Second identical submission (same clientRequestId)
      final res2 = await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_stable_idem_001',
      );
      expect(res2.id, equals(receiptId));

      // Verify no duplicate account credit (₹1,000 + ₹400 = ₹1,400, NOT ₹1,800)
      final acc = await cashbookRepo.getAccountById('acc_cash_idem');
      expect(acc!.currentBalancePaise, equals(140000));

      // Verify only 1 saleOut stock movement was logged for this receipt
      final movements = await inventoryDs.getAllStockMovements(
        fairId: testFairId,
      );
      final saleMovements = movements.where((m) => m.referenceId == receiptId);
      expect(saleMovements.length, equals(1));
    });

    test('submission with same clientRequestId but conflicting payload throws IdempotencyConflictException', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_conflict',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const receiptId = 'rcpt_conflict_01';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-CONF-01',
        fairId: testFairId,
        cashierName: 'Cashier H',
        subtotalAmountPaise: 40000,
        discountAmountPaise: 0,
        totalAmountPaise: 40000,
        tenderedAmountPaise: 40000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_conf_01',
          receiptId: receiptId,
          bookId: 'b_conf_01',
          bookTitle: 'Book Conf',
          quantity: 1,
          unitMrpPaise: 40000,
          unitSellingPricePaise: 40000,
          itemDiscountPaise: 0,
          lineTotalPaise: 40000,
          unitCostPaise: 20000,
          lineCogsPaise: 20000,
          lineGrossProfitPaise: 20000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: true,
          overrideAuthorizerId: 'mgr_lead',
          overrideReason: 'Physical count verified',
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_conf_01',
          fairId: testFairId,
          amountPaise: 40000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_conflict',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_conflict_key',
      );

      // Attempt second submission with same key but altered total (2 copies for ₹800)
      final conflictingReceipt = receipt.copyWith(
        subtotalAmountPaise: 80000,
        totalAmountPaise: 80000,
        tenderedAmountPaise: 80000,
      );
      final conflictingItems = [
        items.first.copyWith(
          quantity: 2,
          lineTotalPaise: 80000,
          lineCogsPaise: 40000,
          lineGrossProfitPaise: 40000,
        ),
      ];
      final conflictingPayments = [payments.first.copyWith(amountPaise: 80000)];

      expect(
        () => salesRepo.recordSale(
          receipt: conflictingReceipt,
          items: conflictingItems,
          payments: conflictingPayments,
          clientRequestId: 'req_conflict_key',
        ),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });
  });

  group('9. Receipt-Linked Customer Returns & Refunds', () {
    test('restocked customer return restores inventory and debits cashbook account', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_ret',
          fairId: testFairId,
          accountName: 'Cash Drawer',
          accountType: 'cash',
          openingBalancePaise: 500000, // ₹5,000
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final book = createTestBook(
        id: 'b_ret_01',
        title: 'Domain-Driven Design',
        mrpPaise: 80000, // ₹800
        defaultSellingPricePaise: 80000,
        estimatedCostPaise: 40000,
      );
      await db.books.put(book.id, BookModel.fromEntity(book));

      final initMovement = createTestMovement(
        id: 'sm_ret_init',
        bookId: book.id,
        movementType: StockMovementType.purchaseIn,
        quantity: 10,
        referenceId: 'b_ret_init',
      );
      await db.stockMovements.put(
        initMovement.id,
        StockMovementModel.fromEntity(initMovement),
      );

      // 1. Initial Sale of 2 copies @ ₹800 = ₹1,600 (160000 paise)
      const receiptId = 'rcpt_ret_001';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-RET-01',
        fairId: testFairId,
        cashierName: 'Cashier I',
        subtotalAmountPaise: 160000,
        discountAmountPaise: 0,
        totalAmountPaise: 160000,
        tenderedAmountPaise: 160000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_ret_01',
          receiptId: receiptId,
          bookId: 'b_ret_01',
          bookTitle: 'Domain-Driven Design',
          quantity: 2,
          unitMrpPaise: 80000,
          unitSellingPricePaise: 80000,
          itemDiscountPaise: 0,
          lineTotalPaise: 160000,
          unitCostPaise: 40000,
          lineCogsPaise: 80000,
          lineGrossProfitPaise: 80000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: false,
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_ret_01',
          fairId: testFairId,
          amountPaise: 160000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_ret',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_ret_sale_001',
      );

      // Balance after sale: ₹5,000 + ₹1,600 = ₹6,600 (660000 paise)
      var acc = await cashbookRepo.getAccountById('acc_cash_ret');
      expect(acc!.currentBalancePaise, equals(660000));

      // 2. Customer Returns 1 copy with restocking (Refund ₹800)
      final updatedReceipt = await salesRepo.processSaleReturn(
        receiptId: receiptId,
        saleItemId: 'sitem_ret_01',
        returnQuantity: 1,
        condition: BookCondition.brandNew,
        isRestocked: true,
        refundAmountPaise: 80000,
        refundAccountId: 'acc_cash_ret',
        reason: 'Duplicate purchase by family member',
        processedByPartnerId: 'partner_01',
        clientRequestId: 'req_ret_action_001',
      );

      // Verify updated receipt fields
      expect(updatedReceipt.refundedAmountPaise, equals(80000));
      expect(updatedReceipt.paymentStatus, equals('partially_refunded'));

      // Verify updated sale item
      final updatedItems = await salesDs.getItemsForReceipt(receiptId);
      final item = updatedItems.firstWhere((i) => i.id == 'sitem_ret_01');
      expect(item.returnedQuantity, equals(1));

      // Verify restocking movement: customerReturnIn (+1 netDelta)
      final movements = await inventoryDs.getAllStockMovements(
        fairId: testFairId,
      );
      final returnMovement = movements.firstWhere(
        (m) => m.movementType == StockMovementType.customerReturnIn.name,
      );
      expect(returnMovement.quantity, equals(1));
      expect(returnMovement.toEntity().netDelta, equals(1));

      // Verify cashbook debit: ₹6,600 - ₹800 = ₹5,800 (580000 paise)
      acc = await cashbookRepo.getAccountById('acc_cash_ret');
      expect(acc!.currentBalancePaise, equals(580000));

      final txs = await cashbookRepo.getTransactions(
        fairId: testFairId,
        accountId: 'acc_cash_ret',
      );
      final refundTx = txs.firstWhere(
        (t) => t.transactionType == 'sale_refund',
      );
      expect(refundTx.direction, equals('outflow'));
      expect(refundTx.amountPaise, equals(80000));
    });

    test(
      'damaged return disburses refund without restocking physical inventory',
      () async {
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_cash_dmg',
            fairId: testFairId,
            accountName: 'Cash Drawer',
            accountType: 'cash',
            openingBalancePaise: 200000,
            currentBalancePaise: 200000,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final book = createTestBook(
          id: 'b_dmg_01',
          title: 'Damaged Book Test',
          mrpPaise: 30000,
          defaultSellingPricePaise: 30000,
          estimatedCostPaise: 15000,
        );
        await db.books.put(book.id, BookModel.fromEntity(book));

        final sm = createTestMovement(
          id: 'sm_dmg_init',
          bookId: book.id,
          movementType: StockMovementType.purchaseIn,
          quantity: 2,
        );
        await db.stockMovements.put(sm.id, StockMovementModel.fromEntity(sm));

        // Sale of 1 copy
        const receiptId = 'rcpt_dmg_001';
        final receipt = SaleReceipt(
          id: receiptId,
          receiptNumber: 'RCPT-DMG-01',
          fairId: testFairId,
          cashierName: 'Cashier J',
          subtotalAmountPaise: 30000,
          discountAmountPaise: 0,
          totalAmountPaise: 30000,
          tenderedAmountPaise: 30000,
          changeAmountPaise: 0,
          refundedAmountPaise: 0,
          paymentStatus: 'paid',
          createdAt: DateTime.now(),
        );

        final List<SaleItem> items = [
          SaleItem(
            id: 'sitem_dmg_01',
            receiptId: receiptId,
            bookId: 'b_dmg_01',
            bookTitle: 'Damaged Book Test',
            quantity: 1,
            unitMrpPaise: 30000,
            unitSellingPricePaise: 30000,
            itemDiscountPaise: 0,
            lineTotalPaise: 30000,
            unitCostPaise: 15000,
            lineCogsPaise: 15000,
            lineGrossProfitPaise: 15000,
            allocatedReceiptDiscountPaise: 0,
            condition: BookCondition.brandNew.displayName,
            isUnverifiedStock: false,
            createdAt: DateTime.now(),
          ),
        ];

        final List<PaymentRecord> payments = [
          PaymentRecord(
            id: 'pay_dmg_01',
            fairId: testFairId,
            amountPaise: 30000,
            paymentMethod: 'cash',
            paymentDate: DateTime.now(),
            accountId: 'acc_cash_dmg',
            relatedEntityType: 'sale_receipt',
            relatedEntityId: receiptId,
            createdAt: DateTime.now(),
          ),
        ];

        await salesRepo.recordSale(
          receipt: receipt,
          items: items,
          payments: payments,
          clientRequestId: 'req_dmg_sale',
        );

        // Return copy as damaged (isRestocked: false)
        await salesRepo.processSaleReturn(
          receiptId: receiptId,
          saleItemId: 'sitem_dmg_01',
          returnQuantity: 1,
          condition: BookCondition.damaged,
          isRestocked: false,
          refundAmountPaise: 30000,
          refundAccountId: 'acc_cash_dmg',
          reason: 'Customer discovered torn pages',
          clientRequestId: 'req_dmg_return',
        );

        // Verify movement logged as damaged (netDelta = 0)
        final movements = await inventoryDs.getAllStockMovements(
          fairId: testFairId,
        );
        final dmgMovement = movements.firstWhere(
          (m) => m.movementType == StockMovementType.damaged.name,
        );
        expect(dmgMovement.toEntity().netDelta, equals(0));

        // Verify refund outflow credited back to customer
        final acc = await cashbookRepo.getAccountById('acc_cash_dmg');
        expect(acc!.currentBalancePaise, equals(200000));
      },
    );

    test('rejects return quantity exceeding original sold quantity', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash_exceed',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const receiptId = 'rcpt_exceed_01';
      final receipt = SaleReceipt(
        id: receiptId,
        receiptNumber: 'RCPT-EXC-01',
        fairId: testFairId,
        cashierName: 'Cashier K',
        subtotalAmountPaise: 20000,
        discountAmountPaise: 0,
        totalAmountPaise: 20000,
        tenderedAmountPaise: 20000,
        changeAmountPaise: 0,
        refundedAmountPaise: 0,
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> items = [
        SaleItem(
          id: 'sitem_exceed_01',
          receiptId: receiptId,
          bookId: 'b_exc_01',
          bookTitle: 'Book Exc',
          quantity: 1, // Only 1 sold
          unitMrpPaise: 20000,
          unitSellingPricePaise: 20000,
          itemDiscountPaise: 0,
          lineTotalPaise: 20000,
          unitCostPaise: 10000,
          lineCogsPaise: 10000,
          lineGrossProfitPaise: 10000,
          allocatedReceiptDiscountPaise: 0,
          condition: BookCondition.brandNew.displayName,
          isUnverifiedStock: true,
          overrideAuthorizerId: 'mgr_lead',
          overrideReason: 'Physical count verified',
          createdAt: DateTime.now(),
        ),
      ];

      final List<PaymentRecord> payments = [
        PaymentRecord(
          id: 'pay_exc_01',
          fairId: testFairId,
          amountPaise: 20000,
          paymentMethod: 'cash',
          paymentDate: DateTime.now(),
          accountId: 'acc_cash_exceed',
          relatedEntityType: 'sale_receipt',
          relatedEntityId: receiptId,
          createdAt: DateTime.now(),
        ),
      ];

      await salesRepo.recordSale(
        receipt: receipt,
        items: items,
        payments: payments,
        clientRequestId: 'req_exc_sale',
      );

      // Attempt to return 2 copies
      expect(
        () => salesRepo.processSaleReturn(
          receiptId: receiptId,
          saleItemId: 'sitem_exceed_01',
          returnQuantity: 2, // Exceeds 1
          condition: BookCondition.brandNew,
          isRestocked: true,
          refundAmountPaise: 20000,
          refundAccountId: 'acc_cash_exceed',
          reason: 'Excess return',
          clientRequestId: 'req_exc_fail',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('10. Crash Recovery Reconciliation for Sales Operations', () {
    test('recovery engine rolls back orphaned stock movements and voids partial transaction on interrupted sale settlement', () async {
      // 1. Setup Cash Account (Opening ₹5,000)
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crash_01',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Simulate partial write crash:
      // Stock movement logged, Transaction logged, but process died before receipt committed.
      const opId = 'op_crash_sale_001';
      const receiptId = 'rcpt_crash_001';

      await db.stockMovements.put(
        'sm_crash_01',
        StockMovementModel(
          id: 'sm_crash_01',
          fairId: testFairId,
          bookId: 'b_crash_01',
          movementType: StockMovementType.saleOut.name,
          quantity: 2,
          referenceId: receiptId,
          movementDateEpoch: DateTime.now().millisecondsSinceEpoch,
          notes: 'Orphaned Sale Movement',
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      await db.accountTransactions.put(
        'tx_crash_01',
        AccountTransactionModel(
          id: 'tx_crash_01',
          fairId: testFairId,
          accountId: 'acc_crash_01',
          transactionType: 'sale_revenue',
          direction: 'inflow',
          amountPaise: 60000,
          transactionDateEpoch: DateTime.now().millisecondsSinceEpoch,
          referenceType: 'sale_receipt',
          referenceId: receiptId,
          description: 'Orphaned Sale Inflow',
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Incomplete journal entry in 'in_flight' status
      await db.financialOperations.put(
        opId,
        FinancialOperationModel(
          id: opId,
          fairId: testFairId,
          idempotencyKey: 'sales_settlement_${testFairId}_req_crash_sale_001',
          requestFingerprint: 'fingerprint_crash_01',
          operationType: 'sales_settlement',
          primaryEntityId: receiptId,
          status: 'processing',
          amountPaise: 60000,
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
          updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          payloadJson: jsonEncode({
            'receiptId': receiptId,
            'clientRequestId': 'req_crash_sale_001',
            'fairId': testFairId,
            'totalAmountPaise': 60000,
            'accountIds': ['acc_crash_01'],
          }),
        ),
      );

      // 3. Run Recovery Engine
      final recoveredCount = await recoveryEngine.runStartupRecovery();
      expect(recoveredCount, equals(1));

      // 4. Verify Orphaned stock movement was deleted
      final movements = await inventoryDs.getAllStockMovements(
        fairId: testFairId,
      );
      expect(movements.any((m) => m.id == 'sm_crash_01'), isFalse);

      // 5. Verify Transaction was voided with void_abandoned
      final tx = cashbookDs.getTransactionById('tx_crash_01');
      expect(tx, isNotNull);
      expect(tx!.transactionType, equals('void_abandoned'));
      expect(tx.referenceType, equals('void_abandoned'));

      // 6. Verify Journal status is now rolled_back
      final op = journalDs.getOperationById(opId);
      expect(op, isNotNull);
      expect(op!.status, equals('rolled_back'));

      // 7. Verify Account balance remains original ₹5,000 (500000 paise)
      final acc = await cashbookRepo.getAccountById('acc_crash_01');
      expect(acc!.currentBalancePaise, equals(500000));
    });
  });

  group('11. Real-Time Accounting Profit Metrics (Stage 05 Unlocked)', () {
    test('calculateMetrics derives gross profit, net profit, COGS, and payment collections correctly', () {
      const calculator = AccountingCalculator();

      final List<SaleReceipt> receipts = [
        SaleReceipt(
          id: 'r_acc_1',
          fairId: testFairId,
          receiptNumber: 'R1',
          subtotalAmountPaise: 100000, // ₹1,000
          discountAmountPaise: 10000, // ₹100
          totalAmountPaise: 90000, // ₹900
          tenderedAmountPaise: 90000,
          changeAmountPaise: 0,
          refundedAmountPaise: 10000, // ₹100 refunded
          paymentStatus: 'partially_refunded',
          createdAt: DateTime.now(),
          items: [
            SaleItem(
              id: 'si_1',
              receiptId: 'r_acc_1',
              bookId: 'b1',
              bookTitle: 'Book 1',
              quantity: 2,
              unitMrpPaise: 50000,
              unitSellingPricePaise: 50000,
              itemDiscountPaise: 0,
              lineTotalPaise: 100000,
              unitCostPaise: 20000, // ₹200 each -> COGS = ₹400
              lineCogsPaise: 40000,
              lineGrossProfitPaise: 50000,
              allocatedReceiptDiscountPaise: 10000,
              condition: BookCondition.brandNew.displayName,
              isUnverifiedStock: false,
              createdAt: DateTime.now(),
            ),
          ],
        ),
      ];

      // Operating Expenses: Stall Rent = ₹200 (20000 paise)
      final List<Expense> expenses = [
        Expense(
          id: 'exp_rent',
          fairId: testFairId,
          categoryId: 'cat_rent',
          title: 'Stall Rent',
          amountPaise: 20000,
          expenseDate: DateTime.now(),
          paidAmountPaise: 20000,
          outstandingAmountPaise: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final List<CashbookAccount> accounts = [
        CashbookAccount(
          id: 'acc_cash_rep',
          fairId: testFairId,
          accountName: 'Cash',
          accountType: 'cash',
          openingBalancePaise: 0,
          currentBalancePaise: 80000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final metrics = calculator.calculateMetrics(
        expenses: expenses,
        accounts: accounts,
        payments: const [],
        purchaseBatches: const [],
        investments: const [],
        receipts: receipts,
      );

      // Gross Sales: ₹900 (90000 paise)
      expect(metrics.totalGrossSalesPaise, equals(90000));
      // Refunds: ₹100 (10000 paise)
      expect(metrics.totalSalesRefundsPaise, equals(10000));
      // Net Sales Revenue: ₹900 - ₹100 = ₹800 (80000 paise)
      expect(metrics.netSalesRevenuePaise, equals(80000));
      // Total COGS: ₹400 (40000 paise)
      expect(metrics.totalCogsPaise, equals(40000));
      // Realized Gross Profit: Net Revenue (₹800) - COGS (₹400) = ₹400 (40000 paise)
      expect(metrics.grossProfitPaise, equals(40000));
      // Net Profit: Gross Profit (₹400) - Fair Expenses (₹200) = ₹200 (20000 paise)
      expect(metrics.netProfitPaise, equals(20000));
      // Gross margin: (400 / 800) * 100 = 50.0%
      expect(metrics.grossMarginPercentage, equals(50.0));
    });
  });
}
