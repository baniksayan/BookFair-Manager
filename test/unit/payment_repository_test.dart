import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/models/expense_model.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/inventory/data/models/purchase_batch_model.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_batch.dart';
import 'package:bookfair_manager/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:bookfair_manager/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:bookfair_manager/features/payments/domain/entities/payment_record.dart';

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

  group('PaymentRepositoryImpl Tests', () {
    const fairId = 'fair_kolkata_2026';

    test('recordPayment throws ValidationException when amount is zero or negative', () async {
      final invalidPayment = PaymentRecord(
        id: 'pay_invalid',
        fairId: fairId,
        amountPaise: 0,
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        relatedEntityType: 'expense',
        relatedEntityId: 'exp_1',
        createdAt: DateTime.now(),
      );

      expect(
        () => paymentRepo.recordPayment(invalidPayment),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'recordPayment updates cashbook balance when paid from business account',
      () async {
        final now = DateTime.now();
        // Setup business account with ₹10,000
        await cashbookRepo.createAccount(
          CashbookAccount(
            id: 'acc_cashbox',
            fairId: fairId,
            accountName: 'Main Cashbox',
            accountType: 'cash',
            openingBalancePaise: 1000000,
            currentBalancePaise: 1000000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Record business cash payment of ₹2,500
        final payment = PaymentRecord(
          id: 'pay_cash_exp',
          fairId: fairId,
          amountPaise: 250000, // ₹2,500
          paymentMethod: 'Cash',
          paymentDate: now,
          accountId: 'acc_cashbox',
          relatedEntityType: 'expense',
          relatedEntityId: 'exp_generator',
          createdAt: now,
        );

        await paymentRepo.recordPayment(payment);

        final account = await cashbookRepo.getAccountById('acc_cashbox');
        expect(account?.currentBalancePaise, 750000); // ₹7,500 remaining

        final txs = await cashbookRepo.getTransactions(
          accountId: 'acc_cashbox',
        );
        final expenseTx = txs.firstWhere(
          (t) => t.transactionType == 'expense_payment',
        );
        expect(expenseTx.amountPaise, 250000);
        expect(expenseTx.isOutflow, isTrue);
      },
    );

    test('recordPayment recalculates Expense paid amount and moves status from Unpaid -> Partially Paid -> Paid', () async {
      final now = DateTime.now();
      // Create an expense of ₹10,000
      final expense = Expense(
        id: 'exp_sound',
        fairId: fairId,
        title: 'Sound & Mic Rental',
        categoryId: 'cat_stall_rent',
        amountPaise: 1000000, // ₹10,000
        outstandingAmountPaise: 1000000,
        expenseDate: now,
        paymentStatus: 'Unpaid',
        createdAt: now,
        updatedAt: now,
      );
      await expenseDataSource.saveExpense(ExpenseModel.fromEntity(expense));

      // 1st Payment: ₹4,000
      await paymentRepo.recordPayment(
        PaymentRecord(
          id: 'pay_1',
          fairId: fairId,
          amountPaise: 400000,
          paymentMethod: 'Cash',
          paymentDate: now,
          relatedEntityType: 'expense',
          relatedEntityId: 'exp_sound',
          createdAt: now,
        ),
      );

      var updated = expenseDataSource.getExpenseById('exp_sound')!.toEntity();
      expect(updated.paidAmountPaise, 400000);
      expect(updated.outstandingAmountPaise, 600000);
      expect(updated.paymentStatus, 'Partially Paid');

      // 2nd Payment: ₹6,000 (Remaining balance)
      await paymentRepo.recordPayment(
        PaymentRecord(
          id: 'pay_2',
          fairId: fairId,
          amountPaise: 600000,
          paymentMethod: 'UPI',
          paymentDate: now,
          relatedEntityType: 'expense',
          relatedEntityId: 'exp_sound',
          createdAt: now,
        ),
      );

      updated = expenseDataSource.getExpenseById('exp_sound')!.toEntity();
      expect(updated.paidAmountPaise, 1000000);
      expect(updated.outstandingAmountPaise, 0);
      expect(updated.paymentStatus, 'Paid');
    });

    test('recordPayment updates PurchaseBatch payment status', () async {
      final now = DateTime.now();
      final batch = PurchaseBatch(
        id: 'batch_ananda',
        fairId: fairId,
        invoiceNumber: 'INV-001',
        supplierId: 'sup_ananda',
        purchaseDate: now,
        totalQuantity: 20,
        totalBookCostPaise: 800000,
        additionalChargesPaise: 0,
        totalAcquisitionCostPaise: 800000, // ₹8,000
        paymentStatus: 'Unpaid',
        paymentMethod: 'Bank Transfer',
        createdAt: now,
      );
      await db.purchaseBatches.put(
        'batch_ananda',
        PurchaseBatchModel.fromEntity(batch),
      );

      // Partial payment ₹3,000
      await paymentRepo.recordPayment(
        PaymentRecord(
          id: 'pay_batch_part',
          fairId: fairId,
          amountPaise: 300000,
          paymentMethod: 'Bank Transfer',
          paymentDate: now,
          relatedEntityType: 'purchase_batch',
          relatedEntityId: 'batch_ananda',
          createdAt: now,
        ),
      );

      var savedBatch = db.purchaseBatches.get('batch_ananda')!.toEntity();
      expect(savedBatch.paymentStatus, 'Partially Paid');

      // Final payment ₹5,000
      await paymentRepo.recordPayment(
        PaymentRecord(
          id: 'pay_batch_full',
          fairId: fairId,
          amountPaise: 500000,
          paymentMethod: 'Bank Transfer',
          paymentDate: now,
          relatedEntityType: 'purchase_batch',
          relatedEntityId: 'batch_ananda',
          createdAt: now,
        ),
      );

      savedBatch = db.purchaseBatches.get('batch_ananda')!.toEntity();
      expect(savedBatch.paymentStatus, 'Paid');
    });

    test('recordPartnerReimbursement disburses from cashbook and records reimbursement payment', () async {
      final now = DateTime.now();
      // Account with ₹20,000
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_bank',
          fairId: fairId,
          accountName: 'Current Bank',
          accountType: 'bank',
          openingBalancePaise: 2000000,
          currentBalancePaise: 2000000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final reimbursement = await paymentRepo.recordPartnerReimbursement(
        fairId: fairId,
        partnerId: 'partner_subhajit',
        amountPaise: 350000, // ₹3,500
        fromAccountId: 'acc_bank',
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'IMPS-998877',
        notes: 'Reimbursement for lighting fixtures',
        paymentDate: now,
      );

      expect(reimbursement.relatedEntityType, 'reimbursement');
      expect(reimbursement.recipientPartnerId, 'partner_subhajit');
      expect(reimbursement.amountPaise, 350000);

      // Verify bank account was debited
      final bank = await cashbookRepo.getAccountById('acc_bank');
      expect(bank?.currentBalancePaise, 1650000); // 20,000 - 3,500 = 16,500

      // Verify partner reimbursements query finds this record
      final reimbursements = await paymentRepo.getPartnerReimbursements(
        fairId: fairId,
        partnerId: 'partner_subhajit',
      );
      expect(reimbursements.length, 1);
      expect(reimbursements.first.amountPaise, 350000);
    });
  });
}
