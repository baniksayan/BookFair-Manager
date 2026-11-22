import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/accounting/presentation/screens/accounting_dashboard_screen.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/book_fair_model.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/partner_dues_screen.dart';
import 'package:bookfair_manager/features/cashbook/presentation/screens/cashbook_overview_screen.dart';
import 'package:bookfair_manager/features/expenses/presentation/screens/expense_dashboard_screen.dart';
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

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
  }

  group('Stage 04 Screens Widget Tests', () {
    const db = AppDatabase();
    final now = DateTime(2026, 11, 21);

    testWidgets(
      'ExpenseDashboardScreen renders app bar, empty state, and action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestableWidget(const ExpenseDashboardScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Expenses Dashboard'), findsOneWidget);
        expect(find.text('No Expenses Recorded'), findsOneWidget);
        expect(find.text('Record First Expense'), findsOneWidget);
        expect(find.text('Add Expense'), findsOneWidget);
      },
    );

    testWidgets(
      'CashbookOverviewScreen renders liquid funds hero, accounts, and action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestableWidget(const CashbookOverviewScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cashbook & Accounts'), findsOneWidget);
        expect(find.text('TOTAL BUSINESS LIQUID FUNDS'), findsOneWidget);
        expect(find.text('New Account'), findsWidgets);
        expect(find.text('Physical Cash'), findsOneWidget);
      },
    );

    testWidgets(
      'AccountingDashboardScreen renders accounting overview and key metrics',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestableWidget(const AccountingDashboardScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Financial Accounting'), findsOneWidget);
        expect(find.text('TOTAL BUSINESS LIQUID FUNDS'), findsOneWidget);
        expect(find.text('TOTAL INVESTMENT'), findsOneWidget);
        expect(find.text('OPERATING EXPENSES'), findsOneWidget);
      },
    );

    testWidgets(
      'PartnerDuesScreen renders empty state when no partners exist',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fair = BookFair(
          id: 'fair_test_1',
          name: 'Test Fair 2026',
          location: 'Milan Mela',
          city: 'Kolkata',
          state: 'West Bengal',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          estimatedBudgetPaise: 5000000,
          initialInvestmentPaise: 5000000,
          createdAt: now,
          updatedAt: now,
        );
        await tester.runAsync(() async {
          await db.bookFairs.put(fair.id, BookFairModel.fromEntity(fair));
        });

        await tester.pumpWidget(
          buildTestableWidget(PartnerDuesScreen(fairId: fair.id)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Fair 2026 — Partner Dues'), findsOneWidget);
        expect(find.text('No Partners Registered'), findsOneWidget);
        expect(find.text('TOTAL REIMBURSEMENT LIABILITY'), findsOneWidget);
        expect(find.text('Personally Incurred'), findsOneWidget);
      },
    );
  });
}
