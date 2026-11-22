import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/book_fairs/data/models/activity_log_model.dart';
import '../../features/book_fairs/data/models/book_fair_model.dart';
import '../../features/book_fairs/data/models/investment_model.dart';
import '../../features/book_fairs/data/models/partner_model.dart';
import '../../features/cashbook/data/datasources/financial_operation_local_datasource.dart';
import '../../features/cashbook/data/models/account_transaction_model.dart';
import '../../features/cashbook/data/models/cashbook_account_model.dart';
import '../../features/cashbook/data/models/financial_operation_model.dart';
import '../../features/cashbook/domain/services/financial_recovery_engine.dart';
import '../../features/expenses/data/models/expense_category_model.dart';
import '../../features/expenses/data/models/expense_model.dart';
import '../../features/expenses/domain/entities/expense_category.dart';
import '../../features/inventory/data/models/book_model.dart';
import '../../features/inventory/data/models/purchase_batch_model.dart';
import '../../features/inventory/data/models/purchase_item_model.dart';
import '../../features/inventory/data/models/stock_movement_model.dart';
import '../../features/inventory/data/models/supplier_model.dart';
import '../../features/payments/data/models/payment_record_model.dart';
import '../../features/sales/data/models/sale_item_model.dart';
import '../../features/sales/data/models/sale_receipt_model.dart';
import 'app_database.dart';
import 'database_constants.dart';
import 'database_exceptions.dart';

