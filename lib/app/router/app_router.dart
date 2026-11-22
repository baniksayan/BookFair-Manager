import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_fairs/presentation/screens/add_partner_screen.dart';
import '../../features/book_fairs/presentation/screens/book_fair_details_screen.dart';
import '../../features/book_fairs/presentation/screens/book_fair_list_screen.dart';
import '../../features/book_fairs/presentation/screens/create_book_fair_screen.dart';
import '../../features/book_fairs/presentation/screens/partner_dues_screen.dart';
import '../../features/book_fairs/presentation/screens/partner_list_screen.dart';
import '../../features/accounting/presentation/screens/accounting_dashboard_screen.dart';
import '../../features/accounting/presentation/screens/financial_reports_screen.dart';
import '../../features/cashbook/presentation/screens/account_details_screen.dart';
import '../../features/cashbook/presentation/screens/cashbook_overview_screen.dart';
import '../../features/cashbook/presentation/screens/transfer_funds_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/expenses/presentation/screens/add_edit_expense_screen.dart';
import '../../features/expenses/presentation/screens/expense_dashboard_screen.dart';
import '../../features/expenses/presentation/screens/expense_details_screen.dart';
import '../../features/expenses/presentation/screens/expense_history_screen.dart';
import '../../features/inventory/presentation/screens/add_edit_book_screen.dart';
import '../../features/inventory/presentation/screens/book_catalogue_screen.dart';
import '../../features/inventory/presentation/screens/book_details_screen.dart';
import '../../features/inventory/presentation/screens/create_purchase_batch_screen.dart';
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/inventory/presentation/screens/purchase_history_screen.dart';
import '../../features/inventory/presentation/screens/supplier_list_screen.dart';
import '../../features/sales/presentation/screens/pos_sales_counter_screen.dart';
import '../../features/sales/presentation/screens/sale_receipt_details_screen.dart';
import '../../features/sales/presentation/screens/sales_history_screen.dart';
import '../../features/sales/presentation/screens/seller_book_search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import 'route_names.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

