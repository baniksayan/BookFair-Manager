/// Centralized route names for GoRouter navigation.
abstract final class RouteNames {
  static const String dashboard = 'dashboard';
  static const String bookFairs = 'bookFairs';
  static const String createBookFair = 'createBookFair';
  static const String bookFairDetails = 'bookFairDetails';
  static const String editBookFair = 'editBookFair';
  static const String partnerList = 'partnerList';
  static const String createPartner = 'createPartner';
  static const String inventory = 'inventory';
  static const String bookCatalogue = 'bookCatalogue';
  static const String createBook = 'createBook';
  static const String bookDetails = 'bookDetails';
  static const String editBook = 'editBook';
  static const String createPurchaseBatch = 'createPurchaseBatch';
  static const String purchaseHistory = 'purchaseHistory';
  static const String suppliers = 'suppliers';
  static const String settings = 'settings';
  static const String more = 'more';

  // --- Stage 04 Finance, Expense & Cashbook Routes ---
  static const String expenses = 'expenses';
  static const String createExpense = 'createExpense';
  static const String expenseDetails = 'expenseDetails';
  static const String editExpense = 'editExpense';
  static const String expenseHistory = 'expenseHistory';

  static const String cashbook = 'cashbook';
  static const String cashbookAccountDetails = 'cashbookAccountDetails';
  static const String cashbookCreateTransfer = 'cashbookCreateTransfer';

  static const String partnerDues = 'partnerDues';

  static const String accounting = 'accounting';
  static const String accountingReports = 'accountingReports';

  // --- Stage 05 Sales & POS Routes ---
  static const String posSalesCounter = 'posSalesCounter';
  static const String salesHistory = 'salesHistory';
  static const String saleReceiptDetails = 'saleReceiptDetails';
  static const String sellerBookSearch = 'sellerBookSearch';
}

/// Centralized route paths for GoRouter navigation.
abstract final class RoutePaths {
  static const String dashboard = '/dashboard';
  static const String bookFairs = '/book-fairs';
  static const String createBookFair = '/book-fairs/create';
  static const String bookFairDetails = '/book-fairs/:id';
  static const String editBookFair = '/book-fairs/:id/edit';
  static const String partnerList = '/book-fairs/:id/partners';
  static const String createPartner = '/book-fairs/:id/partners/create';
  static const String inventory = '/inventory';
  static const String bookCatalogue = '/inventory/books';
  static const String createBook = '/inventory/books/create';
  static const String bookDetails = '/inventory/books/:id';
  static const String editBook = '/inventory/books/:id/edit';
  static const String createPurchaseBatch = '/inventory/purchases/create';
  static const String purchaseHistory = '/inventory/purchases';
  static const String suppliers = '/inventory/suppliers';
  static const String settings = '/settings';
  static const String more = '/more';

  // --- Stage 04 Finance, Expense & Cashbook Paths ---
  static const String expenses = '/expenses';
  static const String createExpense = '/expenses/create';
  static const String expenseDetails = '/expenses/:id';
  static const String editExpense = '/expenses/:id/edit';
  static const String expenseHistory = '/expenses/history';

  static const String cashbook = '/cashbook';
  static const String cashbookAccountDetails = '/cashbook/accounts/:id';
  static const String cashbookCreateTransfer = '/cashbook/transfers/create';

  static const String partnerDues = '/book-fairs/:id/partner-dues';

  static const String accounting = '/accounting';
  static const String accountingReports = '/accounting/reports';

  // --- Stage 05 Sales & POS Paths ---
  static const String posSalesCounter = '/sales/counter';
  static const String salesHistory = '/sales/history';
  static const String saleReceiptDetails = '/sales/receipts/:id';
  static const String sellerBookSearch = '/inventory/seller-search';
}
