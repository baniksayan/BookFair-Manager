import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../features/book_fairs/data/models/activity_log_model.dart';
import '../../features/book_fairs/data/models/book_fair_model.dart';
import '../../features/book_fairs/data/models/investment_model.dart';
import '../../features/book_fairs/data/models/partner_model.dart';
import '../../features/cashbook/data/models/account_transaction_model.dart';
import '../../features/cashbook/data/models/cashbook_account_model.dart';
import '../../features/cashbook/data/models/financial_operation_model.dart';
import '../../features/expenses/data/models/expense_category_model.dart';
import '../../features/expenses/data/models/expense_model.dart';
import '../../features/inventory/data/models/book_model.dart';
import '../../features/inventory/data/models/purchase_batch_model.dart';
import '../../features/inventory/data/models/purchase_item_model.dart';
import '../../features/inventory/data/models/stock_movement_model.dart';
import '../../features/inventory/data/models/supplier_model.dart';
import '../../features/payments/data/models/payment_record_model.dart';
import '../../features/sales/data/models/sale_item_model.dart';
import '../../features/sales/data/models/sale_receipt_model.dart';
import 'database_constants.dart';

/// Central database access manager wrapping typed Hive boxes.
class AppDatabase {
  const AppDatabase();

  Box<BookFairModel> get bookFairs =>
      Hive.box<BookFairModel>(DatabaseConstants.bookFairsBox);

  Box<PartnerModel> get partners =>
      Hive.box<PartnerModel>(DatabaseConstants.partnersBox);

  Box<InvestmentModel> get investments =>
      Hive.box<InvestmentModel>(DatabaseConstants.investmentsBox);

  Box<ActivityLogModel> get activityLogs =>
      Hive.box<ActivityLogModel>(DatabaseConstants.activityLogsBox);

  Box<dynamic> get metadata => Hive.box<dynamic>(DatabaseConstants.metadataBox);

  // --- Stage 03 Inventory Collections ---
  Box<BookModel> get books => Hive.box<BookModel>(DatabaseConstants.booksBox);

  Box<PurchaseBatchModel> get purchaseBatches =>
      Hive.box<PurchaseBatchModel>(DatabaseConstants.purchaseBatchesBox);

  Box<PurchaseItemModel> get purchaseItems =>
      Hive.box<PurchaseItemModel>(DatabaseConstants.purchaseItemsBox);

  Box<StockMovementModel> get stockMovements =>
      Hive.box<StockMovementModel>(DatabaseConstants.stockMovementsBox);

  Box<SupplierModel> get suppliers =>
      Hive.box<SupplierModel>(DatabaseConstants.suppliersBox);

  // --- Stage 04 Finance & Payment Collections ---
  Box<ExpenseModel> get expenses =>
      Hive.box<ExpenseModel>(DatabaseConstants.expensesBox);

  Box<ExpenseCategoryModel> get expenseCategories =>
      Hive.box<ExpenseCategoryModel>(DatabaseConstants.expenseCategoriesBox);

  Box<CashbookAccountModel> get cashbookAccounts =>
      Hive.box<CashbookAccountModel>(DatabaseConstants.cashbookAccountsBox);

  Box<AccountTransactionModel> get accountTransactions =>
      Hive.box<AccountTransactionModel>(
        DatabaseConstants.accountTransactionsBox,
      );

  Box<PaymentRecordModel> get paymentRecords =>
      Hive.box<PaymentRecordModel>(DatabaseConstants.paymentRecordsBox);

  Box<FinancialOperationModel> get financialOperations =>
      Hive.box<FinancialOperationModel>(
        DatabaseConstants.financialOperationsBox,
      );

  // --- Stage 05 Sales & POS Collections ---
  Box<SaleReceiptModel> get salesReceipts =>
      Hive.box<SaleReceiptModel>(DatabaseConstants.salesReceiptsBox);

  Box<SaleItemModel> get saleItems =>
      Hive.box<SaleItemModel>(DatabaseConstants.saleItemsBox);

  /// Clears all tables (used for testing or total database reset).
  Future<void> clearAll() async {
    await Future.wait([
      bookFairs.clear(),
      partners.clear(),
      investments.clear(),
      activityLogs.clear(),
      metadata.clear(),
      books.clear(),
      purchaseBatches.clear(),
      purchaseItems.clear(),
      stockMovements.clear(),
      suppliers.clear(),
      expenses.clear(),
      expenseCategories.clear(),
      cashbookAccounts.clear(),
      accountTransactions.clear(),
      paymentRecords.clear(),
      financialOperations.clear(),
      salesReceipts.clear(),
      saleItems.clear(),
    ]);
  }

  /// Compacts all database boxes to recover disk space.
  Future<void> compact() async {
    await Future.wait([
      bookFairs.compact(),
      partners.compact(),
      investments.compact(),
      activityLogs.compact(),
      books.compact(),
      purchaseBatches.compact(),
      purchaseItems.compact(),
      stockMovements.compact(),
      suppliers.compact(),
      expenses.compact(),
      expenseCategories.compact(),
      cashbookAccounts.compact(),
      accountTransactions.compact(),
      paymentRecords.compact(),
      financialOperations.compact(),
      salesReceipts.compact(),
      saleItems.compact(),
    ]);
  }
}

/// Riverpod provider delivering the application's [AppDatabase] instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return const AppDatabase();
});
