import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/data/repositories/payment_repository_impl.dart';

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
  final fairDataSource = BookFairLocalDataSourceImpl(db);
  final activityRepo = ActivityLogRepositoryImpl(fairDataSource);
  final cashbookDataSource = CashbookLocalDataSourceImpl(db);
  final cashbookRepo = CashbookRepositoryImpl(cashbookDataSource, activityRepo);
  final expenseDataSource = ExpenseLocalDataSourceImpl(db);
  final paymentDataSource = PaymentLocalDataSourceImpl(db);

  final paymentRepo = PaymentRepositoryImpl(
    paymentDataSource: paymentDataSource,
    cashbookRepository: cashbookRepo,
    expenseDataSource: expenseDataSource,
    database: db,
    activityLogs: activityRepo,
  );

  final expenseRepo = ExpenseRepositoryImpl(
    expenseDataSource: expenseDataSource,
    paymentRepository: paymentRepo,
    activityLogs: activityRepo,
  );

  group('ExpenseRepositoryImpl Hive Tests', () {
    test(
      'createExpense stores unpaid expense record when initial payment is 0',
      () async {
        final expense = Expense(
          id: 'exp_rent',
          fairId: 'fair_kolkata',
          title: 'Milan Mela Stall Rent',
          categoryId: 'cat_stall_rent',
          amountPaise: 500000, // ₹5,000
          outstandingAmountPaise: 500000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final created = await expenseRepo.createExpense(expense);

        expect(created.id, 'exp_rent');
        expect(created.paymentStatus, 'Unpaid');
        expect(created.outstandingAmountPaise, 500000);
        expect(created.paidAmountPaise, 0);

        final fetched = await expenseRepo.getExpenseById('exp_rent');
        expect(fetched, isNotNull);
        expect(fetched!.title, 'Milan Mela Stall Rent');
      },
    );

    test('createExpense with initial payment records payment and updates status to Partially Paid', () async {
      final expense = Expense(
        id: 'exp_banner',
        fairId: 'fair_kolkata',
        title: 'Front Gate Flex Banners',
        categoryId: 'cat_banner_flex',
        amountPaise: 400000, // ₹4,000
        outstandingAmountPaise: 400000,
        expenseDate: DateTime.now(),
        paymentStatus: 'Unpaid',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await expenseRepo.createExpense(
        expense,
        initialPaymentAmountPaise: 150000, // ₹1,500 advance paid
        paymentMethod: 'Cash',
      );

      expect(created.paidAmountPaise, 150000);
      expect(created.outstandingAmountPaise, 250000);
      expect(created.paymentStatus, 'Partially Paid');

      // Verify payment record was created
      final payments = await paymentRepo.getPayments(
        fairId: 'fair_kolkata',
        relatedEntityType: 'expense',
        relatedEntityId: 'exp_banner',
      );
      expect(payments.length, 1);
      expect(payments.first.amountPaise, 150000);
    });

    test(
      'updateExpense updates details and recalculates outstanding obligation',
      () async {
        final expense = Expense(
          id: 'exp_decor',
          fairId: 'fair_kolkata',
          title: 'Initial Lighting Decor',
          categoryId: 'cat_lighting',
          amountPaise: 200000, // ₹2,000
          outstandingAmountPaise: 200000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await expenseRepo.createExpense(expense);

        // Increase obligation to ₹2,500
        final updated = expense.copyWith(
          title: 'Upgraded Halogen Decor',
          amountPaise: 250000,
        );

        final result = await expenseRepo.updateExpense(updated);
        expect(result.title, 'Upgraded Halogen Decor');
        expect(result.amountPaise, 250000);
        expect(result.outstandingAmountPaise, 250000);
      },
    );

    test(
      'cancelExpense zeroes outstanding amount and marks status Cancelled',
      () async {
        final expense = Expense(
          id: 'exp_cancel_test',
          fairId: 'fair_kolkata',
          title: 'Extra Chairs Rental',
          categoryId: 'cat_chair_rental',
          amountPaise: 100000,
          outstandingAmountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await expenseRepo.createExpense(expense);

        await expenseRepo.cancelExpense(
          'exp_cancel_test',
          'Chairs provided free by fair authority',
        );

        final cancelled = await expenseRepo.getExpenseById('exp_cancel_test');
        expect(cancelled, isNotNull);
        expect(cancelled!.paymentStatus, 'Cancelled');
        expect(cancelled.outstandingAmountPaise, 0);
        expect(cancelled.notes.contains('Cancelled'), isTrue);
      },
    );

    test(
      'addCategory creates custom category and watchCategories streams updates',
      () async {
        final added = await expenseRepo.addCategory(
          'Custom Sound System',
          iconName: 'speaker',
        );
        expect(added.name, 'Custom Sound System');
        expect(added.isCustom, isTrue);

        final categories = await expenseRepo.getCategories();
        expect(categories.any((c) => c.name == 'Custom Sound System'), isTrue);
      },
    );

    test('createExpense rolls back preliminary expense write if initial payment recording fails', () async {
      final now = DateTime.now();
      // Set up an account with only ₹1,000 (100,000 paise)
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_low_balance',
          fairId: 'fair_kolkata',
          accountName: 'Low Balance Box',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = Expense(
        id: 'exp_rollback_test',
        fairId: 'fair_kolkata',
        title: 'Emergency Generator',
        categoryId: 'cat_electricity',
        amountPaise: 500000, // ₹5,000
        outstandingAmountPaise: 500000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );

      // Attempt to create expense with ₹3,000 initial payment from account with only ₹1,000
      await expectLater(
        () => expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 300000, // ₹3,000 > ₹1,000 available
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_low_balance',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Verify preliminary expense was rolled back and deleted from database!
      final orphanExpense = await expenseRepo.getExpenseById(
        'exp_rollback_test',
      );
      expect(
        orphanExpense,
        isNull,
        reason: 'Expense must be rolled back on payment failure to avoid orphan records',
      );

      // Verify no payment was persisted
      final payments = await paymentRepo.getPayments(
        relatedEntityId: 'exp_rollback_test',
      );
      expect(payments.isEmpty, isTrue);

      // Verify cashbook balance remains intact
      final acc = await cashbookRepo.getAccountById('acc_low_balance');
      expect(acc?.currentBalancePaise, 100000);
    });
  });
}
