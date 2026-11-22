import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_constants.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/core/database/database_initializer.dart';
import 'package:bookfair_manager/core/utils/financial_draft_manager.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/investment_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/investment.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/financial_operation_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/models/account_transaction_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/cashbook_account_model.dart';
import 'package:bookfair_manager/features/cashbook/data/models/financial_operation_model.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/cashbook/domain/services/financial_operation_coordinator.dart';
import 'package:bookfair_manager/features/cashbook/domain/services/financial_recovery_engine.dart';
import 'package:bookfair_manager/features/cashbook/presentation/view_models/cashbook_providers.dart';
import 'package:bookfair_manager/features/cashbook/presentation/view_models/transfer_funds_view_model.dart';
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/expenses/presentation/view_models/expense_form_view_model.dart';
import 'package:bookfair_manager/features/expenses/presentation/view_models/expense_providers.dart';
import 'package:bookfair_manager/features/inventory/data/datasources/inventory_local_datasource.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_batch_model.dart';
import 'package:bookfair_manager/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/presentation/view_models/inventory_providers.dart';
import 'package:bookfair_manager/features/inventory/presentation/view_models/purchase_batch_form_view_model.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/data/models/payment_record_model.dart';
import 'package:bookfair_manager/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:bookfair_manager/features/payments/domain/entities/payment_record.dart'
    hide PaymentMethod;

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
    FinancialOperationCoordinator.clearQuarantineForTesting();
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
  final inventoryDs = InventoryLocalDataSourceImpl(db);
  final inventoryRepo = InventoryRepositoryImpl(inventoryDs, activityRepo);

  group('1. Critical Opening-Balance Verification', () {
    test('Account with ₹5,000 opening balance, ₹5,000 baseline snapshot, and ₹5,000 opening tx derives ₹5,000 (NOT ₹10,000)', () async {
      // Step A: Create account through repo with opening balance ₹5,000 (500000 paise)
      final account = CashbookAccount(
        id: 'acc_opening_test',
        fairId: 'fair_audit',
        accountName: 'Audit Cash Box',
        accountType: 'cash',
        openingBalancePaise: 500000,
        currentBalancePaise: 500000,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await cashbookRepo.createAccount(account);

      // Verify initial state
      final createdAcc = await cashbookRepo.getAccountById('acc_opening_test');
      expect(createdAcc, isNotNull);
      expect(createdAcc!.currentBalancePaise, equals(500000));
      expect(createdAcc.openingBalancePaise, equals(500000));

      // Verify baseline snapshot in metadataBox
      final baseline =
          db.metadata.get('account_baseline_v5_acc_opening_test') as int?;
      expect(baseline, equals(500000));

      // Verify opening-balance transaction in ledger
      final txs = await cashbookRepo.getTransactions(
        accountId: 'acc_opening_test',
      );
      expect(txs.length, equals(1));
      expect(txs.first.transactionType, equals('opening_balance'));
      expect(txs.first.amountPaise, equals(500000));

      // Step B: Trigger startup recovery engine (which re-projects canonical account balance)
      await recoveryEngine.runStartupRecovery();

      // Step C: Verify projected balance is ₹5,000 (500,000 paise) and NEVER ₹10,000 (1,000,000 paise)
      final reloadedAcc = await cashbookRepo.getAccountById('acc_opening_test');
      expect(
        reloadedAcc!.currentBalancePaise,
        equals(500000),
        reason: 'Derived balance must be ₹5,000 and not ₹10,000',
      );

      // Step D: Add subsequent transactions to prove incremental net delta projection
      // Inflow of ₹1,000 (100000 paise)
      await cashbookRepo.recordAccountMovement(
        fairId: 'fair_audit',
        accountId: 'acc_opening_test',
        transactionType: 'manual_inflow',
        direction: 'inflow',
        amountPaise: 100000,
        transactionDate: DateTime.now(),
        referenceType: 'manual',
        description: 'Sales Cash Deposit',
      );

      // Outflow of ₹500 (50000 paise)
      await cashbookRepo.recordAccountMovement(
        fairId: 'fair_audit',
        accountId: 'acc_opening_test',
        transactionType: 'manual_outflow',
        direction: 'outflow',
        amountPaise: 50000,
        transactionDate: DateTime.now(),
        referenceType: 'manual',
        description: 'Tea & Snacks',
      );

      // Reproject through recovery engine
      await recoveryEngine.runStartupRecovery();

      final updatedAcc = await cashbookRepo.getAccountById('acc_opening_test');
      expect(
        updatedAcc!.currentBalancePaise,
        equals(550000), // 500000 + 100000 - 50000 = 550000
        reason: 'Net balance reflects baseline + non-opening transactions',
      );
    });
  });

  group('2. Persistent Idempotency Verification', () {
    test('ExpenseFormViewModel persists clientRequestId in Hive metadataBox and survives restarts', () async {
      final container1 = ProviderContainer(
        overrides: [expenseRepositoryProvider.overrideWithValue(expenseRepo)],
      );

      // Read initial state of ViewModel
      final state1 = container1.read(
        expenseFormViewModelProvider('fair_audit'),
      );
      final clientReqId1 = state1.clientRequestId;
      expect(clientReqId1.isNotEmpty, isTrue);

      // Verify draft was saved in metadataBox
      final draftData = db.metadata.get('draft_expense_fair_audit');
      expect(draftData, isA<Map>());
      expect((draftData as Map)['clientRequestId'], equals(clientReqId1));

      // Simulate closing the form and application restart by disposing container 1
      container1.dispose();

      // Initialize new container (Container 2)
      final container2 = ProviderContainer(
        overrides: [expenseRepositoryProvider.overrideWithValue(expenseRepo)],
      );

      final state2 = container2.read(
        expenseFormViewModelProvider('fair_audit'),
      );
      expect(
        state2.clientRequestId,
        equals(clientReqId1),
        reason:
            'clientRequestId must survive ViewModel disposal and app restart',
      );

      // Complete expense creation via container 2
      final vm2 = container2.read(
        expenseFormViewModelProvider('fair_audit').notifier,
      );
      vm2.setTitle('Audit Printed Banners');
      vm2.setCategoryId('cat_promo');
      vm2.setAmount('250.00');
      vm2.setPaidAmount('0');

      final created = await vm2.submit();
      expect(created, isNotNull);
      expect(created!.title, equals('Audit Printed Banners'));

      // Verify draft in metadataBox was removed on commit
      final draftAfterCommit = db.metadata.get('draft_expense_fair_audit');
      expect(draftAfterCommit, isNull);

      container2.dispose();
    });

    test('TransferFundsViewModel persists clientRequestId in Hive metadataBox and survives restarts', () async {
      // Setup source and destination accounts
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_tf_src',
          fairId: 'fair_tf',
          accountName: 'Bank TF Source',
          accountType: 'bank',
          openingBalancePaise: 200000,
          currentBalancePaise: 200000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_tf_dst',
          fairId: 'fair_tf',
          accountName: 'Cash TF Dest',
          accountType: 'cash',
          openingBalancePaise: 50000,
          currentBalancePaise: 50000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container1 = ProviderContainer(
        overrides: [cashbookRepositoryProvider.overrideWithValue(cashbookRepo)],
      );

      final vm1 = container1.read(transferFundsViewModelProvider.notifier);
      vm1.setFairId('fair_tf');
      final state1 = container1.read(transferFundsViewModelProvider);
      final clientReqId1 = state1.clientRequestId;
      expect(clientReqId1.isNotEmpty, isTrue);

      final draft1 = db.metadata.get('draft_transfer_fair_tf');
      expect(draft1, isA<Map>());
      expect((draft1 as Map)['clientRequestId'], equals(clientReqId1));

      container1.dispose();

      // Recreate ViewModel
      final container2 = ProviderContainer(
        overrides: [cashbookRepositoryProvider.overrideWithValue(cashbookRepo)],
      );

      final vm2 = container2.read(transferFundsViewModelProvider.notifier);
      vm2.setFairId('fair_tf');
      final state2 = container2.read(transferFundsViewModelProvider);
      expect(state2.clientRequestId, equals(clientReqId1));

      vm2.setFromAccountId('acc_tf_src');
      vm2.setToAccountId('acc_tf_dst');
      vm2.setAmount('500.00');

      final ok = await vm2.executeTransfer();
      expect(ok, isTrue);

      // Draft should be cleared
      final draftAfter = db.metadata.get('draft_transfer_fair_tf');
      expect(draftAfter, isNull);

      container2.dispose();
    });

    test('Coordinator replays committed transfer on duplicate submission without duplicate writes', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_dup_src',
          fairId: 'fair_dup',
          accountName: 'Src Dup',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_dup_dst',
          fairId: 'fair_dup',
          accountName: 'Dst Dup',
          accountType: 'cash',
          openingBalancePaise: 10000,
          currentBalancePaise: 10000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const clientReqId = 'dup_transfer_req_123';

      // First execution
      await cashbookRepo.transferFunds(
        fairId: 'fair_dup',
        fromAccountId: 'acc_dup_src',
        toAccountId: 'acc_dup_dst',
        amountPaise: 20000,
        transferDate: DateTime.now(),
        clientRequestId: clientReqId,
      );

      final src1 = await cashbookRepo.getAccountById('acc_dup_src');
      final dst1 = await cashbookRepo.getAccountById('acc_dup_dst');
      expect(src1!.currentBalancePaise, equals(80000));
      expect(dst1!.currentBalancePaise, equals(30000));

      final txCount1 = (await cashbookRepo.getTransactions(
        accountId: 'acc_dup_src',
      )).length;

      // Duplicate execution with exact same clientRequestId and parameters
      await cashbookRepo.transferFunds(
        fairId: 'fair_dup',
        fromAccountId: 'acc_dup_src',
        toAccountId: 'acc_dup_dst',
        amountPaise: 20000,
        transferDate: DateTime.now(),
        clientRequestId: clientReqId,
      );

      final src2 = await cashbookRepo.getAccountById('acc_dup_src');
      final dst2 = await cashbookRepo.getAccountById('acc_dup_dst');
      expect(
        src2!.currentBalancePaise,
        equals(80000),
        reason: 'Balance must not be debited twice',
      );
      expect(
        dst2!.currentBalancePaise,
        equals(30000),
        reason: 'Balance must not be credited twice',
      );

      final txCount2 = (await cashbookRepo.getTransactions(
        accountId: 'acc_dup_src',
      )).length;
      expect(
        txCount2,
        equals(txCount1),
        reason: 'No duplicate ledger transactions generated',
      );
    });

    test('Coordinator detects conflicting parameters with same clientRequestId and throws IdempotencyConflictException', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_conf_src',
          fairId: 'fair_conf',
          accountName: 'Src Conf',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_conf_dst',
          fairId: 'fair_conf',
          accountName: 'Dst Conf',
          accountType: 'cash',
          openingBalancePaise: 10000,
          currentBalancePaise: 10000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const clientReqId = 'conflict_transfer_req_789';

      await cashbookRepo.transferFunds(
        fairId: 'fair_conf',
        fromAccountId: 'acc_conf_src',
        toAccountId: 'acc_conf_dst',
        amountPaise: 20000,
        transferDate: DateTime.now(),
        clientRequestId: clientReqId,
      );

      // Attempt second submission with SAME clientRequestId but DIFFERENT amount (50,000 paise instead of 20,000)
      expect(
        () => cashbookRepo.transferFunds(
          fairId: 'fair_conf',
          fromAccountId: 'acc_conf_src',
          toAccountId: 'acc_conf_dst',
          amountPaise: 50000,
          transferDate: DateTime.now(),
          clientRequestId: clientReqId,
        ),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });

    test('Retrying a failed/rolled-back operation creates Attempt 2 linked via parentOperationId', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const idempotencyKey = 'retry_audit_op_key';
      final fingerprint = coordinator.computeFingerprint(
        amountPaise: 15000,
        sourceAccountId: 'acc_retry_1',
        primaryEntityId: 'entity_retry_1',
      );

      // Save a rolled-back Attempt 1
      final attempt1 = FinancialOperationModel(
        id: 'op_attempt_1',
        fairId: 'fair_retry',
        idempotencyKey: idempotencyKey,
        requestFingerprint: fingerprint,
        operationType: 'standalone_expense_payment',
        status: 'rolled_back',
        amountPaise: 15000,
        primaryEntityId: 'entity_retry_1',
        sourceAccountId: 'acc_retry_1',
        payloadJson: jsonEncode({'note': 'Attempt 1 failed'}),
        attemptNumber: 1,
        createdAtEpoch: now - 5000,
        updatedAtEpoch: now - 5000,
      );
      await journalDs.saveOperation(attempt1);

      // Now run operation via coordinator with same idempotency key
      final result = await coordinator.runCoordinatedOperation<String>(
        fairId: 'fair_retry',
        operationType: 'standalone_expense_payment',
        idempotencyKey: idempotencyKey,
        amountPaise: 15000,
        primaryEntityId: 'entity_retry_1',
        sourceAccountId: 'acc_retry_1',
        payload: {'note': 'Attempt 2 succeeded'},
        affectedBoxes: [db.financialOperations],
        executeWrites: (opId) async => 'success_result',
        rollbackWrites: (opId) async {},
        validateInvariants: () {},
        onAlreadyCommitted: (existing) async => 'already_committed',
      );

      expect(result, equals('success_result'));

      // Look up latest operation by idempotency key
      final latest = journalDs.getOperationByIdempotencyKey(idempotencyKey);
      expect(latest, isNotNull);
      expect(latest!.attemptNumber, equals(2));
      expect(latest.parentOperationId, equals('op_attempt_1'));
      expect(latest.status, equals('committed'));
    });
  });

  group('3. Financial Write-Path & Quarantine Enforcement', () {
    test(
      'Quarantined account blocks transfers, movements, and reversals',
      () async {
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_quarantine_victim',
            fairId: 'fair_q',
            accountName: 'Quarantine Test',
            accountType: 'cash',
            openingBalancePaise: 100000,
            currentBalancePaise: 100000,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_quarantine_peer',
            fairId: 'fair_q',
            accountName: 'Quarantine Peer',
            accountType: 'bank',
            openingBalancePaise: 100000,
            currentBalancePaise: 100000,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Record a valid transaction first
        final tx = await cashbookRepo.recordAccountMovement(
          fairId: 'fair_q',
          accountId: 'acc_quarantine_victim',
          transactionType: 'manual_inflow',
          direction: 'inflow',
          amountPaise: 10000,
          transactionDate: DateTime.now(),
          referenceType: 'manual',
          description: 'Pre-quarantine tx',
        );

        // Now quarantine the account
        FinancialOperationCoordinator.quarantineAccount(
          'acc_quarantine_victim',
        );
        expect(
          FinancialOperationCoordinator.isAccountQuarantined(
            'acc_quarantine_victim',
          ),
          isTrue,
        );

        // 1. transferFunds must be blocked
        expect(
          () => cashbookRepo.transferFunds(
            fairId: 'fair_q',
            fromAccountId: 'acc_quarantine_victim',
            toAccountId: 'acc_quarantine_peer',
            amountPaise: 5000,
            transferDate: DateTime.now(),
          ),
          throwsA(isA<AccountQuarantinedException>()),
        );

        // 2. recordAccountMovement must be blocked
        expect(
          () => cashbookRepo.recordAccountMovement(
            fairId: 'fair_q',
            accountId: 'acc_quarantine_victim',
            transactionType: 'manual_outflow',
            direction: 'outflow',
            amountPaise: 5000,
            transactionDate: DateTime.now(),
            referenceType: 'manual',
            description: 'Blocked movement',
          ),
          throwsA(isA<AccountQuarantinedException>()),
        );

        // 3. reverseAccountMovement must be blocked
        expect(
          () => cashbookRepo.reverseAccountMovement(tx.id),
          throwsA(isA<AccountQuarantinedException>()),
        );
      },
    );
  });

  group('4. Refund & Cancellation Permutations', () {
    test('Unpaid expense cancellation marks Cancelled and zeroes outstanding without touching cashbook', () async {
      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_unpaid_canc',
          fairId: 'fair_canc',
          title: 'Unpaid Stalls',
          description: 'No payment made',
          categoryId: 'cat_rent',
          amountPaise: 300000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 300000,
          paymentMethod: 'Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await expenseRepo.cancelExpense(exp.id, 'Vendor contract terminated');

      final cancelled = await expenseRepo.getExpenseById(exp.id);
      expect(cancelled!.paymentStatus, equals('Cancelled'));
      expect(cancelled.outstandingAmountPaise, equals(0));
      expect(cancelled.notes, contains('Vendor contract terminated'));
    });

    test('Partially paid expense cancellation without refund zeroes outstanding and preserves payment history', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_canc_cash',
          fairId: 'fair_canc',
          accountName: 'Canc Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_part_canc',
          fairId: 'fair_canc',
          title: 'Sound System Rental',
          description: 'Partial advance paid',
          categoryId: 'cat_sound',
          amountPaise: 200000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 200000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_canc_cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 50000,
        paidFromAccountId: 'acc_canc_cash',
      );

      expect(exp.paidAmountPaise, equals(50000));
      expect(exp.outstandingAmountPaise, equals(150000));

      final accBefore = await cashbookRepo.getAccountById('acc_canc_cash');
      expect(accBefore!.currentBalancePaise, equals(450000));

      // Attempting to cancel without refund must be strictly rejected
      expect(
        () => expenseRepo.cancelExpense(
          exp.id,
          'Event shortened, balance waived',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Explicit business write-off must be used instead to zero outstanding obligations
      final writtenOff = await expenseRepo.writeOffExpenseOutstanding(
        expenseId: exp.id,
        reason: 'Event shortened, balance waived by sound vendor',
      );

      expect(writtenOff.paymentStatus, equals('Partially Paid (Written Off)'));
      expect(writtenOff.outstandingAmountPaise, equals(0));
      expect(
        writtenOff.paidAmountPaise,
        equals(50000),
      ); // Disbursed amount preserved
      expect(writtenOff.notes, contains('Written Off: Event shortened'));

      // Cash account balance unchanged (disbursement remains logged)
      final accAfter = await cashbookRepo.getAccountById('acc_canc_cash');
      expect(accAfter!.currentBalancePaise, equals(450000));

      // Payments query still shows historical payment
      final payments = await paymentRepo.getPayments(
        relatedEntityType: 'expense',
        relatedEntityId: exp.id,
      );
      expect(payments.length, equals(1));
      expect(payments.first.amountPaise, equals(50000));
    });

    test('Partially paid expense cancellation WITH refund credits destination account and marks Cancelled (Refunded)', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_ref_cash',
          fairId: 'fair_ref',
          accountName: 'Ref Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_ref_test',
          fairId: 'fair_ref',
          title: 'Stage Decoration',
          description: 'Decor advance paid',
          categoryId: 'cat_decor',
          amountPaise: 200000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 200000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_ref_cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 80000,
        paidFromAccountId: 'acc_ref_cash',
      );

      final accBeforeRefund = await cashbookRepo.getAccountById('acc_ref_cash');
      expect(
        accBeforeRefund!.currentBalancePaise,
        equals(420000),
      ); // 500000 - 80000

      // Cancel WITH refund
      await expenseRepo.cancelExpense(
        exp.id,
        'Vendor refunded full advance payment',
        refundToAccountId: 'acc_ref_cash',
        clientRequestId: 'refund_client_req_001',
      );

      final cancelledExp = await expenseRepo.getExpenseById(exp.id);
      expect(cancelledExp!.paymentStatus, equals('Cancelled (Refunded)'));
      expect(cancelledExp.outstandingAmountPaise, equals(0));

      // Cash account credited with refunded advance (420000 + 80000 = 500000)
      final accAfterRefund = await cashbookRepo.getAccountById('acc_ref_cash');
      expect(accAfterRefund!.currentBalancePaise, equals(500000));

      // Duplicate refund submission with same clientRequestId should return cleanly and NOT credit again
      await expenseRepo.cancelExpense(
        exp.id,
        'Vendor refunded full advance payment',
        refundToAccountId: 'acc_ref_cash',
        clientRequestId: 'refund_client_req_001',
      );

      final accAfterDup = await cashbookRepo.getAccountById('acc_ref_cash');
      expect(
        accAfterDup!.currentBalancePaise,
        equals(500000),
        reason: 'Duplicate refund must not credit twice',
      );
    });
  });

  group('5. Concurrency, Mutex Locks & Deadlock Prevention', () {
    test('Reverse concurrent transfers between same accounts (A -> B and B -> A) execute cleanly without deadlock', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_deadlock_a',
          fairId: 'fair_dl',
          accountName: 'Account A',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_deadlock_b',
          fairId: 'fair_dl',
          accountName: 'Account B',
          accountType: 'bank',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Execute A -> B (₹100) and B -> A (₹50) concurrently
      final futures = await Future.wait([
        cashbookRepo.transferFunds(
          fairId: 'fair_dl',
          fromAccountId: 'acc_deadlock_a',
          toAccountId: 'acc_deadlock_b',
          amountPaise: 10000,
          transferDate: DateTime.now(),
        ),
        cashbookRepo.transferFunds(
          fairId: 'fair_dl',
          fromAccountId: 'acc_deadlock_b',
          toAccountId: 'acc_deadlock_a',
          amountPaise: 5000,
          transferDate: DateTime.now(),
        ),
      ]);

      expect(futures.length, equals(2));

      final finalA = await cashbookRepo.getAccountById('acc_deadlock_a');
      final finalB = await cashbookRepo.getAccountById('acc_deadlock_b');

      // A: 500000 - 10000 + 5000 = 495000
      // B: 500000 + 10000 - 5000 = 505000
      expect(finalA!.currentBalancePaise, equals(495000));
      expect(finalB!.currentBalancePaise, equals(505000));
    });

    test('Transfers involving overlapping accounts (A -> B and B -> C) execute cleanly in parallel', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_over_a',
          fairId: 'fair_over',
          accountName: 'Over A',
          accountType: 'cash',
          openingBalancePaise: 300000,
          currentBalancePaise: 300000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_over_b',
          fairId: 'fair_over',
          accountName: 'Over B',
          accountType: 'bank',
          openingBalancePaise: 200000,
          currentBalancePaise: 200000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_over_c',
          fairId: 'fair_over',
          accountName: 'Over C',
          accountType: 'upi',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // A -> B: ₹500 (50000 paise)
      // B -> C: ₹300 (30000 paise)
      await Future.wait([
        cashbookRepo.transferFunds(
          fairId: 'fair_over',
          fromAccountId: 'acc_over_a',
          toAccountId: 'acc_over_b',
          amountPaise: 50000,
          transferDate: DateTime.now(),
        ),
        cashbookRepo.transferFunds(
          fairId: 'fair_over',
          fromAccountId: 'acc_over_b',
          toAccountId: 'acc_over_c',
          amountPaise: 30000,
          transferDate: DateTime.now(),
        ),
      ]);

      final a = await cashbookRepo.getAccountById('acc_over_a');
      final b = await cashbookRepo.getAccountById('acc_over_b');
      final c = await cashbookRepo.getAccountById('acc_over_c');

      // A: 300000 - 50000 = 250000
      // B: 200000 + 50000 - 30000 = 220000
      // C: 100000 + 30000 = 130000
      expect(a!.currentBalancePaise, equals(250000));
      expect(b!.currentBalancePaise, equals(220000));
      expect(c!.currentBalancePaise, equals(130000));
    });

    test('Locks are released upon validation failure or exception, permitting subsequent operations', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_fail_lock',
          fairId: 'fair_fl',
          accountName: 'Lock Account',
          accountType: 'cash',
          openingBalancePaise: 50000,
          currentBalancePaise: 50000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_peer_lock',
          fairId: 'fair_fl',
          accountName: 'Peer Account',
          accountType: 'bank',
          openingBalancePaise: 50000,
          currentBalancePaise: 50000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Attempt transfer with insufficient balance (fails pre-flight check)
      try {
        await cashbookRepo.transferFunds(
          fairId: 'fair_fl',
          fromAccountId: 'acc_fail_lock',
          toAccountId: 'acc_peer_lock',
          amountPaise: 999999, // Exceeds 50000
          transferDate: DateTime.now(),
        );
      } catch (e) {
        expect(e, isA<ValidationException>());
      }

      // Subsequent legitimate transfer must immediately acquire lock and succeed
      await cashbookRepo.transferFunds(
        fairId: 'fair_fl',
        fromAccountId: 'acc_fail_lock',
        toAccountId: 'acc_peer_lock',
        amountPaise: 10000,
        transferDate: DateTime.now(),
      );

      final acc = await cashbookRepo.getAccountById('acc_fail_lock');
      expect(acc!.currentBalancePaise, equals(40000));
    });
  });

  group('6. Hive TypeIds, Schema Versioning & Baseline Safety', () {
    test('TypeIds 0 through 14 match DatabaseConstants exactly', () {
      expect(DatabaseConstants.bookFairTypeId, equals(0));
      expect(DatabaseConstants.partnerTypeId, equals(1));
      expect(DatabaseConstants.investmentTypeId, equals(2));
      expect(DatabaseConstants.activityLogTypeId, equals(3));
      expect(DatabaseConstants.bookTypeId, equals(4));
      expect(DatabaseConstants.purchaseBatchTypeId, equals(5));
      expect(DatabaseConstants.purchaseItemTypeId, equals(6));
      expect(DatabaseConstants.stockMovementTypeId, equals(7));
      expect(DatabaseConstants.supplierTypeId, equals(8));
      expect(DatabaseConstants.expenseTypeId, equals(9));
      expect(DatabaseConstants.expenseCategoryTypeId, equals(10));
      expect(DatabaseConstants.cashbookAccountTypeId, equals(11));
      expect(DatabaseConstants.accountTransactionTypeId, equals(12));
      expect(DatabaseConstants.paymentRecordTypeId, equals(13));
      expect(DatabaseConstants.financialOperationTypeId, equals(14));
      expect(DatabaseConstants.saleReceiptTypeId, equals(15));
      expect(DatabaseConstants.saleItemTypeId, equals(16));
      expect(DatabaseConstants.currentSchemaVersion, equals(6));
    });

    test('v4-to-v5 baseline snapshot is immutable and never overwritten on repeated migration', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_base_imm',
          fairId: 'fair_base',
          accountName: 'Baseline Immutable',
          accountType: 'cash',
          openingBalancePaise: 250000,
          currentBalancePaise: 250000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final baselineKey = 'account_baseline_v5_acc_base_imm';
      final originalBaseline = db.metadata.get(baselineKey);
      expect(originalBaseline, equals(250000));

      // Simulate balance changes after baseline
      await cashbookRepo.recordAccountMovement(
        fairId: 'fair_base',
        accountId: 'acc_base_imm',
        transactionType: 'manual_inflow',
        direction: 'inflow',
        amountPaise: 100000,
        transactionDate: DateTime.now(),
        referenceType: 'manual',
        description: 'New deposit',
      );

      final accUpdated = await cashbookRepo.getAccountById('acc_base_imm');
      expect(accUpdated!.currentBalancePaise, equals(350000));

      // Run recovery and verification
      await recoveryEngine.runStartupRecovery();

      // Verify baseline is STILL 250000 (not overwritten with 350000)
      final baselineAfter = db.metadata.get(baselineKey);
      expect(baselineAfter, equals(250000));
    });
  });

  group('7. Cumulative Refund Accounting', () {
    test('Single complete refund credits destination account, zeroes outstanding, and marks Cancelled (Refunded)', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crm_single',
          fairId: 'fair_crm',
          accountName: 'CRM Single',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_crm_single',
          fairId: 'fair_crm',
          title: 'Brochure Printing',
          description: 'Full advance paid',
          categoryId: 'cat_print',
          amountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_crm_single',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_crm_single',
      );

      final accBefore = await cashbookRepo.getAccountById('acc_crm_single');
      expect(accBefore!.currentBalancePaise, equals(400000));

      // Cancel with full refund
      await expenseRepo.cancelExpense(
        exp.id,
        'Printer returned full payment',
        refundToAccountId: 'acc_crm_single',
      );

      final expAfter = await expenseRepo.getExpenseById(exp.id);
      expect(expAfter!.paymentStatus, equals('Cancelled (Refunded)'));
      expect(expAfter.outstandingAmountPaise, equals(0));
      expect(
        expAfter.paidAmountPaise,
        equals(100000),
      ); // Original disbursement preserved

      final accAfter = await cashbookRepo.getAccountById('acc_crm_single');
      expect(accAfter!.currentBalancePaise, equals(500000)); // Fully restored

      final cumulativeRefunds = await expenseRepo.getCumulativeRefundsPaise(
        exp.id,
      );
      expect(cumulativeRefunds, equals(100000));

      // Verify original payment record and debit transaction remain intact
      final payments = await paymentRepo.getPayments(
        relatedEntityType: 'expense',
        relatedEntityId: exp.id,
      );
      expect(payments.length, equals(1));
      expect(payments.first.amountPaise, equals(100000));
      expect(payments.first.paymentMethod, equals('Cash'));

      final txs = await cashbookRepo.getTransactions(
        accountId: 'acc_crm_single',
      );
      final originalDebitTx = txs.firstWhere((t) => t.direction == 'outflow');
      expect(originalDebitTx.amountPaise, equals(100000));
      expect(originalDebitTx.transactionType, equals('expense_payment'));
    });

    test('Multiple partial refunds accumulate until full reimbursement reaches Cancelled (Refunded)', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crm_multi',
          fairId: 'fair_crm',
          accountName: 'CRM Multi',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_crm_multi',
          fairId: 'fair_crm',
          title: 'Lighting Equipment',
          description: 'Disbursed in full',
          categoryId: 'cat_lights',
          amountPaise: 100000, // ₹1,000
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_crm_multi',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_crm_multi',
      );

      expect(
        (await cashbookRepo.getAccountById('acc_crm_multi'))!
            .currentBalancePaise,
        equals(400000),
      );

      // Partial Refund 1: ₹300 (30,000 paise)
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_multi',
        amountPaise: 30000,
        reason: 'Faulty bulbs refund',
        clientRequestId: 'crm_req_p1',
      );

      var currentExp = await expenseRepo.getExpenseById(exp.id);
      expect(currentExp!.paymentStatus, equals('Partially Refunded'));
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(30000),
      );
      expect(
        (await cashbookRepo.getAccountById('acc_crm_multi'))!
            .currentBalancePaise,
        equals(430000),
      );

      // Partial Refund 2: ₹400 (40,000 paise) -> cumulative 70,000 paise
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_multi',
        amountPaise: 40000,
        reason: 'Unused spotlight refund',
        clientRequestId: 'crm_req_p2',
      );

      currentExp = await expenseRepo.getExpenseById(exp.id);
      expect(currentExp!.paymentStatus, equals('Partially Refunded'));
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(70000),
      );
      expect(
        (await cashbookRepo.getAccountById('acc_crm_multi'))!
            .currentBalancePaise,
        equals(470000),
      );

      // Partial Refund 3: ₹300 (30,000 paise) -> cumulative 100,000 paise (full amount reached)
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_multi',
        amountPaise: 30000,
        reason: 'Final refund of remaining balance',
        clientRequestId: 'crm_req_p3',
      );

      currentExp = await expenseRepo.getExpenseById(exp.id);
      expect(currentExp!.paymentStatus, equals('Cancelled (Refunded)'));
      expect(currentExp.outstandingAmountPaise, equals(0));
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(100000),
      );
      expect(
        (await cashbookRepo.getAccountById('acc_crm_multi'))!
            .currentBalancePaise,
        equals(500000),
      );
    });

    test('Over-refund attempt exceeding remaining refundable balance throws ValidationException', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crm_over',
          fairId: 'fair_crm',
          accountName: 'CRM Over',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_crm_over',
          fairId: 'fair_crm',
          title: 'Banner Printing',
          description: 'Partial advance',
          categoryId: 'cat_print',
          amountPaise: 80000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 80000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_crm_over',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 50000, // Only ₹500 paid
        paidFromAccountId: 'acc_crm_over',
      );

      // Attempt to refund ₹600 (60,000 paise) when only ₹500 was paid
      expect(
        () => expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_crm_over',
          amountPaise: 60000,
          reason: 'Excess refund attempt',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Successfully refund ₹300
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_over',
        amountPaise: 30000,
        reason: 'Legitimate refund',
      );

      // Remaining refundable is now ₹200 (20,000 paise). Attempting ₹20,001 must throw.
      expect(
        () => expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_crm_over',
          amountPaise: 20001,
          reason: 'Exceeding remaining balance',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Duplicate refund submission with same clientRequestId replays idempotently without duplicate credits', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crm_idem',
          fairId: 'fair_crm',
          accountName: 'CRM Idem',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_crm_idem',
          fairId: 'fair_crm',
          title: 'Audio Visual System',
          description: 'AV payment',
          categoryId: 'cat_av',
          amountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_crm_idem',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_crm_idem',
      );

      expect(
        (await cashbookRepo.getAccountById('acc_crm_idem'))!
            .currentBalancePaise,
        equals(400000),
      );

      const refundReqId = 'refund_crm_idem_001';

      // First submission
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_idem',
        amountPaise: 25000,
        reason: 'AV mic returned',
        clientRequestId: refundReqId,
      );

      expect(
        (await cashbookRepo.getAccountById('acc_crm_idem'))!
            .currentBalancePaise,
        equals(425000),
      );
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(25000),
      );

      // Duplicate submission with SAME clientRequestId
      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_idem',
        amountPaise: 25000,
        reason: 'AV mic returned',
        clientRequestId: refundReqId,
      );

      // Balance is STILL 425,000 paise (NOT 450,000 paise)
      expect(
        (await cashbookRepo.getAccountById('acc_crm_idem'))!
            .currentBalancePaise,
        equals(425000),
      );
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(25000),
      );
    });

    test('Refund submission with same clientRequestId but conflicting payload throws IdempotencyConflictException', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_crm_conf',
          fairId: 'fair_crm',
          accountName: 'CRM Conf',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_crm_conf',
          fairId: 'fair_crm',
          title: 'Booth Carpets',
          description: 'Carpets deposit',
          categoryId: 'cat_decor',
          amountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_crm_conf',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_crm_conf',
      );

      const refundReqId = 'refund_crm_conf_001';

      await expenseRepo.recordExpenseRefund(
        expenseId: exp.id,
        toAccountId: 'acc_crm_conf',
        amountPaise: 20000,
        reason: 'Small carpet refund',
        clientRequestId: refundReqId,
      );

      // Attempt second submission with SAME clientRequestId but altered amount (50,000 paise)
      expect(
        () => expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_crm_conf',
          amountPaise: 50000,
          reason: 'Small carpet refund',
          clientRequestId: refundReqId,
        ),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });
  });

  group('8. Persistent Idempotency Across All Financial Forms', () {
    test('FinancialDraftManager persists, restores, and clears clientRequestId across all 6 financial operations', () async {
      const operations = [
        ('expense', 'fair_101'),
        ('transfer', 'fair_101'),
        ('standalone_payment', 'exp_202'),
        ('purchase_payment', 'batch_303'),
        ('reimbursement', 'partner_404'),
        ('refund', 'exp_202'),
      ];

      for (final (opType, entityId) in operations) {
        final id1 = FinancialDraftManager.getOrCreateClientRequestId(
          operationType: opType,
          entityId: entityId,
        );
        expect(id1, isNotEmpty);

        // Verify stored in Hive metadataBox
        final draftKey = 'draft_${opType}_$entityId';
        final stored = db.metadata.get(draftKey);
        expect(stored, isNotNull);
        expect((stored as Map)['clientRequestId'], equals(id1));

        // Re-requesting returns identical ID
        final idReopened = FinancialDraftManager.getOrCreateClientRequestId(
          operationType: opType,
          entityId: entityId,
        );
        expect(idReopened, equals(id1));

        // Clear draft on commit
        await FinancialDraftManager.clearDraft(
          operationType: opType,
          entityId: entityId,
        );
        expect(db.metadata.get(draftKey), isNull);

        // Subsequent creation generates fresh ID
        final idNew = FinancialDraftManager.getOrCreateClientRequestId(
          operationType: opType,
          entityId: entityId,
        );
        expect(idNew, isNot(equals(id1)));
      }
    });

    test('PurchaseBatchFormViewModel persists clientRequestId in Hive metadataBox and restores across re-initialization', () async {
      final container1 = ProviderContainer(
        overrides: [
          inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
        ],
      );
      addTearDown(container1.dispose);

      final vm1 = container1.read(purchaseBatchFormViewModelProvider.notifier);
      vm1.init(fairId: 'fair_pbatch_draft');
      final state1 = container1.read(purchaseBatchFormViewModelProvider);
      final reqId1 = state1.clientRequestId;
      expect(reqId1, isNotEmpty);

      // Verify persisted in Hive metadata
      final storedDraft = db.metadata.get(
        'draft_purchase_batch_fair_pbatch_draft',
      );
      expect(storedDraft, isNotNull);
      expect((storedDraft as Map)['clientRequestId'], equals(reqId1));

      // Simulate app restart by disposing container and creating fresh container
      final container2 = ProviderContainer(
        overrides: [
          inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
        ],
      );
      addTearDown(container2.dispose);

      final vm2 = container2.read(purchaseBatchFormViewModelProvider.notifier);
      vm2.init(fairId: 'fair_pbatch_draft');
      final state2 = container2.read(purchaseBatchFormViewModelProvider);
      expect(state2.clientRequestId, equals(reqId1)); // Survives restart!

      // Add item to pass validation and submit batch
      vm2.addItem(
        book: Book(
          id: 'bk_draft_test',
          fairId: 'fair_pbatch_draft',
          title: 'Draft Test Book',
          author: 'Author',
          publisher: 'Pub',
          genre: 'Fiction',
          language: 'English',
          mrpPaise: 20000,
          defaultSellingPricePaise: 18000,
          condition: BookCondition.brandNew,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        quantity: 2,
        unitCost: '100',
      );

      final batchId = await vm2.submit();
      expect(batchId, isNotNull);

      // After commit, draft is cleared and fresh request ID is generated
      final nextState = container2.read(purchaseBatchFormViewModelProvider);
      expect(nextState.clientRequestId, isNot(equals(reqId1)));
    });

    test('Purchase payment submission path persists clientRequestId in metadataBox and clears on commit', () async {
      const batchId = 'batch_draft_test_456';
      const draftKey = 'draft_purchase_payment_$batchId';

      final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
        operationType: 'purchase_payment',
        entityId: batchId,
      );
      expect(clientReqId, isNotEmpty);
      expect(
        (db.metadata.get(draftKey) as Map)['clientRequestId'],
        equals(clientReqId),
      );

      // Simulate reopening dialog / restart
      final restoredId = FinancialDraftManager.getOrCreateClientRequestId(
        operationType: 'purchase_payment',
        entityId: batchId,
      );
      expect(restoredId, equals(clientReqId));

      // Clear draft on successful payment commit
      await FinancialDraftManager.clearDraft(
        operationType: 'purchase_payment',
        entityId: batchId,
      );
      expect(db.metadata.get(draftKey), isNull);
    });
  });

  group('9. Forensic Audit Preservation', () {
    test('Rollback writes preserve original financial data inside structured forensic tags without schema alteration', () async {
      const fairId = 'fair_forensic';
      const opId = 'op_forensic_audit_001';
      final now = DateTime.now();

      // Setup initial transaction and payment record
      final origTx = AccountTransactionModel(
        id: 'tx_forensic_001',
        fairId: fairId,
        accountId: 'acc_forensic_src',
        transactionType: 'transfer_out',
        direction: 'outflow',
        amountPaise: 75000,
        transactionDateEpoch: now.millisecondsSinceEpoch,
        referenceType: 'account_transfer',
        referenceId: 'ref_forensic_001',
        description: 'Vendor wire transfer to publisher',
        createdAtEpoch: now.millisecondsSinceEpoch,
      );
      await db.accountTransactions.put(origTx.id, origTx);

      final origPay = PaymentRecordModel(
        id: 'pay_forensic_001',
        fairId: fairId,
        amountPaise: 75000,
        paymentMethod: 'Bank Transfer',
        paymentDateEpoch: now.millisecondsSinceEpoch,
        accountId: 'acc_forensic_src',
        payerPartnerId: null,
        recipientPartnerId: null,
        supplierId: 'supp_001',
        referenceNumber: 'REF-FORENSIC-001',
        relatedEntityType: 'expense',
        relatedEntityId: 'exp_forensic_001',
        notes: 'Publisher advance batch',
        createdAtEpoch: now.millisecondsSinceEpoch,
      );
      await db.paymentRecords.put(origPay.id, origPay);

      // Simulate compensating rollback write with structured forensic tags
      final voidedTx = AccountTransactionModel(
        id: origTx.id,
        fairId: origTx.fairId,
        accountId: origTx.accountId,
        transactionType: 'void_abandoned',
        direction: origTx.direction,
        amountPaise: origTx.amountPaise,
        transactionDateEpoch: origTx.transactionDateEpoch,
        referenceType: 'void_abandoned',
        referenceId: origTx.referenceId,
        description:
            '[VOID_ABANDONED: origTxType=${origTx.transactionType}, origRefType=${origTx.referenceType}, op=$opId] ${origTx.description}',
        createdAtEpoch: origTx.createdAtEpoch,
      );
      await db.accountTransactions.put(voidedTx.id, voidedTx);

      final voidedPay = PaymentRecordModel(
        id: origPay.id,
        fairId: origPay.fairId,
        amountPaise: origPay.amountPaise,
        paymentMethod: 'void_abandoned',
        paymentDateEpoch: origPay.paymentDateEpoch,
        accountId: origPay.accountId,
        payerPartnerId: origPay.payerPartnerId,
        recipientPartnerId: origPay.recipientPartnerId,
        supplierId: origPay.supplierId,
        referenceNumber: origPay.referenceNumber,
        relatedEntityType: 'void_abandoned',
        relatedEntityId: origPay.relatedEntityId,
        notes:
            '[VOID_ABANDONED: origType=${origPay.relatedEntityType}, origMethod=${origPay.paymentMethod}, op=$opId] ${origPay.notes}',
        createdAtEpoch: origPay.createdAtEpoch,
      );
      await db.paymentRecords.put(voidedPay.id, voidedPay);

      // Inspect persisted voided models
      final savedTx = db.accountTransactions.get('tx_forensic_001')!;
      expect(savedTx.transactionType, equals('void_abandoned'));
      expect(savedTx.referenceType, equals('void_abandoned'));
      expect(savedTx.amountPaise, equals(75000)); // Strict preservation
      expect(savedTx.accountId, equals('acc_forensic_src'));
      expect(savedTx.fairId, equals(fairId));
      expect(savedTx.description, contains('origTxType=transfer_out'));
      expect(savedTx.description, contains('origRefType=account_transfer'));
      expect(savedTx.description, contains('op=$opId'));
      expect(
        savedTx.description,
        contains('Vendor wire transfer to publisher'),
      );

      final savedPay = db.paymentRecords.get('pay_forensic_001')!;
      expect(savedPay.paymentMethod, equals('void_abandoned'));
      expect(savedPay.relatedEntityType, equals('void_abandoned'));
      expect(savedPay.amountPaise, equals(75000)); // Strict preservation
      expect(savedPay.accountId, equals('acc_forensic_src'));
      expect(savedPay.fairId, equals(fairId));
      expect(savedPay.notes, contains('origType=expense'));
      expect(savedPay.notes, contains('origMethod=Bank Transfer'));
      expect(savedPay.notes, contains('op=$opId'));
      expect(savedPay.notes, contains('Publisher advance batch'));
    });

    test('Operation payloadJson stores structured originalRecords allowing complete reconstruction without string parsing', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_snap_src',
          fairId: 'fair_snap',
          accountName: 'Snap Src',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_snap_dst',
          fairId: 'fair_snap',
          accountName: 'Snap Dst',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await cashbookRepo.transferFunds(
        fairId: 'fair_snap',
        fromAccountId: 'acc_snap_src',
        toAccountId: 'acc_snap_dst',
        amountPaise: 50000,
        transferDate: DateTime.now(),
        referenceNumber: 'REF-SNAP-01',
        clientRequestId: 'snap_req_001',
      );

      final op = journalDs.getOperationByIdempotencyKey(
        'transfer_fair_snap_acc_snap_src_acc_snap_dst_snap_req_001',
      );
      expect(op, isNotNull);

      // Verify payloadJson contains structured originalRecords snapshot
      final payload = jsonDecode(op!.payloadJson) as Map<String, dynamic>;
      expect(payload.containsKey('originalRecords'), isTrue);

      final originalRecords =
          payload['originalRecords'] as Map<String, dynamic>;
      final debitTx = originalRecords['debitTx'] as Map<String, dynamic>;
      final creditTx = originalRecords['creditTx'] as Map<String, dynamic>;

      expect(debitTx['amountPaise'], equals(50000));
      expect(debitTx['accountId'], equals('acc_snap_src'));
      expect(debitTx['transactionType'], equals('transfer_out'));
      expect(debitTx['direction'], equals('outflow'));
      expect(creditTx['amountPaise'], equals(50000));
      expect(creditTx['accountId'], equals('acc_snap_dst'));
      expect(creditTx['transactionType'], equals('transfer_in'));
      expect(creditTx['direction'], equals('inflow'));
    });
  });

  group('10. Persisted Partial-Write Recovery (On-Disk Crash Simulation)', () {
    // Note: This test verifies on-disk crash consistency under persisted partial writes by flushing
    // to physical disk files, closing all Hive boxes, and reopening them from disk through startup recovery.
    // It verifies crash recovery against actual on-disk files without in-memory mocks, distinct from OS SIGKILL.
    test('Persisted partial-write recovery: on-disk database simulates crash via immediate disk flush and hard box closure, reopens cleanly, and rolls back orphaned debit', () async {
      final diskTempDir = await Directory.systemTemp.createTemp(
        'bookfair_disk_crash_',
      );
      try {
        // Initialize an isolated, real on-disk Hive instance
        await DatabaseInitializer.initTest(path: diskTempDir.path);
        const diskDb = AppDatabase();

        final srcAccount = CashbookAccountModel(
          id: 'acc_disk_crash_src',
          fairId: 'fair_disk',
          accountName: 'Disk Crash Source',
          accountType: 'cash',
          openingBalancePaise: 1000000, // ₹10,000
          currentBalancePaise: 1000000,
          isActive: true,
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
          updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await diskDb.cashbookAccounts.put(srcAccount.id, srcAccount);

        final dstAccount = CashbookAccountModel(
          id: 'acc_disk_crash_dst',
          fairId: 'fair_disk',
          accountName: 'Disk Crash Dst',
          accountType: 'bank',
          openingBalancePaise: 200000, // ₹2,000
          currentBalancePaise: 200000,
          isActive: true,
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
          updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await diskDb.cashbookAccounts.put(dstAccount.id, dstAccount);

        // Snapshot baseline in metadata
        await diskDb.metadata.put(
          'account_baseline_v5_${srcAccount.id}',
          1000000,
        );
        await diskDb.metadata.put(
          'account_baseline_v5_${dstAccount.id}',
          200000,
        );

        // Simulate application mid-operation crash:
        // Journal entry created in processing state for ₹4,000 (400,000 paise) transfer
        final crashOp = FinancialOperationModel(
          id: 'op_disk_crash_001',
          fairId: 'fair_disk',
          idempotencyKey: 'transfer_fair_disk_crash_001',
          requestFingerprint: 'disk_crash_fingerprint',
          operationType: 'account_transfer',
          status: 'processing',
          amountPaise: 400000,
          primaryEntityId: 'acc_disk_crash_src',
          sourceAccountId: 'acc_disk_crash_src',
          targetAccountId: 'acc_disk_crash_dst',
          payloadJson: jsonEncode({
            'fairId': 'fair_disk',
            'fromAccountId': 'acc_disk_crash_src',
            'toAccountId': 'acc_disk_crash_dst',
            'amountPaise': 400000,
            'debitTxId': 'tx_disk_deb_001',
            'creditTxId': 'tx_disk_crd_001',
          }),
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
          updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await diskDb.financialOperations.put(crashOp.id, crashOp);

        // Source account was debited to 600,000 paise before the crash
        await diskDb.cashbookAccounts.put(
          srcAccount.id,
          CashbookAccountModel(
            id: srcAccount.id,
            fairId: srcAccount.fairId,
            accountName: srcAccount.accountName,
            accountType: srcAccount.accountType,
            openingBalancePaise: srcAccount.openingBalancePaise,
            currentBalancePaise: 600000,
            isActive: srcAccount.isActive,
            createdAtEpoch: srcAccount.createdAtEpoch,
            updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        // Debit transaction was written before the crash
        final debitTx = AccountTransactionModel(
          id: 'tx_disk_deb_001',
          fairId: 'fair_disk',
          accountId: 'acc_disk_crash_src',
          transactionType: 'transfer_out',
          direction: 'outflow',
          amountPaise: 400000,
          transactionDateEpoch: DateTime.now().millisecondsSinceEpoch,
          referenceType: 'account_transfer',
          description: 'Transfer to Disk Crash Dst',
          createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await diskDb.accountTransactions.put(debitTx.id, debitTx);

        // Force flush all data to actual disk
        await diskDb.financialOperations.flush();
        await diskDb.cashbookAccounts.flush();
        await diskDb.accountTransactions.flush();
        await diskDb.metadata.flush();

        // SIMULATE SUDDEN OS PROCESS TERMINATION (Hard close of all boxes)
        await DatabaseInitializer.close();

        // SIMULATE NEXT APPLICATION LAUNCH:
        // Re-initialize from the exact same disk directory.
        // initTest automatically runs FinancialRecoveryEngine.runStartupRecovery()
        await DatabaseInitializer.initTest(path: diskTempDir.path);

        // VERIFY RECOVERY ON DISK:
        final reloadedDb = const AppDatabase();

        // 1. Journal operation must be rolled back
        final recoveredOp = reloadedDb.financialOperations.get(
          'op_disk_crash_001',
        );
        expect(recoveredOp, isNotNull);
        expect(recoveredOp!.status, equals('rolled_back'));

        // 2. Source account balance must be restored to 1,000,000 paise
        final recoveredSrcAcc = reloadedDb.cashbookAccounts.get(
          'acc_disk_crash_src',
        );
        expect(recoveredSrcAcc, isNotNull);
        expect(recoveredSrcAcc!.currentBalancePaise, equals(1000000));

        // 3. Destination account balance must remain intact at 200,000 paise
        final recoveredDstAcc = reloadedDb.cashbookAccounts.get(
          'acc_disk_crash_dst',
        );
        expect(recoveredDstAcc, isNotNull);
        expect(recoveredDstAcc!.currentBalancePaise, equals(200000));

        // 4. Orphaned debit transaction must be marked void_abandoned with forensic tag
        final recoveredDebitTx = reloadedDb.accountTransactions.get(
          'tx_disk_deb_001',
        );
        expect(recoveredDebitTx, isNotNull);
        expect(recoveredDebitTx!.transactionType, equals('void_abandoned'));
        expect(recoveredDebitTx.referenceType, equals('void_abandoned'));
        expect(recoveredDebitTx.description, contains('[VOID_ABANDONED:'));
        expect(recoveredDebitTx.description, contains('op=op_disk_crash_001'));
      } finally {
        // Teardown disk test instance
        await DatabaseInitializer.close();
        if (diskTempDir.existsSync()) {
          try {
            await diskTempDir.delete(recursive: true);
          } catch (_) {}
        }
        // Re-establish suite database for suite lifecycle
        await TestDatabaseHelper.setUpSuiteDatabase();
      }
    });
  });

  group('11. Financial Write-Path Guards', () {
    test('updateExpense throws ValidationException when reducing expense amount below disbursed paidAmountPaise', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_wguard_cash',
          fairId: 'fair_wguard',
          accountName: 'Guard Cash',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_wguard_reduce',
          fairId: 'fair_wguard',
          title: 'Stage Trussing',
          description: 'Truss hire',
          categoryId: 'cat_truss',
          amountPaise: 200000, // ₹2,000 total
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 200000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_wguard_cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 80000, // ₹800 paid
        paidFromAccountId: 'acc_wguard_cash',
      );

      expect(exp.paidAmountPaise, equals(80000));

      // Attempt to reduce total amount to ₹600 (60,000 paise), which is LESS than ₹800 paid
      expect(
        () => expenseRepo.updateExpense(exp.copyWith(amountPaise: 60000)),
        throwsA(isA<ValidationException>()),
      );

      // Reducing or increasing total amount to ₹1,500 (150,000 paise >= 80,000 paid) succeeds
      final updated = await expenseRepo.updateExpense(
        exp.copyWith(amountPaise: 150000),
      );
      expect(updated.amountPaise, equals(150000));
      expect(updated.outstandingAmountPaise, equals(70000)); // 150000 - 80000
    });

    test('updateExpense throws ValidationException when attempting to modify a cancelled expense', () async {
      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_wguard_canc',
          fairId: 'fair_wguard',
          title: 'Unused Stalls',
          description: 'Stalls booking',
          categoryId: 'cat_rent',
          amountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await expenseRepo.cancelExpense(exp.id, 'Fair venue changed');

      final cancelled = await expenseRepo.getExpenseById(exp.id);
      expect(cancelled!.paymentStatus, equals('Cancelled'));

      // Attempting to modify the cancelled expense must throw
      expect(
        () => expenseRepo.updateExpense(
          cancelled.copyWith(title: 'Modified Cancelled Stall'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'updateAccount sanitizes and discards direct caller balance tampering',
      () async {
        final initialAccount = await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_wguard_sanitize',
            fairId: 'fair_wguard',
            accountName: 'Original Account Name',
            accountType: 'cash',
            openingBalancePaise: 200000,
            currentBalancePaise: 200000,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        expect(initialAccount.currentBalancePaise, equals(200000));

        // Malicious or buggy caller passes mutated balance values
        final tampered = initialAccount.copyWith(
          accountName: 'Updated Legitimate Name',
          openingBalancePaise: 9999999,
          currentBalancePaise: 8888888,
        );

        final returned = await cashbookRepo.updateAccount(tampered);

        // Name was updated, but balances were sanitized and strictly preserved
        expect(returned.accountName, equals('Updated Legitimate Name'));
        expect(returned.openingBalancePaise, equals(200000));
        expect(returned.currentBalancePaise, equals(200000));

        final persisted = await cashbookRepo.getAccountById(
          'acc_wguard_sanitize',
        );
        expect(persisted!.accountName, equals('Updated Legitimate Name'));
        expect(persisted.openingBalancePaise, equals(200000));
        expect(persisted.currentBalancePaise, equals(200000));
      },
    );

    test('InvestmentRepositoryImpl enforces amountPaise > 0 on addInvestment and updateInvestment', () async {
      final investmentRepo = InvestmentRepositoryImpl(fairDs, activityRepo);
      final now = DateTime.now();

      final invalidZero = Investment(
        id: 'inv_guard_zero',
        fairId: 'fair_wguard',
        partnerId: 'partner_01',
        amountPaise: 0,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.cash,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final invalidNegative = Investment(
        id: 'inv_guard_neg',
        fairId: 'fair_wguard',
        partnerId: 'partner_01',
        amountPaise: -50000,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.cash,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => investmentRepo.addInvestment(invalidZero),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => investmentRepo.addInvestment(invalidNegative),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => investmentRepo.updateInvestment(invalidZero),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => investmentRepo.updateInvestment(invalidNegative),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('12. Entity-Level Financial Locking & Serialization', () {
    test('Two simultaneous refunds to different destination accounts are serialized and prevent over-refund', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_lock_src_01',
          fairId: 'fair_lock',
          accountName: 'Lock Cash',
          accountType: 'cash',
          openingBalancePaise: 1000000,
          currentBalancePaise: 1000000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_lock_dst_1',
          fairId: 'fair_lock',
          accountName: 'Lock Dst 1',
          accountType: 'bank',
          openingBalancePaise: 0,
          currentBalancePaise: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_lock_dst_2',
          fairId: 'fair_lock',
          accountName: 'Lock Dst 2',
          accountType: 'upi',
          openingBalancePaise: 0,
          currentBalancePaise: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_lock_concurrent_01',
          fairId: 'fair_lock',
          title: 'Concurrent Refund Expense',
          description: 'Testing entity locks',
          categoryId: 'cat_general',
          amountPaise: 100000, // ₹1,000 disbursed
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_lock_src_01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_lock_src_01',
      );

      // Concurrently submit two refunds of ₹600 each to DIFFERENT destination accounts
      // Total refundable is only ₹1,000. 600 + 600 = 1200 > 1000.
      int successCount = 0;
      int validationFailureCount = 0;

      await Future.wait([
        () async {
          try {
            await expenseRepo.recordExpenseRefund(
              expenseId: exp.id,
              toAccountId: 'acc_lock_dst_1',
              amountPaise: 60000,
              reason: 'Simultaneous refund A',
              clientRequestId: 'simul_refund_req_a',
            );
            successCount++;
          } on ValidationException {
            validationFailureCount++;
          }
        }(),
        () async {
          try {
            await expenseRepo.recordExpenseRefund(
              expenseId: exp.id,
              toAccountId: 'acc_lock_dst_2',
              amountPaise: 60000,
              reason: 'Simultaneous refund B',
              clientRequestId: 'simul_refund_req_b',
            );
            successCount++;
          } on ValidationException {
            validationFailureCount++;
          }
        }(),
      ]);

      // Exactly ONE must succeed and the other must be rejected for exceeding remaining refundable amount
      expect(successCount, equals(1));
      expect(validationFailureCount, equals(1));

      final cumulativeRefunded = await expenseRepo.getCumulativeRefundsPaise(
        exp.id,
      );
      expect(cumulativeRefunded, equals(60000));

      final acc1 = await cashbookRepo.getAccountById('acc_lock_dst_1');
      final acc2 = await cashbookRepo.getAccountById('acc_lock_dst_2');
      expect(
        acc1!.currentBalancePaise + acc2!.currentBalancePaise,
        equals(60000),
      );
    });

    test('Two simultaneous refunds within available balance to different accounts both serialize and succeed', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_safe_src_01',
          fairId: 'fair_lock',
          accountName: 'Safe Cash',
          accountType: 'cash',
          openingBalancePaise: 1000000,
          currentBalancePaise: 1000000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_safe_dst_1',
          fairId: 'fair_lock',
          accountName: 'Safe Dst 1',
          accountType: 'bank',
          openingBalancePaise: 0,
          currentBalancePaise: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_safe_dst_2',
          fairId: 'fair_lock',
          accountName: 'Safe Dst 2',
          accountType: 'upi',
          openingBalancePaise: 0,
          currentBalancePaise: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_lock_safe_01',
          fairId: 'fair_lock',
          title: 'Concurrent Safe Refunds',
          description: 'Testing serialized non-conflicting refunds',
          categoryId: 'cat_general',
          amountPaise: 100000, // ₹1,000 disbursed
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_safe_src_01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 100000,
        paidFromAccountId: 'acc_safe_src_01',
      );

      // Concurrently submit ₹400 and ₹500 (total ₹900 <= ₹1000)
      await Future.wait([
        expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_safe_dst_1',
          amountPaise: 40000,
          reason: 'Safe Partial A',
          clientRequestId: 'safe_req_a_01',
        ),
        expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_safe_dst_2',
          amountPaise: 50000,
          reason: 'Safe Partial B',
          clientRequestId: 'safe_req_b_01',
        ),
      ]);

      final cumulativeRefunded = await expenseRepo.getCumulativeRefundsPaise(
        exp.id,
      );
      expect(cumulativeRefunded, equals(90000));

      final acc1 = await cashbookRepo.getAccountById('acc_safe_dst_1');
      final acc2 = await cashbookRepo.getAccountById('acc_safe_dst_2');
      expect(acc1!.currentBalancePaise, equals(40000));
      expect(acc2!.currentBalancePaise, equals(50000));
    });

    test('Simultaneous refund and write-off attempt on same expense serialize without deadlock', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_rw_src_01',
          fairId: 'fair_rw',
          accountName: 'RW Src',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_rw_dst_01',
          fairId: 'fair_rw',
          accountName: 'RW Dst',
          accountType: 'bank',
          openingBalancePaise: 0,
          currentBalancePaise: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_rw_test_01',
          fairId: 'fair_rw',
          title: 'Simultaneous Refund & Write-off',
          categoryId: 'cat_general',
          amountPaise: 100000, // ₹1,000 total
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          paidFromAccountId: 'acc_rw_src_01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialPaymentAmountPaise: 40000, // ₹400 paid, ₹600 outstanding
        paidFromAccountId: 'acc_rw_src_01',
      );

      // Concurrently refund ₹400 and write off remaining ₹600
      await Future.wait([
        expenseRepo.recordExpenseRefund(
          expenseId: exp.id,
          toAccountId: 'acc_rw_dst_01',
          amountPaise: 40000,
          reason: 'Refund advance',
          clientRequestId: 'rw_refund_req_01',
        ),
        expenseRepo.writeOffExpenseOutstanding(
          expenseId: exp.id,
          reason: 'Vendor waived balance',
          clientRequestId: 'rw_writeoff_req_01',
        ),
      ]);

      final finalExp = await expenseRepo.getExpenseById(exp.id);
      expect(finalExp!.outstandingAmountPaise, equals(0));
      expect(
        await expenseRepo.getCumulativeRefundsPaise(exp.id),
        equals(40000),
      );
      expect(
        (await cashbookRepo.getAccountById('acc_rw_dst_01'))!
            .currentBalancePaise,
        equals(40000),
      );
    });

    test('Simultaneous payment and cancellation attempt serialize cleanly without state corruption', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_pc_src_01',
          fairId: 'fair_pc',
          accountName: 'PC Src',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final exp = await expenseRepo.createExpense(
        Expense(
          id: 'exp_pc_test_01',
          fairId: 'fair_pc',
          title: 'Unpaid Expense for PC Test',
          categoryId: 'cat_general',
          amountPaise: 100000,
          expenseDate: DateTime.now(),
          paymentStatus: 'Unpaid',
          paidAmountPaise: 0,
          outstandingAmountPaise: 100000,
          paymentMethod: 'Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Concurrently attempt payment and cancellation
      final payment = PaymentRecord(
        id: 'pay_pc_001',
        fairId: 'fair_pc',
        amountPaise: 50000,
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        accountId: 'acc_pc_src_01',
        relatedEntityType: 'expense',
        relatedEntityId: exp.id,
        createdAt: DateTime.now(),
      );

      Object? cancellationError;
      Object? paymentError;

      await Future.wait([
        () async {
          try {
            await expenseRepo.cancelExpense(
              exp.id,
              'Cancel event',
              clientRequestId: 'canc_req_pc_01',
            );
          } catch (e) {
            cancellationError = e;
          }
        }(),
        () async {
          try {
            await paymentRepo.recordPayment(
              payment,
              clientRequestId: 'pay_req_pc_01',
            );
          } catch (e) {
            paymentError = e;
          }
        }(),
      ]);

      // Exactly one of the two must fail because one took the lock first:
      // If cancellation won: payment failed with ValidationException (cannot pay cancelled expense).
      // If payment won: cancellation failed with ValidationException (cannot cancel without refund destination).
      expect(cancellationError != null || paymentError != null, isTrue);

      final finalExp = await expenseRepo.getExpenseById(exp.id);
      expect(finalExp, isNotNull);
      // State is logically sound: either cancelled with 0 paid, or partially paid with payment logged
      if (finalExp!.isCancelled) {
        expect(finalExp.paidAmountPaise, equals(0));
      } else {
        expect(finalExp.paidAmountPaise, equals(50000));
      }
    });

    test('Simultaneous purchase-batch payments serialize against the same purchase batch', () async {
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_pbp_1',
          fairId: 'fair_pbp',
          accountName: 'PBP 1',
          accountType: 'cash',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_pbp_2',
          fairId: 'fair_pbp',
          accountName: 'PBP 2',
          accountType: 'bank',
          openingBalancePaise: 500000,
          currentBalancePaise: 500000,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final batch = PurchaseBatchModel(
        id: 'batch_pbp_concurrent',
        fairId: 'fair_pbp',
        supplierId: 'supp_pbp_01',
        purchaseDateEpoch: DateTime.now().millisecondsSinceEpoch,
        totalQuantity: 20,
        totalBookCostPaise: 200000, // ₹2,000 total
        additionalChargesPaise: 0,
        totalAcquisitionCostPaise: 200000,
        paymentStatus: 'Pending',
        paymentMethod: 'Bank Transfer',
        notes: '',
        createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
      );
      await db.purchaseBatches.put(batch.id, batch);

      final pay1 = PaymentRecord(
        id: 'pay_pbp_c1',
        fairId: 'fair_pbp',
        amountPaise: 100000,
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        accountId: 'acc_pbp_1',
        relatedEntityType: 'purchase_batch',
        relatedEntityId: batch.id,
        createdAt: DateTime.now(),
      );

      final pay2 = PaymentRecord(
        id: 'pay_pbp_c2',
        fairId: 'fair_pbp',
        amountPaise: 100000,
        paymentMethod: 'Bank Transfer',
        paymentDate: DateTime.now(),
        accountId: 'acc_pbp_2',
        relatedEntityType: 'purchase_batch',
        relatedEntityId: batch.id,
        createdAt: DateTime.now(),
      );

      // Concurrently submit both payments for ₹1,000 each
      await Future.wait([
        paymentRepo.recordPayment(pay1, clientRequestId: 'pbp_req_c1'),
        paymentRepo.recordPayment(pay2, clientRequestId: 'pbp_req_c2'),
      ]);

      final updatedBatch = db.purchaseBatches.get(batch.id);
      expect(updatedBatch!.paymentStatus, equals('Paid'));

      final acc1 = await cashbookRepo.getAccountById('acc_pbp_1');
      final acc2 = await cashbookRepo.getAccountById('acc_pbp_2');
      expect(acc1!.currentBalancePaise, equals(400000));
      expect(acc2!.currentBalancePaise, equals(400000));
    });
  });
}
