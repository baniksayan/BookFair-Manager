/// Centralized constants for Hive database collections, type IDs, and schema versioning.
abstract final class DatabaseConstants {
  // --- Hive Box Names ---
  static const String bookFairsBox = 'book_fairs_v1';
  static const String partnersBox = 'partners_v1';
  static const String investmentsBox = 'investments_v1';
  static const String activityLogsBox = 'activity_logs_v1';
  static const String metadataBox = 'app_metadata_v1';

  // --- Stage 03 Inventory Box Names ---
  static const String booksBox = 'books_v1';
  static const String purchaseBatchesBox = 'purchase_batches_v1';
  static const String purchaseItemsBox = 'purchase_items_v1';
  static const String stockMovementsBox = 'stock_movements_v1';
  static const String suppliersBox = 'suppliers_v1';

  // --- Stage 04 Finance, Expenses, Cashbook & Payments Box Names ---
  static const String expensesBox = 'expenses_v1';
  static const String expenseCategoriesBox = 'expense_categories_v1';
  static const String cashbookAccountsBox = 'cashbook_accounts_v1';
  static const String accountTransactionsBox = 'account_transactions_v1';
  static const String paymentRecordsBox = 'payment_records_v1';
  static const String financialOperationsBox = 'financial_operations_v1';

  // --- Stage 05 Sales, POS & Receipts Box Names ---
  static const String salesReceiptsBox = 'sales_receipts_v1';
  static const String saleItemsBox = 'sale_items_v1';

  // --- Hive Type IDs ---
  static const int bookFairTypeId = 0;
  static const int partnerTypeId = 1;
  static const int investmentTypeId = 2;
  static const int activityLogTypeId = 3;

  // --- Stage 03 Type IDs ---
  static const int bookTypeId = 4;
  static const int purchaseBatchTypeId = 5;
  static const int purchaseItemTypeId = 6;
  static const int stockMovementTypeId = 7;
  static const int supplierTypeId = 8;

  // --- Stage 04 Type IDs ---
  static const int expenseTypeId = 9;
  static const int expenseCategoryTypeId = 10;
  static const int cashbookAccountTypeId = 11;
  static const int accountTransactionTypeId = 12;
  static const int paymentRecordTypeId = 13;
  static const int financialOperationTypeId = 14;

  // --- Stage 05 Type IDs ---
  static const int saleReceiptTypeId = 15;
  static const int saleItemTypeId = 16;

  // --- Schema Versioning ---
  static const int currentSchemaVersion = 6;

  // --- Metadata & Settings Keys ---
  static const String schemaVersionKey = 'schema_version';
  static const String draftFairKey = 'draft_book_fair';
  static const String selectedPaletteKey = 'selected_palette_id';
  static const String selectedThemeModeKey = 'selected_theme_mode';
}