/// Riverpod provider delivering the application's [GoRouter] instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.dashboard,
    routes: [
      // Top-level Shell with persistent bottom navigation bar
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            name: RouteNames.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: RoutePaths.bookFairs,
            name: RouteNames.bookFairs,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookFairListScreen()),
          ),
          GoRoute(
            path: RoutePaths.inventory,
            name: RouteNames.inventory,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryDashboardScreen()),
          ),
          GoRoute(
            path: RoutePaths.more,
            name: RouteNames.more,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),

      // Create Book Fair screen
      GoRoute(
        path: RoutePaths.createBookFair,
        name: RouteNames.createBookFair,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateBookFairScreen(),
      ),

      // Book Fair Details screen
      GoRoute(
        path: RoutePaths.bookFairDetails,
        name: RouteNames.bookFairDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.pathParameters['id']!;
          return BookFairDetailsScreen(fairId: fairId);
        },
      ),

      // Edit Book Fair screen
      GoRoute(
        path: RoutePaths.editBookFair,
        name: RouteNames.editBookFair,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.pathParameters['id']!;
          return CreateBookFairScreen(fairId: fairId);
        },
      ),

      // Partner List screen
      GoRoute(
        path: RoutePaths.partnerList,
        name: RouteNames.partnerList,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.pathParameters['id']!;
          return PartnerListScreen(fairId: fairId);
        },
      ),

      // Add / Edit Partner screen
      GoRoute(
        path: RoutePaths.createPartner,
        name: RouteNames.createPartner,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.pathParameters['id']!;
          final partnerId = state.uri.queryParameters['partnerId'];
          return AddPartnerScreen(fairId: fairId, partnerIdToEdit: partnerId);
        },
      ),

      // --- Inventory Module Routes ---

      // Book Master Catalogue
      GoRoute(
        path: RoutePaths.bookCatalogue,
        name: RouteNames.bookCatalogue,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BookCatalogueScreen(),
      ),

      // Add Book
      GoRoute(
        path: RoutePaths.createBook,
        name: RouteNames.createBook,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddEditBookScreen(),
      ),

      // Book Details
      GoRoute(
        path: RoutePaths.bookDetails,
        name: RouteNames.bookDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return BookDetailsScreen(bookId: bookId);
        },
      ),

      // Edit Book
      GoRoute(
        path: RoutePaths.editBook,
        name: RouteNames.editBook,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return AddEditBookScreen(bookIdToEdit: bookId);
        },
      ),

      // Create Purchase Batch
      GoRoute(
        path: RoutePaths.createPurchaseBatch,
        name: RouteNames.createPurchaseBatch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreatePurchaseBatchScreen(),
      ),

      // Purchase History
      GoRoute(
        path: RoutePaths.purchaseHistory,
        name: RouteNames.purchaseHistory,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PurchaseHistoryScreen(),
      ),

      // Suppliers & Vendors Directory
      GoRoute(
        path: RoutePaths.suppliers,
        name: RouteNames.suppliers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SupplierListScreen(),
      ),

      // Settings Screen
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // --- Stage 04 Expenses Module Routes ---

      // Expenses Dashboard
      GoRoute(
        path: RoutePaths.expenses,
        name: RouteNames.expenses,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExpenseDashboardScreen(),
      ),

      // Create Expense
      GoRoute(
        path: RoutePaths.createExpense,
        name: RouteNames.createExpense,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.uri.queryParameters['fairId'];
          return AddEditExpenseScreen(initialFairId: fairId);
        },
      ),

      // Expense Details
      GoRoute(
        path: RoutePaths.expenseDetails,
        name: RouteNames.expenseDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpenseDetailsScreen(expenseId: id);
        },
      ),

      // Edit Expense
      GoRoute(
        path: RoutePaths.editExpense,
        name: RouteNames.editExpense,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditExpenseScreen(expenseId: id);
        },
      ),

      // Expense History
      GoRoute(
        path: RoutePaths.expenseHistory,
        name: RouteNames.expenseHistory,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExpenseHistoryScreen(),
      ),

      // --- Stage 04 Cashbook Module Routes ---

      // Cashbook Overview
      GoRoute(
        path: RoutePaths.cashbook,
        name: RouteNames.cashbook,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CashbookOverviewScreen(),
      ),

      // Account Details
      GoRoute(
        path: RoutePaths.cashbookAccountDetails,
        name: RouteNames.cashbookAccountDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AccountDetailsScreen(accountId: id);
        },
      ),

      // Transfer Funds
      GoRoute(
        path: RoutePaths.cashbookCreateTransfer,
        name: RouteNames.cashbookCreateTransfer,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TransferFundsScreen(),
      ),

      // Partner Dues & Reimbursements
      GoRoute(
        path: RoutePaths.partnerDues,
        name: RouteNames.partnerDues,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PartnerDuesScreen(fairId: id);
        },
      ),

      // --- Stage 04 Financial Accounting & Reports Routes ---

      // Accounting Dashboard
      GoRoute(
        path: RoutePaths.accounting,
        name: RouteNames.accounting,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountingDashboardScreen(),
      ),

      // Financial Reports
      GoRoute(
        path: RoutePaths.accountingReports,
        name: RouteNames.accountingReports,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FinancialReportsScreen(),
      ),

      // --- Stage 05 Sales & POS Routes ---

      // POS Sales Counter
      GoRoute(
        path: RoutePaths.posSalesCounter,
        name: RouteNames.posSalesCounter,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.uri.queryParameters['fairId'];
          return PosSalesCounterScreen(fairId: fairId);
        },
      ),

      // Sales Register History
      GoRoute(
        path: RoutePaths.salesHistory,
        name: RouteNames.salesHistory,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SalesHistoryScreen(),
      ),

      // Sale Receipt Details
      GoRoute(
        path: RoutePaths.saleReceiptDetails,
        name: RouteNames.saleReceiptDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SaleReceiptDetailsScreen(receiptId: id);
        },
      ),

      // Seller Kiosk Inventory Lookup
      GoRoute(
        path: RoutePaths.sellerBookSearch,
        name: RouteNames.sellerBookSearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final fairId = state.uri.queryParameters['fairId'];
          return SellerBookSearchScreen(fairId: fairId);
        },
      ),
    ],
  );
});
