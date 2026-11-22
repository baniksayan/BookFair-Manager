import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_constants.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/core/database/database_initializer.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/models/account_transaction_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/cashbook_account_model.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/models/expense_model.dart';
import 'package:bookfair_manager/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/data/models/payment_record_model.dart';
import 'package:bookfair_manager/features/payments/data/repositories/payment_repository_impl.dart';

import '../test_helper.dart';

// --- Failure-Injecting Data Source Test Doubles ---

class FailingPaymentDataSource extends PaymentLocalDataSourceImpl {
  FailingPaymentDataSource(super.db);
  bool failSavePayment = false;

  @override
  Future<void> savePayment(PaymentRecordModel payment) async {
    if (failSavePayment) {
      throw const DatabaseException(
        'Simulated I/O failure during payment record write',
      );
    }
    return super.savePayment(payment);
  }
}

class FailingCashbookDataSource extends CashbookLocalDataSourceImpl {
  FailingCashbookDataSource(super.db);
  bool failCreditTxSave = false;
  bool failToAccountSave = false;

  @override
  Future<void> saveTransaction(AccountTransactionModel transaction) async {
    if (failCreditTxSave && transaction.transactionType == 'transfer_in') {
      throw const DatabaseException(
        'Simulated disk error during destination credit transaction persistence',
      );
    }
    return super.saveTransaction(transaction);
  }

  @override
  Future<void> saveAccount(CashbookAccountModel account) async {
    if (failToAccountSave && account.accountName == 'Destination Account') {
      throw const DatabaseException(
        'Simulated crash during destination account balance update',
      );
    }
    return super.saveAccount(account);
  }
}

class FailingExpenseDataSource extends ExpenseLocalDataSourceImpl {
  FailingExpenseDataSource(super.db);
  bool failPostPaymentSave = false;
  int expenseSaveCount = 0;