/// Handles offline Hive database registration, lifecycle initialization, and schema migrations.
abstract final class DatabaseInitializer {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initializes Hive storage and opens all core application boxes.
  ///
  /// Can optionally specify [subDir] for isolated unit and integration testing.
  static Future<void> init({String? subDir}) async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        await Hive.initFlutter();
      } else {
        await Hive.initFlutter(subDir);
      }

      _registerAdapters();
      await _openBoxes();
      await _verifyAndMigrateSchema();

      // Execute startup crash recovery for any interrupted financial operations
      const db = AppDatabase();
      final recoveryEngine = FinancialRecoveryEngine(
        db: db,
        journalDataSource: const FinancialOperationLocalDataSourceImpl(db),
      );
      await recoveryEngine.runStartupRecovery();

      _isInitialized = true;
    } catch (e, stack) {
      throw DatabaseInitializationException(
        'Failed to initialize local Hive database: $e',
        stack,
      );
    }
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(DatabaseConstants.bookFairTypeId)) {
      Hive.registerAdapter(BookFairAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.partnerTypeId)) {
      Hive.registerAdapter(PartnerAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.investmentTypeId)) {
      Hive.registerAdapter(InvestmentAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.activityLogTypeId)) {
      Hive.registerAdapter(ActivityLogAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.bookTypeId)) {
      Hive.registerAdapter(BookAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.purchaseBatchTypeId)) {
      Hive.registerAdapter(PurchaseBatchAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.purchaseItemTypeId)) {
      Hive.registerAdapter(PurchaseItemAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.stockMovementTypeId)) {
      Hive.registerAdapter(StockMovementAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.supplierTypeId)) {
      Hive.registerAdapter(SupplierAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.expenseTypeId)) {
      Hive.registerAdapter(ExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.expenseCategoryTypeId)) {
      Hive.registerAdapter(ExpenseCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.cashbookAccountTypeId)) {
      Hive.registerAdapter(CashbookAccountAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.accountTransactionTypeId)) {
      Hive.registerAdapter(AccountTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.paymentRecordTypeId)) {
      Hive.registerAdapter(PaymentRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.financialOperationTypeId)) {
      Hive.registerAdapter(FinancialOperationAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.saleReceiptTypeId)) {
      Hive.registerAdapter(SaleReceiptAdapter());
    }
    if (!Hive.isAdapterRegistered(DatabaseConstants.saleItemTypeId)) {
      Hive.registerAdapter(SaleItemAdapter());
    }
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      Hive.openBox<BookFairModel>(DatabaseConstants.bookFairsBox),
      Hive.openBox<PartnerModel>(DatabaseConstants.partnersBox),
      Hive.openBox<InvestmentModel>(DatabaseConstants.investmentsBox),
      Hive.openBox<ActivityLogModel>(DatabaseConstants.activityLogsBox),
      Hive.openBox<dynamic>(DatabaseConstants.metadataBox),
      Hive.openBox<BookModel>(DatabaseConstants.booksBox),
      Hive.openBox<PurchaseBatchModel>(DatabaseConstants.purchaseBatchesBox),
      Hive.openBox<PurchaseItemModel>(DatabaseConstants.purchaseItemsBox),
      Hive.openBox<StockMovementModel>(DatabaseConstants.stockMovementsBox),
      Hive.openBox<SupplierModel>(DatabaseConstants.suppliersBox),
      Hive.openBox<ExpenseModel>(DatabaseConstants.expensesBox),
      Hive.openBox<ExpenseCategoryModel>(
        DatabaseConstants.expenseCategoriesBox,
      ),
      Hive.openBox<CashbookAccountModel>(DatabaseConstants.cashbookAccountsBox),
      Hive.openBox<AccountTransactionModel>(
        DatabaseConstants.accountTransactionsBox,
      ),
      Hive.openBox<PaymentRecordModel>(DatabaseConstants.paymentRecordsBox),
      Hive.openBox<FinancialOperationModel>(
        DatabaseConstants.financialOperationsBox,
      ),
      Hive.openBox<SaleReceiptModel>(DatabaseConstants.salesReceiptsBox),
      Hive.openBox<SaleItemModel>(DatabaseConstants.saleItemsBox),
    ]);
  }

  static Future<void> _verifyAndMigrateSchema() async {
    final metaBox = Hive.box<dynamic>(DatabaseConstants.metadataBox);
    final storedVersion =
        metaBox.get(DatabaseConstants.schemaVersionKey) as int?;

    if (storedVersion == null) {
      // Fresh database instance
      await metaBox.put(
        DatabaseConstants.schemaVersionKey,
        DatabaseConstants.currentSchemaVersion,
      );
      await metaBox.flush();
    } else if (storedVersion < DatabaseConstants.currentSchemaVersion) {
      // Migrate from older schema version to current (e.g. v4 -> v5)
      // Step A: Snapshot all existing accounts' v4 balances as immutable baseline
      final accountsBox = Hive.box<CashbookAccountModel>(
        DatabaseConstants.cashbookAccountsBox,
      );
      final cutoverNow = DateTime.now().millisecondsSinceEpoch;
      for (final account in accountsBox.values) {
        final baselineKey = 'account_baseline_v5_${account.id}';
        final cutoverKey = 'account_cutover_epoch_v5_${account.id}';
        if (!metaBox.containsKey(baselineKey)) {
          await metaBox.put(baselineKey, account.currentBalancePaise);
          await metaBox.put(cutoverKey, cutoverNow);
        }
      }
      await metaBox.flush();

      // Step B: Advance schema version to v5
      await metaBox.put(
        DatabaseConstants.schemaVersionKey,
        DatabaseConstants.currentSchemaVersion,
      );
      await metaBox.flush();
    } else if (storedVersion > DatabaseConstants.currentSchemaVersion) {
      // Database was written by a newer version of the application.
      // Strict rule: Never downgrade or silently overwrite a higher stored schema version.
      if (kDebugMode) {
        debugPrint(
          'Database schema version ($storedVersion) is newer than app current '
          '(${DatabaseConstants.currentSchemaVersion}). Preserving existing schema version.',
        );
      }
    }

    // Seed default expense categories if collection is fresh
    final catBox = Hive.box<ExpenseCategoryModel>(
      DatabaseConstants.expenseCategoriesBox,
    );
    if (catBox.isEmpty) {
      final defaults = ExpenseCategory.defaultCategories;
      final map = {
        for (final c in defaults) c.id: ExpenseCategoryModel.fromEntity(c),
      };
      await catBox.putAll(map);
      await catBox.flush();
    }
  }

  /// Initializes Hive storage for isolated unit and widget tests using direct file path.
  static Future<void> initTest({required String path}) async {
    if (_isInitialized) {
      await close();
    }
    Hive.init(path);
    _registerAdapters();
    await _openBoxes();
    await _verifyAndMigrateSchema();

    const db = AppDatabase();
    final recoveryEngine = FinancialRecoveryEngine(
      db: db,
      journalDataSource: const FinancialOperationLocalDataSourceImpl(db),
    );
    await recoveryEngine.runStartupRecovery();

    _isInitialized = true;
  }

  /// Closes all open database boxes (useful in test teardown).
  static Future<void> close() async {
    Future<void> safeCloseBox(Box? box) async {
      if (box != null && box.isOpen) {
        try {
          await box.close().timeout(
            const Duration(seconds: 1),
            onTimeout: () => null,
          );
        } catch (_) {}
      }
    }

    try {
      if (Hive.isBoxOpen(DatabaseConstants.bookFairsBox)) {
        await safeCloseBox(
          Hive.box<BookFairModel>(DatabaseConstants.bookFairsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.partnersBox)) {
        await safeCloseBox(
          Hive.box<PartnerModel>(DatabaseConstants.partnersBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.investmentsBox)) {
        await safeCloseBox(
          Hive.box<InvestmentModel>(DatabaseConstants.investmentsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.activityLogsBox)) {
        await safeCloseBox(
          Hive.box<ActivityLogModel>(DatabaseConstants.activityLogsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.booksBox)) {
        await safeCloseBox(Hive.box<BookModel>(DatabaseConstants.booksBox));
      }
      if (Hive.isBoxOpen(DatabaseConstants.purchaseBatchesBox)) {
        await safeCloseBox(
          Hive.box<PurchaseBatchModel>(DatabaseConstants.purchaseBatchesBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.purchaseItemsBox)) {
        await safeCloseBox(
          Hive.box<PurchaseItemModel>(DatabaseConstants.purchaseItemsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.stockMovementsBox)) {
        await safeCloseBox(
          Hive.box<StockMovementModel>(DatabaseConstants.stockMovementsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.suppliersBox)) {
        await safeCloseBox(
          Hive.box<SupplierModel>(DatabaseConstants.suppliersBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.expensesBox)) {
        await safeCloseBox(
          Hive.box<ExpenseModel>(DatabaseConstants.expensesBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.expenseCategoriesBox)) {
        await safeCloseBox(
          Hive.box<ExpenseCategoryModel>(
            DatabaseConstants.expenseCategoriesBox,
          ),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.cashbookAccountsBox)) {
        await safeCloseBox(
          Hive.box<CashbookAccountModel>(DatabaseConstants.cashbookAccountsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.accountTransactionsBox)) {
        await safeCloseBox(
          Hive.box<AccountTransactionModel>(
            DatabaseConstants.accountTransactionsBox,
          ),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.paymentRecordsBox)) {
        await safeCloseBox(
          Hive.box<PaymentRecordModel>(DatabaseConstants.paymentRecordsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.financialOperationsBox)) {
        await safeCloseBox(
          Hive.box<FinancialOperationModel>(
            DatabaseConstants.financialOperationsBox,
          ),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.salesReceiptsBox)) {
        await safeCloseBox(
          Hive.box<SaleReceiptModel>(DatabaseConstants.salesReceiptsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.saleItemsBox)) {
        await safeCloseBox(
          Hive.box<SaleItemModel>(DatabaseConstants.saleItemsBox),
        );
      }
      if (Hive.isBoxOpen(DatabaseConstants.metadataBox)) {
        await safeCloseBox(Hive.box<dynamic>(DatabaseConstants.metadataBox));
      }
      await Hive.close().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (_) {}
    _isInitialized = false;
  }
}
