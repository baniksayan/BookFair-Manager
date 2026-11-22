import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';

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

  group('CashbookRepositoryImpl Tests', () {
    const fairId = 'fair_kolkata_2026';

    test('createAccount creates account and opening balance transaction when balance > 0', () async {
      final now = DateTime.now();
      final account = CashbookAccount(
        id: 'acc_cashbox',
        fairId: fairId,
        accountName: 'Main Cashbox',
        accountType: 'cash',
        openingBalancePaise: 1000000, // ₹10,000
        currentBalancePaise: 1000000,
        createdAt: now,
        updatedAt: now,
      );

      final created = await cashbookRepo.createAccount(account);
      expect(created.id, 'acc_cashbox');
      expect(created.currentBalancePaise, 1000000);

      final txs = await cashbookRepo.getTransactions(accountId: 'acc_cashbox');
      expect(txs.length, 1);
      expect(txs.first.transactionType, 'opening_balance');
      expect(txs.first.amountPaise, 1000000);
      expect(txs.first.isInflow, isTrue);
    });

    test(
      'ensureDefaultAccounts seeds 3 standard accounts on empty fair',
      () async {
        final accounts = await cashbookRepo.ensureDefaultAccounts(fairId);
        expect(accounts.length, 3);
        expect(
          accounts.map((a) => a.accountType),
          containsAll(['cash', 'upi', 'bank']),
        );

        final existingAgain = await cashbookRepo.ensureDefaultAccounts(fairId);
        expect(existingAgain.length, 3);
        expect(
          existingAgain.map((a) => a.id),
          containsAll(accounts.map((a) => a.id)),
        );
      },
    );

    test(
      'recordAccountMovement updates balance accurately for inflow and outflow',
      () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_upi',
            fairId: fairId,
            accountName: 'Stall UPI',
            accountType: 'upi',
            openingBalancePaise: 500000, // ₹5,000
            currentBalancePaise: 500000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Inflow
        await cashbookRepo.recordAccountMovement(
          fairId: fairId,
          accountId: 'acc_upi',
          transactionType: 'deposit',
          direction: 'inflow',
          amountPaise: 200000, // +₹2,000
          transactionDate: now,
          referenceType: 'manual',
          description: 'UPI direct collection',
        );

        var acc = await cashbookRepo.getAccountById('acc_upi');
        expect(acc?.currentBalancePaise, 700000); // ₹7,000

        // Outflow
        await cashbookRepo.recordAccountMovement(
          fairId: fairId,
          accountId: 'acc_upi',
          transactionType: 'withdrawal',
          direction: 'outflow',
          amountPaise: 150000, // -₹1,500
          transactionDate: now,
          referenceType: 'manual',
          description: 'Tea & snacks payment',
        );

        acc = await cashbookRepo.getAccountById('acc_upi');
        expect(acc?.currentBalancePaise, 550000); // ₹5,500
      },
    );

    test(
      'transferFunds rejects non-positive amounts or identical accounts',
      () async {
        expect(
          () => cashbookRepo.transferFunds(
            fairId: fairId,
            fromAccountId: 'acc1',
            toAccountId: 'acc1',
            amountPaise: 1000,
            transferDate: DateTime.now(),
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(
          () => cashbookRepo.transferFunds(
            fairId: fairId,
            fromAccountId: 'acc1',
            toAccountId: 'acc2',
            amountPaise: 0,
            transferDate: DateTime.now(),
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'transferFunds rejects when source account has insufficient balance',
      () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_cash',
            fairId: fairId,
            accountName: 'Cash',
            accountType: 'cash',
            openingBalancePaise: 100000, // ₹1,000
            currentBalancePaise: 100000,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_bank',
            fairId: fairId,
            accountName: 'Bank',
            accountType: 'bank',
            openingBalancePaise: 0,
            currentBalancePaise: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(
          () => cashbookRepo.transferFunds(
            fairId: fairId,
            fromAccountId: 'acc_cash',
            toAccountId: 'acc_bank',
            amountPaise: 200000, // ₹2,000 > ₹1,000
            transferDate: now,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('transferFunds atomically updates balances and records matching ledger entries', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash',
          fairId: fairId,
          accountName: 'Main Cashbox',
          accountType: 'cash',
          openingBalancePaise: 1000000, // ₹10,000
          currentBalancePaise: 1000000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_bank',
          fairId: fairId,
          accountName: 'HDFC Current Bank',
          accountType: 'bank',
          openingBalancePaise: 500000, // ₹5,000
          currentBalancePaise: 500000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Transfer ₹4,000 from Cashbox to Bank
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_cash',
        toAccountId: 'acc_bank',
        amountPaise: 400000,
        transferDate: now,
        referenceNumber: 'DEP-2026-01',
        notes: 'Cash deposit to branch',
      );

      final updatedCash = await cashbookRepo.getAccountById('acc_cash');
      final updatedBank = await cashbookRepo.getAccountById('acc_bank');

      expect(
        updatedCash?.currentBalancePaise,
        600000,
      ); // 10,000 - 4,000 = 6,000
      expect(updatedBank?.currentBalancePaise, 900000); // 5,000 + 4,000 = 9,000

      // Total liquid funds invariant preserved: 10,000 + 5,000 == 6,000 + 9,000 == 15,000
      expect(
        (updatedCash!.currentBalancePaise + updatedBank!.currentBalancePaise),
        1500000,
      );

      // Verify transaction records
      final cashTxs = await cashbookRepo.getTransactions(accountId: 'acc_cash');
      final bankTxs = await cashbookRepo.getTransactions(accountId: 'acc_bank');

      final transferOut = cashTxs.firstWhere(
        (tx) => tx.transactionType == 'transfer_out',
      );
      final transferIn = bankTxs.firstWhere(
        (tx) => tx.transactionType == 'transfer_in',
      );

      expect(transferOut.amountPaise, 400000);
      expect(transferOut.isOutflow, isTrue);
      expect(transferIn.amountPaise, 400000);
      expect(transferIn.isInflow, isTrue);
      expect(
        transferOut.referenceId,
        transferIn.referenceId,
      ); // Shared transfer UUID
    });

    test(
      'recordAccountMovement enforces overdraft protection on outflows',
      () async {
        final now = DateTime.now();
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_petty',
            fairId: fairId,
            accountName: 'Petty Cash',
            accountType: 'cash',
            openingBalancePaise: 50000, // ₹500
            currentBalancePaise: 50000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Attempt outflow of ₹1,000 (exceeds ₹500)
        expect(
          () => cashbookRepo.recordAccountMovement(
            fairId: fairId,
            accountId: 'acc_petty',
            transactionType: 'withdrawal',
            direction: 'outflow',
            amountPaise: 100000, // ₹1,000 > ₹500
            transactionDate: now,
            referenceType: 'manual',
            description: 'Excess withdrawal',
          ),
          throwsA(isA<ValidationException>()),
        );

        // Verify account balance was NOT modified
        final acc = await cashbookRepo.getAccountById('acc_petty');
        expect(acc?.currentBalancePaise, 50000);

        // Verify no transaction record was persisted
        final txs = await cashbookRepo.getTransactions(accountId: 'acc_petty');
        expect(
          txs.where((t) => t.transactionType == 'withdrawal').isEmpty,
          isTrue,
        );
      },
    );

    test('recordAccountMovement rejects operations on inactive accounts or non-positive amounts', () async {
      final now = DateTime.now();
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_closed',
          fairId: fairId,
          accountName: 'Closed Bank',
          accountType: 'bank',
          openingBalancePaise: 100000,
          currentBalancePaise: 100000,
          isActive: false, // Inactive
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Inactive account
      expect(
        () => cashbookRepo.recordAccountMovement(
          fairId: fairId,
          accountId: 'acc_closed',
          transactionType: 'deposit',
          direction: 'inflow',
          amountPaise: 50000,
          transactionDate: now,
          referenceType: 'manual',
          description: 'Deposit to inactive',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Non-positive amount
      expect(
        () => cashbookRepo.recordAccountMovement(
          fairId: fairId,
          accountId: 'acc_closed',
          transactionType: 'deposit',
          direction: 'inflow',
          amountPaise: 0,
          transactionDate: now,
          referenceType: 'manual',
          description: 'Zero amount',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
