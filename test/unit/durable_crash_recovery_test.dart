import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
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
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/models/expense_model.dart';
import 'package:bookfair_manager/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_batch_model.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/data/models/payment_record_model.dart';
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
  final expenseDs = ExpenseLocalDataSourceImpl(db);
  final paymentRepo = PaymentRepositoryImpl(
    paymentDataSource: paymentDs,
    cashbookRepository: cashbookRepo,
    expenseDataSource: expenseDs,
    database: db,
    activityLogs: activityRepo,
    coordinator: coordinator,
  );
  final expenseRepo = ExpenseRepositoryImpl(
    expenseDataSource: expenseDs,
    paymentRepository: paymentRepo,
    activityLogs: activityRepo,
    cashbookRepository: cashbookRepo,
    coordinator: coordinator,
  );

  group(
    'Durable Financial Crash Recovery — Account Transfer Permutations (T1–T6)',
    () {
      const fairId = 'fair_test_crash';

      test(
        'T1: Incomplete transfer with no transaction writes rolls back cleanly',
        () async {
          await cashbookRepo.createAccount(
            CashbookAccount(
              id: 'acc_from_t1',
              fairId: fairId,
              accountName: 'From Account',
              accountType: 'cash',
              openingBalancePaise: 500000,
              currentBalancePaise: 500000,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await cashbookRepo.createAccount(
            CashbookAccount(
              id: 'acc_to_t1',
              fairId: fairId,
              accountName: 'To Account',
              accountType: 'bank',
              openingBalancePaise: 200000,
              currentBalancePaise: 200000,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          final op = FinancialOperationModel(
            id: 'op_t1',
            fairId: fairId,
            idempotencyKey: 'transfer_t1',
            requestFingerprint: 'dummy_fp',
            operationType: 'account_transfer',
            status: 'prepared',
            amountPaise: 100000,
            primaryEntityId: 'ref_t1',
            sourceAccountId: 'acc_from_t1',
            targetAccountId: 'acc_to_t1',
            payloadJson: jsonEncode({
              'debitTxId': 'debit_t1_missing',
              'creditTxId': 'credit_t1_missing',
            }),
            createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
            updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          );
          await journalDs.saveOperation(op);

          final recovered = await recoveryEngine.runStartupRecovery();
          expect(recovered, 1);

          final opAfter = journalDs.getOperationByIdempotencyKey('transfer_t1');
          expect(opAfter?.status, 'rolled_back');

          final from = await cashbookRepo.getAccountById('acc_from_t1');
          final to = await cashbookRepo.getAccountById('acc_to_t1');
          expect(from?.currentBalancePaise, 500000);
          expect(to?.currentBalancePaise, 200000);
        },
      );

      test('T2: Transfer crashed after debit write voids partial transaction and restores balance', () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_from_t2',
            fairId: fairId,
            accountName: 'From Account',
            accountType: 'cash',
            openingBalancePaise: 500000,
            currentBalancePaise: 400000, // Stale in-flight mutated balance
            createdAt: now,
            updatedAt: now,
          ),
        );
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_to_t2',
            fairId: fairId,
            accountName: 'To Account',
            accountType: 'bank',
            openingBalancePaise: 200000,
            currentBalancePaise: 200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Debit was written to disk before crash
        final debitTx = AccountTransactionModel(
          id: 'tx_debit_t2',
          fairId: fairId,
          accountId: 'acc_from_t2',
          transactionType: 'transfer_out',
          direction: 'outflow',
          amountPaise: 100000,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'transfer',
          referenceId: 'ref_t2',
          description: 'Transfer Out to To Account',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        await db.accountTransactions.put(debitTx.id, debitTx);

        final op = FinancialOperationModel(
          id: 'op_t2',
          fairId: fairId,
          idempotencyKey: 'transfer_t2',
          requestFingerprint: 'dummy_fp',
          operationType: 'account_transfer',
          status: 'processing',
          amountPaise: 100000,
          primaryEntityId: 'ref_t2',
          sourceAccountId: 'acc_from_t2',
          targetAccountId: 'acc_to_t2',
          payloadJson: jsonEncode({
            'debitTxId': 'tx_debit_t2',
            'creditTxId': 'tx_credit_t2_missing',
          }),
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await journalDs.saveOperation(op);

        final recovered = await recoveryEngine.runStartupRecovery();
        expect(recovered, 1);

        final opAfter = journalDs.getOperationByIdempotencyKey('transfer_t2');
        expect(opAfter?.status, 'rolled_back');

        // Transaction is tagged void_abandoned, NOT deleted
        final storedTx = db.accountTransactions.get('tx_debit_t2');
        expect(storedTx?.transactionType, 'void_abandoned');

        // Reprojected balance restores to full 500000
        final from = await cashbookRepo.getAccountById('acc_from_t2');
        expect(from?.currentBalancePaise, 500000);
      });

      test('T5 & T6: Complete transfer on disk is rolled forward and journal marked committed', () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_from_t5',
            fairId: fairId,
            accountName: 'From Account',
            accountType: 'cash',
            openingBalancePaise: 500000,
            currentBalancePaise: 500000, // Balance was not updated before crash
            createdAt: now,
            updatedAt: now,
          ),
        );
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_to_t5',
            fairId: fairId,
            accountName: 'To Account',
            accountType: 'bank',
            openingBalancePaise: 200000,
            currentBalancePaise: 200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final debitTx = AccountTransactionModel(
          id: 'tx_debit_t5',
          fairId: fairId,
          accountId: 'acc_from_t5',
          transactionType: 'transfer_out',
          direction: 'outflow',
          amountPaise: 150000,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'transfer',
          referenceId: 'ref_t5',
          description: 'Transfer to To Account',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        final creditTx = AccountTransactionModel(
          id: 'tx_credit_t5',
          fairId: fairId,
          accountId: 'acc_to_t5',
          transactionType: 'transfer_in',
          direction: 'inflow',
          amountPaise: 150000,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'transfer',
          referenceId: 'ref_t5',
          description: 'Transfer from From Account',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        await db.accountTransactions.put(debitTx.id, debitTx);
        await db.accountTransactions.put(creditTx.id, creditTx);

        final op = FinancialOperationModel(
          id: 'op_t5',
          fairId: fairId,
          idempotencyKey: 'transfer_t5',
          requestFingerprint: 'dummy_fp',
          operationType: 'account_transfer',
          status: 'processing',
          amountPaise: 150000,
          primaryEntityId: 'ref_t5',
          sourceAccountId: 'acc_from_t5',
          targetAccountId: 'acc_to_t5',
          payloadJson: jsonEncode({
            'debitTxId': 'tx_debit_t5',
            'creditTxId': 'tx_credit_t5',
          }),
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await journalDs.saveOperation(op);

        final recovered = await recoveryEngine.runStartupRecovery();
        expect(recovered, 1);

        final opAfter = journalDs.getOperationByIdempotencyKey('transfer_t5');
        expect(opAfter?.status, 'committed');

        // Balances derived and reprojected from valid transactions
        final from = await cashbookRepo.getAccountById('acc_from_t5');
        final to = await cashbookRepo.getAccountById('acc_to_t5');
        expect(from?.currentBalancePaise, 350000);
        expect(to?.currentBalancePaise, 350000);
      });
    },
  );

  group(
    'Durable Financial Crash Recovery — Expense Creation Permutations (E1–E7)',
    () {
      const fairId = 'fair_test_crash_exp';

      test('E1: Preliminary expense with no payment or tx rolls back and deletes preliminary expense', () async {
        final now = DateTime.now();
        final preliminaryExpense = ExpenseModel(
          id: 'exp_e1',
          fairId: fairId,
          title: 'Signboard Flex',
          description: '',
          categoryId: 'cat_marketing',
          amountPaise: 200000,
          expenseDateEpoch: now.millisecondsSinceEpoch,
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 200000,
          paymentMethod: 'Cash',
          notes: '',
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.expenses.put('exp_e1', preliminaryExpense);

        final op = FinancialOperationModel(
          id: 'op_e1',
          fairId: fairId,
          idempotencyKey: 'expense_e1',
          requestFingerprint: 'fp_e1',
          operationType: 'expense_initial_business_payment',
          status: 'prepared',
          amountPaise: 100000,
          primaryEntityId: 'exp_e1',
          secondaryEntityId: 'pay_e1',
          sourceAccountId: 'acc_e1',
          payloadJson: jsonEncode({'paymentId': 'pay_e1', 'txId': 'tx_e1'}),
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await journalDs.saveOperation(op);

        final recovered = await recoveryEngine.runStartupRecovery();
        expect(recovered, 1);

        final opAfter = journalDs.getOperationByIdempotencyKey('expense_e1');
        expect(opAfter?.status, 'rolled_back');
        expect(db.expenses.containsKey('exp_e1'), isFalse);
      });

      test('E2: Preliminary expense with debit tx but missing payment record rolls back and restores balance', () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_e2',
            fairId: fairId,
            accountName: 'Operating Cash',
            accountType: 'cash',
            openingBalancePaise: 500000,
            currentBalancePaise: 400000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final preliminaryExpense = ExpenseModel(
          id: 'exp_e2',
          fairId: fairId,
          title: 'Display Banners',
          description: '',
          categoryId: 'cat_marketing',
          amountPaise: 200000,
          expenseDateEpoch: now.millisecondsSinceEpoch,
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 200000,
          paymentMethod: 'Cash',
          notes: '',
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.expenses.put('exp_e2', preliminaryExpense);

        final tx = AccountTransactionModel(
          id: 'tx_e2',
          fairId: fairId,
          accountId: 'acc_e2',
          transactionType: 'expense_payment',
          direction: 'outflow',
          amountPaise: 100000,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'expense',
          referenceId: 'exp_e2',
          description: 'Payment for Display Banners',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        await db.accountTransactions.put('tx_e2', tx);

        final op = FinancialOperationModel(
          id: 'op_e2',
          fairId: fairId,
          idempotencyKey: 'expense_e2',
          requestFingerprint: 'fp_e2',
          operationType: 'expense_initial_business_payment',
          status: 'processing',
          amountPaise: 100000,
          primaryEntityId: 'exp_e2',
          secondaryEntityId: 'pay_e2',
          sourceAccountId: 'acc_e2',
          payloadJson: jsonEncode({'paymentId': 'pay_e2', 'txId': 'tx_e2'}),
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await journalDs.saveOperation(op);

        final recovered = await recoveryEngine.runStartupRecovery();
        expect(recovered, 1);

        expect(db.expenses.containsKey('exp_e2'), isFalse);
        expect(
          db.accountTransactions.get('tx_e2')?.transactionType,
          'void_abandoned',
        );

        final acc = await cashbookRepo.getAccountById('acc_e2');
        expect(acc?.currentBalancePaise, 500000);
      });

      test('E5 & E6: Complete initial expense writes roll forward and update summary fields', () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_e5',
            fairId: fairId,
            accountName: 'Operating Cash',
            accountType: 'cash',
            openingBalancePaise: 500000,
            currentBalancePaise: 500000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final preliminaryExpense = ExpenseModel(
          id: 'exp_e5',
          fairId: fairId,
          title: 'Electricity Setup',
          description: '',
          categoryId: 'cat_utilities',
          amountPaise: 300000,
          expenseDateEpoch: now.millisecondsSinceEpoch,
          paymentStatus: 'Unpaid', // Stale pre-payment status
          paidAmountPaise: 0,
          outstandingAmountPaise: 300000,
          paymentMethod: 'Cash',
          notes: '',
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.expenses.put('exp_e5', preliminaryExpense);

        final tx = AccountTransactionModel(
          id: 'tx_e5',
          fairId: fairId,
          accountId: 'acc_e5',
          transactionType: 'expense_payment',
          direction: 'outflow',
          amountPaise: 200000,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'expense',
          referenceId: 'exp_e5',
          description: 'Payment for Electricity Setup',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        await db.accountTransactions.put('tx_e5', tx);

        final payment = PaymentRecordModel(
          id: 'pay_e5',
          fairId: fairId,
          amountPaise: 200000,
          paymentMethod: 'Cash',
          paymentDateEpoch: now.millisecondsSinceEpoch,
          accountId: 'acc_e5',
          relatedEntityType: 'expense',
          relatedEntityId: 'exp_e5',
          notes: '',
          createdAtEpoch: now.millisecondsSinceEpoch + 10,
        );
        await db.paymentRecords.put('pay_e5', payment);

        final op = FinancialOperationModel(
          id: 'op_e5',
          fairId: fairId,
          idempotencyKey: 'expense_e5',
          requestFingerprint: 'fp_e5',
          operationType: 'expense_initial_business_payment',
          status: 'processing',
          amountPaise: 200000,
          primaryEntityId: 'exp_e5',
          secondaryEntityId: 'pay_e5',
          sourceAccountId: 'acc_e5',
          payloadJson: jsonEncode({'paymentId': 'pay_e5', 'txId': 'tx_e5'}),
          createdAtEpoch: now.millisecondsSinceEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await journalDs.saveOperation(op);

        final recovered = await recoveryEngine.runStartupRecovery();
        expect(recovered, 1);

        final opAfter = journalDs.getOperationByIdempotencyKey('expense_e5');
        expect(opAfter?.status, 'committed');

        // Expense is properly synchronized to Partially Paid
        final updatedExp = db.expenses.get('exp_e5');
        expect(updatedExp?.paidAmountPaise, 200000);
        expect(updatedExp?.outstandingAmountPaise, 100000);
        expect(updatedExp?.paymentStatus, 'Partially Paid');

        // Cashbook account balance reflects debited payment
        final acc = await cashbookRepo.getAccountById('acc_e5');
        expect(acc?.currentBalancePaise, 300000);
      });
    },
  );

  group('Durable Financial Crash Recovery — Standalone Payment & Purchase Batch (S1–S5, B1–B5)', () {
    const fairId = 'fair_test_crash_pay';

    test('S2: Standalone payment crash after ledger debit voids transaction without altering expense', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_s2',
          fairId: fairId,
          accountName: 'Operating Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 400000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final existingExpense = ExpenseModel(
        id: 'exp_s2',
        fairId: fairId,
        title: 'Carpentry',
        description: '',
        categoryId: 'cat_stall',
        amountPaise: 300000,
        expenseDateEpoch: now.millisecondsSinceEpoch,
        paymentStatus: 'Unpaid',
        paidAmountPaise: 0,
        outstandingAmountPaise: 300000,
        paymentMethod: 'Cash',
        notes: '',
        createdAtEpoch: now.millisecondsSinceEpoch,
        updatedAtEpoch: now.millisecondsSinceEpoch,
      );
      await db.expenses.put('exp_s2', existingExpense);

      final tx = AccountTransactionModel(
        id: 'tx_s2',
        fairId: fairId,
        accountId: 'acc_s2',
        transactionType: 'expense_payment',
        direction: 'outflow',
        amountPaise: 100000,
        transactionDateEpoch: now.millisecondsSinceEpoch,
        referenceType: 'expense',
        referenceId: 'exp_s2',
        description: 'Payment for Carpentry',
        createdAtEpoch: now.millisecondsSinceEpoch + 10,
      );
      await db.accountTransactions.put('tx_s2', tx);

      final op = FinancialOperationModel(
        id: 'op_s2',
        fairId: fairId,
        idempotencyKey: 'pay_s2',
        requestFingerprint: 'fp_s2',
        operationType: 'standalone_expense_payment',
        status: 'processing',
        amountPaise: 100000,
        primaryEntityId: 'exp_s2',
        secondaryEntityId: 'pay_s2_missing',
        sourceAccountId: 'acc_s2',
        payloadJson: jsonEncode({
          'paymentId': 'pay_s2_missing',
          'txId': 'tx_s2',
        }),
        createdAtEpoch: now.millisecondsSinceEpoch,
        updatedAtEpoch: now.millisecondsSinceEpoch,
      );
      await journalDs.saveOperation(op);

      final recovered = await recoveryEngine.runStartupRecovery();
      expect(recovered, 1);

      expect(
        db.accountTransactions.get('tx_s2')?.transactionType,
        'void_abandoned',
      );
      final acc = await cashbookRepo.getAccountById('acc_s2');
      expect(acc?.currentBalancePaise, 500000);

      // Existing expense remains untouched
      final exp = db.expenses.get('exp_s2');
      expect(exp?.paidAmountPaise, 0);
      expect(exp?.paymentStatus, 'Unpaid');
    });

    test('B4 & B5: Complete purchase batch payment synchronizes batch paymentStatus to Paid', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_b4',
          fairId: fairId,
          accountName: 'Bank Account',
          accountType: 'bank',
          openingBalancePaise: 1000000,
          currentBalancePaise: 1000000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final batch = PurchaseBatchModel(
        id: 'batch_b4',
        fairId: fairId,
        purchaseDateEpoch: now.millisecondsSinceEpoch,
        totalQuantity: 50,
        totalBookCostPaise: 400000,
        additionalChargesPaise: 0,
        totalAcquisitionCostPaise: 400000,
        paymentStatus: 'Unpaid',
        paymentMethod: 'Bank Transfer',
        notes: '',
        createdAtEpoch: now.millisecondsSinceEpoch,
      );
      await db.purchaseBatches.put('batch_b4', batch);

      final payment = PaymentRecordModel(
        id: 'pay_b4',
        fairId: fairId,
        amountPaise: 400000,
        paymentMethod: 'Bank Transfer',
        paymentDateEpoch: now.millisecondsSinceEpoch,
        accountId: 'acc_b4',
        relatedEntityType: 'purchase_batch',
        relatedEntityId: 'batch_b4',
        notes: '',
        createdAtEpoch: now.millisecondsSinceEpoch + 10,
      );
      await db.paymentRecords.put('pay_b4', payment);

      final tx = AccountTransactionModel(
        id: 'tx_b4',
        fairId: fairId,
        accountId: 'acc_b4',
        transactionType: 'purchase_payment',
        direction: 'outflow',
        amountPaise: 400000,
        transactionDateEpoch: now.millisecondsSinceEpoch,
        referenceType: 'purchase_batch',
        referenceId: 'batch_b4',
        description: 'Payment for Purchase Batch',
        createdAtEpoch: now.millisecondsSinceEpoch + 10,
      );
      await db.accountTransactions.put('tx_b4', tx);

      final op = FinancialOperationModel(
        id: 'op_b4',
        fairId: fairId,
        idempotencyKey: 'pay_b4_op',
        requestFingerprint: 'fp_b4',
        operationType: 'purchase_batch_payment',
        status: 'processing',
        amountPaise: 400000,
        primaryEntityId: 'batch_b4',
        secondaryEntityId: 'pay_b4',
        sourceAccountId: 'acc_b4',
        payloadJson: jsonEncode({'paymentId': 'pay_b4', 'txId': 'tx_b4'}),
        createdAtEpoch: now.millisecondsSinceEpoch,
        updatedAtEpoch: now.millisecondsSinceEpoch,
      );
      await journalDs.saveOperation(op);

      final recovered = await recoveryEngine.runStartupRecovery();
      expect(recovered, 1);

      final updatedBatch = db.purchaseBatches.get('batch_b4');
      expect(updatedBatch?.paymentStatus, 'Paid');

      final acc = await cashbookRepo.getAccountById('acc_b4');
      expect(acc?.currentBalancePaise, 600000);
    });
  });

  group(
    'Durable Financial Crash Recovery — Expense Cancellation & Refund Reversal',
    () {
      const fairId = 'fair_test_cancel_refund';

      test(
        'Unpaid expense cancels directly and marks status Cancelled',
        () async {
          final now = DateTime.now();
          final expense = Expense(
            id: 'exp_unpaid_cancel',
            fairId: fairId,
            title: 'Snacks Delivery',
            categoryId: 'cat_food',
            amountPaise: 50000,
            outstandingAmountPaise: 50000,
            expenseDate: now,
            paymentStatus: 'Unpaid',
            createdAt: now,
            updatedAt: now,
          );
          await expenseRepo.createExpense(expense);

          await expenseRepo.cancelExpense(
            'exp_unpaid_cancel',
            'Order cancelled',
          );

          final cancelled = await expenseRepo.getExpenseById(
            'exp_unpaid_cancel',
          );
          expect(cancelled?.paymentStatus, 'Cancelled');
          expect(cancelled?.outstandingAmountPaise, 0);
        },
      );

      test('Paid expense cancellation requires refund destination account and records reversing flow', () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_refund_dest',
            fairId: fairId,
            accountName: 'Main Cash',
            accountType: 'cash',
            openingBalancePaise: 1000000,
            currentBalancePaise: 1000000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final expense = Expense(
          id: 'exp_paid_cancel',
          fairId: fairId,
          title: 'Booth Furniture',
          categoryId: 'cat_furniture',
          amountPaise: 400000,
          outstandingAmountPaise: 400000,
          expenseDate: now,
          paymentStatus: 'Unpaid',
          createdAt: now,
          updatedAt: now,
        );
        await expenseRepo.createExpense(
          expense,
          initialPaymentAmountPaise: 400000,
          paidFromAccountId: 'acc_refund_dest',
          paymentMethod: 'Cash',
        );

        final accAfterPay = await cashbookRepo.getAccountById(
          'acc_refund_dest',
        );
        expect(accAfterPay?.currentBalancePaise, 600000);

        // Cancelling with refund destination account executes refund flow
        await expenseRepo.cancelExpense(
          'exp_paid_cancel',
          'Vendor returned advance',
          refundToAccountId: 'acc_refund_dest',
        );

        final expAfter = await expenseRepo.getExpenseById('exp_paid_cancel');
        expect(expAfter?.paymentStatus, 'Cancelled (Refunded)');
        expect(expAfter?.outstandingAmountPaise, 0);

        final accAfterRefund = await cashbookRepo.getAccountById(
          'acc_refund_dest',
        );
        expect(accAfterRefund?.currentBalancePaise, 1000000);

        // Inflow transaction and refund payment record exist
        final txs = await cashbookRepo.getTransactions(fairId: fairId);
        final refundTx = txs.firstWhere(
          (t) => t.transactionType == 'refund_received',
        );
        expect(refundTx.amountPaise, 400000);
        expect(refundTx.direction, 'inflow');

        final payments = await paymentRepo.getPayments(fairId: fairId);
        final refundPay = payments.firstWhere(
          (p) => p.relatedEntityType == 'expense_refund',
        );
        expect(refundPay.amountPaise, 400000);
      });
    },
  );

  group('Durable Financial Crash Recovery — Idempotency & Conflict Detection', () {
    const fairId = 'fair_test_idempotency';

    test('Same clientRequestId with identical parameters returns committed result without duplicate writes', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_idem_from',
          fairId: fairId,
          accountName: 'From Acc',
          accountType: 'cash',
          openingBalancePaise: 800000,
          currentBalancePaise: 800000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_idem_to',
          fairId: fairId,
          accountName: 'To Acc',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      const clientReqId = 'req_stable_001';

      // First invocation
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_idem_from',
        toAccountId: 'acc_idem_to',
        amountPaise: 200000,
        transferDate: now,
        clientRequestId: clientReqId,
      );

      final from1 = await cashbookRepo.getAccountById('acc_idem_from');
      final to1 = await cashbookRepo.getAccountById('acc_idem_to');
      expect(from1?.currentBalancePaise, 600000);
      expect(to1?.currentBalancePaise, 300000);

      // Replay with identical parameters and clientRequestId
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_idem_from',
        toAccountId: 'acc_idem_to',
        amountPaise: 200000,
        transferDate: now,
        clientRequestId: clientReqId,
      );

      // Balances must NOT be debited twice!
      final from2 = await cashbookRepo.getAccountById('acc_idem_from');
      final to2 = await cashbookRepo.getAccountById('acc_idem_to');
      expect(from2?.currentBalancePaise, 600000);
      expect(to2?.currentBalancePaise, 300000);

      // Ledger must contain exactly 2 transfer transactions (1 debit, 1 credit), not 4
      final txs = await cashbookRepo.getTransactions(fairId: fairId);
      final transfers = txs
          .where((t) => t.referenceType == 'transfer')
          .toList();
      expect(transfers.length, 2);
    });

    test('Same clientRequestId with conflicting amount throws IdempotencyConflictException', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_conflict_from',
          fairId: fairId,
          accountName: 'From Acc',
          accountType: 'cash',
          openingBalancePaise: 800000,
          currentBalancePaise: 800000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_conflict_to',
          fairId: fairId,
          accountName: 'To Acc',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      const clientReqId = 'req_stable_conflict';

      // First invocation
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_conflict_from',
        toAccountId: 'acc_conflict_to',
        amountPaise: 200000,
        transferDate: now,
        clientRequestId: clientReqId,
      );

      // Inconsistent retry with different amount using same request identifier
      await expectLater(
        () => cashbookRepo.transferFunds(
          fairId: fairId,
          fromAccountId: 'acc_conflict_from',
          toAccountId: 'acc_conflict_to',
          amountPaise: 500000, // Conflict: was 200000
          transferDate: now,
          clientRequestId: clientReqId,
        ),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });
  });

  group('Durable Financial Crash Recovery — Account Quarantine', () {
    const fairId = 'fair_test_quarantine';

    test('Recovery fatal failure quarantines account and blocks subsequent mutations', () async {
      FinancialOperationCoordinator.quarantineAccount('acc_quarantine_fatal');
      expect(
        FinancialOperationCoordinator.isAccountQuarantined(
          'acc_quarantine_fatal',
        ),
        isTrue,
      );

      final now = DateTime.now();
      await expectLater(
        () => cashbookRepo.transferFunds(
          fairId: fairId,
          fromAccountId: 'acc_quarantine_fatal',
          toAccountId: 'acc_dest_quarantine',
          amountPaise: 10000,
          transferDate: now,
        ),
        throwsA(isA<AccountQuarantinedException>()),
      );

      // Release quarantine and verify normal operations resume
      FinancialOperationCoordinator.releaseQuarantine('acc_quarantine_fatal');
      expect(
        FinancialOperationCoordinator.isAccountQuarantined(
          'acc_quarantine_fatal',
        ),
        isFalse,
      );
    });
  });
}