  @override
  Future<void> saveExpense(ExpenseModel expense) async {
    expenseSaveCount++;
    if (failPostPaymentSave && expenseSaveCount > 1) {
      throw const DatabaseException(
        'Simulated error updating expense status after payment record',
      );
    }
    return super.saveExpense(expense);
  }
}

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

  group('Financial Safety & Failure-Injection Boundaries', () {
    test('Boundary 1: Pre-flight check rejects business-funded expense with insufficient balance before write', () async {
      final cashbookDs = CashbookLocalDataSourceImpl(db);
      final cashbookRepo = CashbookRepositoryImpl(cashbookDs, activityRepo);
      final expenseDs = ExpenseLocalDataSourceImpl(db);
      final paymentDs = PaymentLocalDataSourceImpl(db);
      final paymentRepo = PaymentRepositoryImpl(
        paymentDataSource: paymentDs,
        cashbookRepository: cashbookRepo,
        expenseDataSource: expenseDs,
        database: db,
        activityLogs: activityRepo,
      );
      final expenseRepo = ExpenseRepositoryImpl(
        expenseDataSource: expenseDs,
        paymentRepository: paymentRepo,
        activityLogs: activityRepo,
        cashbookRepository: cashbookRepo,
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_preflight',
          fairId: 'fair_safe',
          accountName: 'Preflight Cashbox',
          accountType: 'cash',
          openingBalancePaise: 100000, // ₹1,000
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = Expense(
        id: 'exp_preflight_fail',
        fairId: 'fair_safe',
        title: 'Mega Flex Banner',
        categoryId: 'cat_banner',
        amountPaise: 400000, // ₹4,000
        outstandingAmountPaise: 400000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );

      // Attempt ₹2,500 initial payment from account with only ₹1,000
      await expectLater(
        () => expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 250000,
          paidFromAccountId: 'acc_preflight',
          paymentMethod: 'Cash',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Verify zero partial state
      final fetchedExpense = await expenseRepo.getExpenseById(
        'exp_preflight_fail',
      );
      expect(
        fetchedExpense,
        isNull,
        reason: 'Expense must not be saved if pre-flight fails',
      );

      final payments = await paymentRepo.getPayments(fairId: 'fair_safe');
      expect(payments.isEmpty, isTrue, reason: 'No payment should exist');

      final txs = await cashbookRepo.getTransactions(fairId: 'fair_safe');
      // Only opening balance transaction if any
      expect(txs.where((t) => t.referenceType == 'expense').isEmpty, isTrue);

      final account = await cashbookRepo.getAccountById('acc_preflight');
      expect(
        account?.currentBalancePaise,
        100000,
        reason: 'Balance must not change',
      );
    });

    test('Boundary 2: Failure during payment save triggers compensating rollback of cashbook movement and deletes preliminary expense', () async {
      final cashbookDs = CashbookLocalDataSourceImpl(db);
      final cashbookRepo = CashbookRepositoryImpl(cashbookDs, activityRepo);
      final expenseDs = ExpenseLocalDataSourceImpl(db);
      final failingPaymentDs = FailingPaymentDataSource(db);

      final paymentRepo = PaymentRepositoryImpl(
        paymentDataSource: failingPaymentDs,
        cashbookRepository: cashbookRepo,
        expenseDataSource: expenseDs,
        database: db,
        activityLogs: activityRepo,
      );
      final expenseRepo = ExpenseRepositoryImpl(
        expenseDataSource: expenseDs,
        paymentRepository: paymentRepo,
        activityLogs: activityRepo,
        // Intentionally omit cashbookRepo in ExpenseRepo to test PaymentRepo boundary rollback
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_rollback_test',
          fairId: 'fair_safe',
          accountName: 'Operating Cash',
          accountType: 'cash',
          openingBalancePaise: 500000, // ₹5,000
          currentBalancePaise: 500000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = Expense(
        id: 'exp_payment_fail',
        fairId: 'fair_safe',
        title: 'Lighting Rigging',
        categoryId: 'cat_lighting',
        amountPaise: 300000, // ₹3,000
        outstandingAmountPaise: 300000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );

      // Inject simulated failure during payment record save
      failingPaymentDs.failSavePayment = true;

      await expectLater(
        () => expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 200000, // ₹2,000
          paidFromAccountId: 'acc_rollback_test',
          paymentMethod: 'Cash',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Verify:
      // 1. Preliminary expense was rolled back and deleted
      final orphanExp = await expenseRepo.getExpenseById('exp_payment_fail');
      expect(
        orphanExp,
        isNull,
        reason: 'Preliminary expense must be deleted on payment failure',
      );

      // 2. Payment record was not saved
      final payments = await paymentRepo.getPayments(fairId: 'fair_safe');
      expect(payments.isEmpty, isTrue, reason: 'Payment record must not exist');

      // 3. Cashbook movement was rolled back, transaction deleted
      final txs = await cashbookRepo.getTransactions(fairId: 'fair_safe');
      expect(
        txs.where((t) => t.referenceType == 'expense').isEmpty,
        isTrue,
        reason: 'Compensating rollback must remove cashbook transaction',
      );

      // 4. Cashbook account balance was completely restored
      final acc = await cashbookRepo.getAccountById('acc_rollback_test');
      expect(
        acc?.currentBalancePaise,
        500000,
        reason: 'Account balance must be restored to original ₹5,000',
      );
    });

    test('Boundary 3: Failure after payment save during expense status update rolls back payment, cashbook, and preliminary expense', () async {
      final cashbookDs = CashbookLocalDataSourceImpl(db);
      final cashbookRepo = CashbookRepositoryImpl(cashbookDs, activityRepo);
      final failingExpenseDs = FailingExpenseDataSource(db);
      final paymentDs = PaymentLocalDataSourceImpl(db);

      final paymentRepo = PaymentRepositoryImpl(
        paymentDataSource: paymentDs,
        cashbookRepository: cashbookRepo,
        expenseDataSource: failingExpenseDs,
        database: db,
        activityLogs: activityRepo,
      );
      final expenseRepo = ExpenseRepositoryImpl(
        expenseDataSource: failingExpenseDs,
        paymentRepository: paymentRepo,
        activityLogs: activityRepo,
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_postpay_fail',
          fairId: 'fair_safe',
          accountName: 'Stall Cashbox',
          accountType: 'cash',
          openingBalancePaise: 400000, // ₹4,000
          currentBalancePaise: 400000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = Expense(
        id: 'exp_postpay_fail',
        fairId: 'fair_safe',
        title: 'Sound System Rental',
        categoryId: 'cat_sound',
        amountPaise: 250000, // ₹2,500
        outstandingAmountPaise: 250000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );

      // Inject failure on the second expense save (which happens during payment recording)
      failingExpenseDs.failPostPaymentSave = true;

      await expectLater(
        () => expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 150000, // ₹1,500
          paidFromAccountId: 'acc_postpay_fail',
          paymentMethod: 'Cash',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Verify:
      // 1. Preliminary expense was rolled back
      final orphanExp = await expenseRepo.getExpenseById('exp_postpay_fail');
      expect(
        orphanExp,
        isNull,
        reason: 'Expense must be deleted on post-payment failure',
      );

      // 2. Saved payment was rolled back and deleted
      final payments = await paymentRepo.getPayments(fairId: 'fair_safe');
      expect(
        payments.isEmpty,
        isTrue,
        reason: 'Payment record must be deleted during rollback',
      );

      // 3. Cashbook transaction was reversed and deleted
      final txs = await cashbookRepo.getTransactions(fairId: 'fair_safe');
      expect(txs.where((t) => t.referenceType == 'expense').isEmpty, isTrue);

      // 4. Cashbook account balance restored to initial ₹4,000
      final acc = await cashbookRepo.getAccountById('acc_postpay_fail');
      expect(
        acc?.currentBalancePaise,
        400000,
        reason: 'Balance must be restored',
      );
    });

    test('Boundary 4: Partner-personal payment failure rolls back preliminary expense cleanly without touching cashbook', () async {
      final cashbookDs = CashbookLocalDataSourceImpl(db);
      final cashbookRepo = CashbookRepositoryImpl(cashbookDs, activityRepo);
      final expenseDs = ExpenseLocalDataSourceImpl(db);
      final failingPaymentDs = FailingPaymentDataSource(db);

      final paymentRepo = PaymentRepositoryImpl(
        paymentDataSource: failingPaymentDs,
        cashbookRepository: cashbookRepo,
        expenseDataSource: expenseDs,
        database: db,
        activityLogs: activityRepo,
      );
      final expenseRepo = ExpenseRepositoryImpl(
        expenseDataSource: expenseDs,
        paymentRepository: paymentRepo,
        activityLogs: activityRepo,
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_untouched',
          fairId: 'fair_safe',
          accountName: 'Untouched Main Account',
          accountType: 'cash',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = Expense(
        id: 'exp_partner_fail',
        fairId: 'fair_safe',
        title: 'Guest Refreshments',
        categoryId: 'cat_food',
        amountPaise: 120000, // ₹1,200
        outstandingAmountPaise: 120000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );

      // Fail during payment write
      failingPaymentDs.failSavePayment = true;

      await expectLater(
        () => expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 120000,
          paidByPartnerId: 'partner_rahul', // Partner financed personal payment
          paymentMethod: 'UPI',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Verify preliminary expense was cleaned up
      final orphanExp = await expenseRepo.getExpenseById('exp_partner_fail');
      expect(orphanExp, isNull);

      // Verify cashbook was completely untouched
      final acc = await cashbookRepo.getAccountById('acc_untouched');
      expect(acc?.currentBalancePaise, 100000);
    });

    test('Boundary 5: Account transfer rollback when destination credit transaction write fails', () async {
      final failingCashbookDs = FailingCashbookDataSource(db);
      final cashbookRepo = CashbookRepositoryImpl(
        failingCashbookDs,
        activityRepo,
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_source_1',
          fairId: 'fair_safe',
          accountName: 'Source Cash',
          accountType: 'cash',
          openingBalancePaise: 500000, // ₹5,000
          currentBalancePaise: 500000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_dest_1',
          fairId: 'fair_safe',
          accountName: 'Destination Account',
          accountType: 'upi',
          openingBalancePaise: 200000, // ₹2,000
          currentBalancePaise: 200000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Fail during destination credit transaction
      failingCashbookDs.failCreditTxSave = true;

      await expectLater(
        () => cashbookRepo.transferFunds(
          fairId: 'fair_safe',
          fromAccountId: 'acc_source_1',
          toAccountId: 'acc_dest_1',
          amountPaise: 150000, // ₹1,500
          transferDate: now,
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Verify:
      // 1. Debit transaction was rolled back and deleted
      final txs = await cashbookRepo.getTransactions(fairId: 'fair_safe');
      expect(
        txs.where((t) => t.referenceType == 'transfer').isEmpty,
        isTrue,
        reason: 'No transfer transactions should remain after rollback',
      );

      // 2. Both balances are untouched
      final source = await cashbookRepo.getAccountById('acc_source_1');
      final dest = await cashbookRepo.getAccountById('acc_dest_1');
      expect(source?.currentBalancePaise, 500000);
      expect(dest?.currentBalancePaise, 200000);
    });

    test('Boundary 6: Account transfer rollback when destination account balance write fails restores source debit', () async {
      final failingCashbookDs = FailingCashbookDataSource(db);
      final cashbookRepo = CashbookRepositoryImpl(
        failingCashbookDs,
        activityRepo,
      );

      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_source_2',
          fairId: 'fair_safe',
          accountName: 'Source Bank',
          accountType: 'bank',
          openingBalancePaise: 600000, // ₹6,000
          currentBalancePaise: 600000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_dest_2',
          fairId: 'fair_safe',
          accountName: 'Destination Account', // Trigger failure
          accountType: 'cash',
          openingBalancePaise: 100000, // ₹1,000
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Fail during destination account write (source account was already debited!)
      failingCashbookDs.failToAccountSave = true;

      await expectLater(
        () => cashbookRepo.transferFunds(
          fairId: 'fair_safe',
          fromAccountId: 'acc_source_2',
          toAccountId: 'acc_dest_2',
          amountPaise: 200000, // ₹2,000
          transferDate: now,
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Verify compensating rollback:
      // 1. Source account balance was restored back to ₹6,000!
      final source = await cashbookRepo.getAccountById('acc_source_2');
      expect(
        source?.currentBalancePaise,
        600000,
        reason: 'Source debit must be restored if destination update fails',
      );

      // 2. Destination account remained ₹1,000
      final dest = await cashbookRepo.getAccountById('acc_dest_2');
      expect(dest?.currentBalancePaise, 100000);

      // 3. Transactions were deleted
      final txs = await cashbookRepo.getTransactions(fairId: 'fair_safe');
      expect(txs.where((t) => t.referenceType == 'transfer').isEmpty, isTrue);
    });

    test('Boundary 7: Higher stored schema version is safely preserved and never downgraded', () async {
      final metaBox = Hive.box<dynamic>(DatabaseConstants.metadataBox);
      // Simulate database written by future version 6 of BookFair Manager
      await metaBox.put(DatabaseConstants.schemaVersionKey, 6);

      // Re-run database schema verification in an isolated temporary directory
      final tempDir = await Directory.systemTemp.createTemp(
        'hive_future_test_',
      );
      try {
        await DatabaseInitializer.initTest(path: tempDir.path);

        final testMetaBox = Hive.box<dynamic>(DatabaseConstants.metadataBox);
        // Set to 6 and verify schema check does not downgrade it to 5
        await testMetaBox.put(DatabaseConstants.schemaVersionKey, 6);

        // Close and re-open to trigger _verifyAndMigrateSchema
        await DatabaseInitializer.close();
        await DatabaseInitializer.initTest(path: tempDir.path);

        final reloadedMetaBox = Hive.box<dynamic>(
          DatabaseConstants.metadataBox,
        );
        final storedVersion = reloadedMetaBox.get(
          DatabaseConstants.schemaVersionKey,
        );

        expect(
          storedVersion,
          6,
          reason: 'Database schema version 6 must be preserved and never downgraded to 5',
        );
      } finally {
        await DatabaseInitializer.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
        // Restore test suite database
        await TestDatabaseHelper.setUpSuiteDatabase();
      }
    });
  });
}
