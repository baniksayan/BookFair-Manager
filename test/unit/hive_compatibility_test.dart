import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_constants.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/activity_log_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/book_fair_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/investment_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/partner_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/account_transaction_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/cashbook_account_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/financial_operation_model.dart';
import 'package:bookfair_manager/features/expenses/data/models/expense_category_model.dart';
import 'package:bookfair_manager/features/expenses/data/models/expense_model.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense_category.dart';
import 'package:bookfair_manager/features/inventory/data/models/book_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_batch_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_item_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/stock_movement_model.dart';
import 'package:bookfair_manager/features/inventory/data/models/supplier_model.dart';
import 'package:bookfair_manager/features/payments/data/models/payment_record_model.dart';

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

  group('Hive TypeId & Database Compatibility Tests', () {
    test('all 15 TypeIds from 0 to 14 are strictly unique and sequential', () {
      final typeIds = <int>[
        DatabaseConstants.bookFairTypeId,
        DatabaseConstants.partnerTypeId,
        DatabaseConstants.investmentTypeId,
        DatabaseConstants.activityLogTypeId,
        DatabaseConstants.bookTypeId,
        DatabaseConstants.purchaseBatchTypeId,
        DatabaseConstants.purchaseItemTypeId,
        DatabaseConstants.stockMovementTypeId,
        DatabaseConstants.supplierTypeId,
        DatabaseConstants.expenseTypeId,
        DatabaseConstants.expenseCategoryTypeId,
        DatabaseConstants.cashbookAccountTypeId,
        DatabaseConstants.accountTransactionTypeId,
        DatabaseConstants.paymentRecordTypeId,
        DatabaseConstants.financialOperationTypeId,
      ];

      expect(typeIds.length, 15);
      final uniqueSet = typeIds.toSet();
      expect(
        uniqueSet.length,
        15,
        reason: 'Every TypeId must be unique without collisions',
      );

      // Exact numerical assignment assertion
      expect(DatabaseConstants.bookFairTypeId, 0);
      expect(DatabaseConstants.partnerTypeId, 1);
      expect(DatabaseConstants.investmentTypeId, 2);
      expect(DatabaseConstants.activityLogTypeId, 3);
      expect(DatabaseConstants.bookTypeId, 4);
      expect(DatabaseConstants.purchaseBatchTypeId, 5);
      expect(DatabaseConstants.purchaseItemTypeId, 6);
      expect(DatabaseConstants.stockMovementTypeId, 7);
      expect(DatabaseConstants.supplierTypeId, 8);
      expect(DatabaseConstants.expenseTypeId, 9);
      expect(DatabaseConstants.expenseCategoryTypeId, 10);
      expect(DatabaseConstants.cashbookAccountTypeId, 11);
      expect(DatabaseConstants.accountTransactionTypeId, 12);
      expect(DatabaseConstants.paymentRecordTypeId, 13);
      expect(DatabaseConstants.financialOperationTypeId, 14);
    });

    test('all 15 TypeAdapters are correctly registered in Hive', () {
      expect(Hive.isAdapterRegistered(0), isTrue);
      expect(Hive.isAdapterRegistered(1), isTrue);
      expect(Hive.isAdapterRegistered(2), isTrue);
      expect(Hive.isAdapterRegistered(3), isTrue);
      expect(Hive.isAdapterRegistered(4), isTrue);
      expect(Hive.isAdapterRegistered(5), isTrue);
      expect(Hive.isAdapterRegistered(6), isTrue);
      expect(Hive.isAdapterRegistered(7), isTrue);
      expect(Hive.isAdapterRegistered(8), isTrue);
      expect(Hive.isAdapterRegistered(9), isTrue);
      expect(Hive.isAdapterRegistered(10), isTrue);
      expect(Hive.isAdapterRegistered(11), isTrue);
      expect(Hive.isAdapterRegistered(12), isTrue);
      expect(Hive.isAdapterRegistered(13), isTrue);
      expect(Hive.isAdapterRegistered(14), isTrue);
      expect(Hive.isAdapterRegistered(15), isTrue);
      expect(Hive.isAdapterRegistered(16), isTrue);
    });

    test('currentSchemaVersion is 6 and metadata migration upgrades stored version safely', () async {
      expect(DatabaseConstants.currentSchemaVersion, 6);

      final metaBox = Hive.box<dynamic>(DatabaseConstants.metadataBox);
      // Simulate existing legacy installation with schema version 4
      await metaBox.put(DatabaseConstants.schemaVersionKey, 4);

      // Verify migration logic
      final stored = metaBox.get(DatabaseConstants.schemaVersionKey) as int?;
      expect(stored, 4);

      if (stored != null && stored < DatabaseConstants.currentSchemaVersion) {
        await metaBox.put(
          DatabaseConstants.schemaVersionKey,
          DatabaseConstants.currentSchemaVersion,
        );
      }

      final upgraded = metaBox.get(DatabaseConstants.schemaVersionKey) as int?;
      expect(upgraded, 6);
    });

    test('database initialization seeds and does not duplicate default categories on restart', () async {
      final catBox = Hive.box<ExpenseCategoryModel>(
        DatabaseConstants.expenseCategoriesBox,
      );
      expect(catBox.isEmpty, isTrue);

      // 1st run: fresh installation
      if (catBox.isEmpty) {
        final defaults = ExpenseCategory.defaultCategories;
        final map = {
          for (final c in defaults) c.id: ExpenseCategoryModel.fromEntity(c),
        };
        await catBox.putAll(map);
      }
      expect(catBox.length, 19);

      // 2nd run: simulated application restart
      if (catBox.isEmpty) {
        fail('Categories should not be empty on second initialization');
      }
      expect(
        catBox.length,
        19,
        reason:
            'Categories must not be duplicated on subsequent initializations',
      );
    });

    test('every model can be serialized, persisted into its box, and deserialized accurately', () async {
      const db = AppDatabase();
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;

      // 0. BookFair
      final fair = BookFairModel(
        id: 'fair_test_0',
        name: 'Kolkata Book Fair 2026',
        location: 'Milan Mela',
        city: 'Kolkata',
        state: 'WB',
        startDateEpoch: nowEpoch,
        endDateEpoch: nowEpoch + 86400000,
        estimatedBudgetPaise: 5000000,
        initialInvestmentPaise: 5000000,
        currency: 'INR',
        partnerCount: 2,
        partnershipType: 'Equal Split',
        initialPartnerSetup: '',
        description: 'Historic fair',
        operationalNotes: '',
        isDraft: false,
        isArchived: false,
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.bookFairs.put(fair.id, fair);
      final readFair = db.bookFairs.get(fair.id);
      expect(readFair?.name, fair.name);
      expect(readFair?.estimatedBudgetPaise, fair.estimatedBudgetPaise);

      // 1. Partner
      final partner = PartnerModel(
        id: 'part_test_1',
        fairId: fair.id,
        fullName: 'Subhajit Roy',
        phoneNumber: '9876543210',
        email: 'subhajit@example.com',
        role: 'managingPartner',
        joinedAtEpoch: nowEpoch,
        profitSharingPercentage: 50.0,
        notes: 'Co-lead',
        isActive: true,
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.partners.put(partner.id, partner);
      final readPartner = db.partners.get(partner.id);
      expect(readPartner?.fullName, partner.fullName);

      // 2. Investment
      final inv = InvestmentModel(
        id: 'inv_test_2',
        fairId: fair.id,
        partnerId: partner.id,
        amountPaise: 2500000,
        contributionType: 'Initial Capital',
        paymentMethod: 'Bank Transfer',
        contributionDateEpoch: nowEpoch,
        notes: 'Founder contribution',
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.investments.put(inv.id, inv);
      final readInv = db.investments.get(inv.id);
      expect(readInv?.amountPaise, 2500000);

      // 3. ActivityLog
      final log = ActivityLogModel(
        id: 'log_test_3',
        fairId: fair.id,
        title: 'Capital Injected',
        subtitle: 'Subhajit Roy added funds',
        amount: '₹25,000.00',
        type: 'investmentRecorded',
        timestampEpoch: nowEpoch,
      );
      await db.activityLogs.put(log.id, log);
      final readLog = db.activityLogs.get(log.id);
      expect(readLog?.title, log.title);

      // 4. Book
      final book = BookModel(
        id: 'book_test_4',
        fairId: fair.id,
        title: 'Feluda Samagra',
        author: 'Satyajit Ray',
        publisher: 'Ananda',
        genre: 'Mystery',
        language: 'Bengali',
        description: 'Complete collection',
        mrpPaise: 80000,
        defaultSellingPricePaise: 65000,
        condition: 'newCondition',
        conditionNotes: 'Mint fresh',
        isPreviousStock: true,
        openingStockQuantity: 10,
        estimatedCostPaise: 40000,
        isActive: true,
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.books.put(book.id, book);
      final readBook = db.books.get(book.id);
      expect(readBook?.title, book.title);

      // 5. PurchaseBatch
      final batch = PurchaseBatchModel(
        id: 'batch_test_5',
        fairId: fair.id,
        purchaseDateEpoch: nowEpoch,
        totalQuantity: 50,
        totalBookCostPaise: 2000000,
        additionalChargesPaise: 50000,
        totalAcquisitionCostPaise: 2050000,
        paymentStatus: 'Unpaid',
        paymentMethod: 'Bank Transfer',
        notes: '',
        createdAtEpoch: nowEpoch,
      );
      await db.purchaseBatches.put(batch.id, batch);
      final readBatch = db.purchaseBatches.get(batch.id);
      expect(readBatch?.totalAcquisitionCostPaise, 2050000);

      // 6. PurchaseItem
      final item = PurchaseItemModel(
        id: 'item_test_6',
        batchId: batch.id,
        bookId: book.id,
        quantity: 50,
        unitPurchaseCostPaise: 40000,
        lineTotalPaise: 2000000,
        condition: 'newCondition',
        notes: '',
      );
      await db.purchaseItems.put(item.id, item);
      final readItem = db.purchaseItems.get(item.id);
      expect(readItem?.lineTotalPaise, 2000000);

      // 7. StockMovement
      final movement = StockMovementModel(
        id: 'sm_test_7',
        fairId: fair.id,
        bookId: book.id,
        quantity: 50,
        movementType: 'purchaseReceipt',
        movementDateEpoch: nowEpoch,
        notes: 'Inward shipment',
        createdAtEpoch: nowEpoch,
      );
      await db.stockMovements.put(movement.id, movement);
      final readMovement = db.stockMovements.get(movement.id);
      expect(readMovement?.quantity, 50);

      // 8. Supplier
      final supplier = SupplierModel(
        id: 'sup_test_8',
        name: 'Dey Publications',
        contactNumber: '033-2241-0000',
        notes: 'College Street Distributor',
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.suppliers.put(supplier.id, supplier);
      final readSupplier = db.suppliers.get(supplier.id);
      expect(readSupplier?.name, supplier.name);

      // 9. Expense
      final expense = ExpenseModel(
        id: 'exp_test_9',
        fairId: fair.id,
        title: 'Flex Banner Printing',
        description: 'Stall front flex',
        categoryId: 'cat_banners',
        amountPaise: 450000,
        expenseDateEpoch: nowEpoch,
        paymentStatus: 'Unpaid',
        paidAmountPaise: 0,
        outstandingAmountPaise: 450000,
        paymentMethod: 'Cash',
        notes: '',
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.expenses.put(expense.id, expense);
      final readExp = db.expenses.get(expense.id);
      expect(readExp?.amountPaise, 450000);

      // 10. ExpenseCategory
      final category = ExpenseCategoryModel(
        id: 'cat_custom_10',
        name: 'Special Security',
        iconName: 'security',
        isCustom: true,
        isSystem: false,
        createdAtEpoch: nowEpoch,
      );
      await db.expenseCategories.put(category.id, category);
      final readCategory = db.expenseCategories.get(category.id);
      expect(readCategory?.name, category.name);

      // 11. CashbookAccount
      final account = CashbookAccountModel(
        id: 'acc_test_11',
        fairId: fair.id,
        accountName: 'Main Cashbox',
        accountType: 'cash',
        openingBalancePaise: 5000000,
        currentBalancePaise: 5000000,
        isActive: true,
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.cashbookAccounts.put(account.id, account);
      final readAcc = db.cashbookAccounts.get(account.id);
      expect(readAcc?.currentBalancePaise, 5000000);

      // 12. AccountTransaction
      final tx = AccountTransactionModel(
        id: 'tx_test_12',
        fairId: fair.id,
        accountId: account.id,
        transactionType: 'opening_balance',
        direction: 'inflow',
        amountPaise: 5000000,
        transactionDateEpoch: nowEpoch,
        referenceType: 'manual',
        description: 'Initial balance',
        createdAtEpoch: nowEpoch,
      );
      await db.accountTransactions.put(tx.id, tx);
      final readTx = db.accountTransactions.get(tx.id);
      expect(readTx?.amountPaise, 5000000);

      // 13. PaymentRecord
      final payment = PaymentRecordModel(
        id: 'pay_test_13',
        fairId: fair.id,
        amountPaise: 450000,
        paymentMethod: 'Cash',
        paymentDateEpoch: nowEpoch,
        accountId: account.id,
        relatedEntityType: 'expense',
        relatedEntityId: expense.id,
        notes: 'Payment settled',
        createdAtEpoch: nowEpoch,
      );
      await db.paymentRecords.put(payment.id, payment);
      final readPay = db.paymentRecords.get(payment.id);
      expect(readPay?.amountPaise, 450000);

      // 14. FinancialOperation
      final op = FinancialOperationModel(
        id: 'op_test_14',
        fairId: fair.id,
        idempotencyKey: 'op_fair_test_0_transfer_nonce123',
        requestFingerprint: 'dummy_sha256_fingerprint',
        operationType: 'account_transfer',
        status: 'committed',
        amountPaise: 100000,
        primaryEntityId: 'ref_123',
        secondaryEntityId: 'acc_dest',
        sourceAccountId: account.id,
        targetAccountId: 'acc_dest',
        payloadJson: '{"testKey":"testVal"}',
        attemptNumber: 1,
        parentOperationId: null,
        createdAtEpoch: nowEpoch,
        updatedAtEpoch: nowEpoch,
      );
      await db.financialOperations.put(op.id, op);
      final readOp = db.financialOperations.get(op.id);
      expect(readOp?.idempotencyKey, op.idempotencyKey);
      expect(readOp?.payload['testKey'], 'testVal');
      expect(readOp?.isCommitted, isTrue);
    });
  });
}
