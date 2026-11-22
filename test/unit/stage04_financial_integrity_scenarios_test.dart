import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/accounting/domain/services/accounting_calculator.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/book_fair_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/partner_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/partner.dart';
import 'package:bookfair_manager/features/cashbook/data/datasources/cashbook_local_datasource.dart';
import 'package:bookfair_manager/features/cashbook/data/repositories/cashbook_repository_impl.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:bookfair_manager/features/expenses/data/repositories/expense_repository_impl.dart';
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

  final expenseRepo = ExpenseRepositoryImpl(
    expenseDataSource: expenseDataSource,
    paymentRepository: paymentRepo,
    activityLogs: activityRepo,
  );

  const calculator = AccountingCalculator();

  group('Stage 04 Financial Integrity — 7 Real-World Scenarios', () {
    const fairId = 'fair_kolkata_2026';
    final now = DateTime.now();

    Future<void> setupBaseEntities() async {
      // 1. Fair
      final fair = BookFair(
        id: fairId,
        name: 'Kolkata Book Fair 2026',
        location: 'Milan Mela',
        city: 'Kolkata',
        state: 'West Bengal',
        startDate: now,
        endDate: now.add(const Duration(days: 10)),
        estimatedBudgetPaise: 10000000,
        initialInvestmentPaise: 5000000,
        createdAt: now,
        updatedAt: now,
      );
      await fairDataSource.createBookFair(BookFairModel.fromEntity(fair));

      // 2. Partner Sayan
      final partner = Partner(
        id: 'partner_sayan',
        fairId: fairId,
        fullName: 'Sayan Banik',
        role: PartnerRole.owner,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await fairDataSource.createPartner(PartnerModel.fromEntity(partner));

      // 3. Cashbook Accounts: Cashbox (₹25,000) and Bank (₹50,000)
      await cashbookRepo.createAccount(
        CashbookAccount(
          id: 'acc_cash',
          fairId: fairId,
          accountName: 'Main Cashbox',
          accountType: 'cash',
          openingBalancePaise: 2500000, // ₹25,000
          currentBalancePaise: 2500000,
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
          openingBalancePaise: 5000000, // ₹50,000
          currentBalancePaise: 5000000,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    test('Scenario 1 — Business-funded expense decreases cash and updates outstanding amount', () async {
      await setupBaseEntities();

      // Create a ₹10,000 stall decoration expense with ₹4,000 initial payment from Cashbox
      final expense = Expense(
        id: 'exp_decor',
        fairId: fairId,
        title: 'Stall Fabrication & Decor',
        categoryId: 'cat_stall_construction',
        amountPaise: 1000000, // ₹10,000
        outstandingAmountPaise: 1000000,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final created = await expenseRepo.createExpense(
        expense,
        initialPaymentAmountPaise: 400000, // ₹4,000 paid
        paymentMethod: 'Cash',
        paidFromAccountId: 'acc_cash',
      );

      // Verify expense state
      expect(created.amountPaise, 1000000);
      expect(created.paidAmountPaise, 400000);
      expect(created.outstandingAmountPaise, 600000); // ₹6,000 remaining
      expect(created.paymentStatus, 'Partially Paid');

      // Verify business cash decreased by ₹4,000: 25,000 - 4,000 = 21,000
      final cashAccount = await cashbookRepo.getAccountById('acc_cash');
      expect(cashAccount?.currentBalancePaise, 2100000);

      // Verify ledger transaction was written
      final txs = await cashbookRepo.getTransactions(accountId: 'acc_cash');
      final expTx = txs.firstWhere(
        (t) => t.transactionType == 'expense_payment',
      );
      expect(expTx.amountPaise, 400000);
      expect(expTx.isOutflow, isTrue);

      // Verify AccountingCalculator metrics
      final allExpenses = await expenseRepo.getExpenses(fairId: fairId);
      final allAccounts = await cashbookRepo.getAccounts(fairId: fairId);
      final allPayments = await paymentRepo.getPayments(fairId: fairId);

      final metrics = calculator.calculateMetrics(
        expenses: allExpenses,
        accounts: allAccounts,
        payments: allPayments,
        purchaseBatches: [],
        investments: [],
      );

      expect(metrics.totalExpensesPaise, 1000000);
      expect(metrics.paidExpensesPaise, 400000);
      expect(metrics.outstandingExpensesPaise, 600000);
      expect(metrics.totalCashBalancePaise, 2100000);
    });

    test('Scenario 2 — Partner-funded expense creates reimbursement liability without reducing business cash', () async {
      await setupBaseEntities();

      // Create a ₹5,000 banner printing expense personally funded by partner Sayan
      final expense = Expense(
        id: 'exp_banners',
        fairId: fairId,
        title: 'Entrance Arch Flex & Banners',
        categoryId: 'cat_banners',
        amountPaise: 500000, // ₹5,000
        outstandingAmountPaise: 500000,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final created = await expenseRepo.createExpense(
        expense,
        initialPaymentAmountPaise: 500000, // ₹5,000 paid personally
        paymentMethod: 'Cash',
        paidByPartnerId: 'partner_sayan',
        paidFromAccountId: null, // Partner personal funds
      );

      expect(created.paymentStatus, 'Paid');
      expect(created.outstandingAmountPaise, 0);

      // Verify business cashbox remains COMPLETELY UNCHANGED at ₹25,000
      final cashAccount = await cashbookRepo.getAccountById('acc_cash');
      expect(cashAccount?.currentBalancePaise, 2500000);

      // Verify partner reimbursement liability equals ₹5,000
      final partnerModel = await fairDataSource.getPartnerById('partner_sayan');
      final allExpenses = await expenseRepo.getExpenses(fairId: fairId);
      final allPayments = await paymentRepo.getPayments(fairId: fairId);

      final partnerDues = calculator.calculatePartnerDues(
        partners: [partnerModel!.toEntity()],
        expenses: allExpenses,
        payments: allPayments,
        investments: [],
      );

      expect(partnerDues.first.personallyPaidPaise, 500000);
      expect(partnerDues.first.outstandingReimbursementPaise, 500000);
      expect(partnerDues.first.reimbursedPaise, 0);
    });

    test('Scenario 3 — Partner reimbursement reduces liability and cash without creating duplicate expense', () async {
      await setupBaseEntities();

      // 1. Partner personally pays ₹5,000
      final expense = Expense(
        id: 'exp_lighting',
        fairId: fairId,
        title: 'Focus Lights',
        categoryId: 'cat_lighting',
        amountPaise: 500000,
        outstandingAmountPaise: 500000,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await expenseRepo.createExpense(
        expense,
        initialPaymentAmountPaise: 500000,
        paymentMethod: 'Cash',
        paidByPartnerId: 'partner_sayan',
      );

      // 2. Business reimburses ₹2,000 to partner Sayan from Cashbox
      await paymentRepo.recordPartnerReimbursement(
        fairId: fairId,
        partnerId: 'partner_sayan',
        amountPaise: 200000, // ₹2,000
        fromAccountId: 'acc_cash',
        paymentMethod: 'Cash',
        referenceNumber: 'REIMB-001',
        paymentDate: now,
      );

      // Verify business cashbox decreased by ₹2,000: 25,000 - 2,000 = 23,000
      final cashAccount = await cashbookRepo.getAccountById('acc_cash');
      expect(cashAccount?.currentBalancePaise, 2300000);

      // Verify reimbursement liability decreased to ₹3,000 (5,000 - 2,000)
      final partnerModel = await fairDataSource.getPartnerById('partner_sayan');
      final allExpenses = await expenseRepo.getExpenses(fairId: fairId);
      final allPayments = await paymentRepo.getPayments(fairId: fairId);

      final partnerDues = calculator.calculatePartnerDues(
        partners: [partnerModel!.toEntity()],
        expenses: allExpenses,
        payments: allPayments,
        investments: [],
      );

      expect(partnerDues.first.personallyPaidPaise, 500000);
      expect(partnerDues.first.reimbursedPaise, 200000);
      expect(partnerDues.first.outstandingReimbursementPaise, 300000);

      // Verify NO duplicate expense was created (total expenses remains exactly ₹5,000)
      final allAccounts = await cashbookRepo.getAccounts(fairId: fairId);
      final metrics = calculator.calculateMetrics(
        expenses: allExpenses,
        accounts: allAccounts,
        payments: allPayments,
        purchaseBatches: [],
        investments: [],
      );
      expect(metrics.totalExpensesPaise, 500000); // Only focus lights!
    });

    test('Scenario 4 — Internal transfer debits source and credits destination, preserving total liquidity', () async {
      await setupBaseEntities();

      // Total liquid funds initially: 25,000 + 50,000 = 75,000
      final initialCash = (await cashbookRepo.getAccountById('acc_cash'))!
          .currentBalancePaise;
      final initialBank = (await cashbookRepo.getAccountById('acc_bank'))!
          .currentBalancePaise;
      expect(initialCash + initialBank, 7500000);

      // Transfer ₹3,000 from Cashbox to Bank
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_cash',
        toAccountId: 'acc_bank',
        amountPaise: 300000, // ₹3,000
        transferDate: now,
        referenceNumber: 'DEP-01',
      );

      final updatedCash = (await cashbookRepo.getAccountById('acc_cash'))!
          .currentBalancePaise;
      final updatedBank = (await cashbookRepo.getAccountById('acc_bank'))!
          .currentBalancePaise;

      expect(updatedCash, 2200000); // 25,000 - 3,000 = 22,000
      expect(updatedBank, 5300000); // 50,000 + 3,000 = 53,000

      // Total liquid funds strictly preserved
      expect(updatedCash + updatedBank, 7500000);
    });

    test('Scenario 5 — Purchase batch payment updates supplier payables and debits cashbook without expense duplication', () async {
      await setupBaseEntities();

      // Create purchase batch of ₹20,000
      final batch = PurchaseBatch(
        id: 'batch_dey',
        fairId: fairId,
        supplierId: 'sup_dey',
        purchaseDate: now,
        invoiceNumber: 'INV-2026-99',
        totalQuantity: 100,
        totalBookCostPaise: 2000000, // ₹20,000
        additionalChargesPaise: 0,
        totalAcquisitionCostPaise: 2000000,
        paymentStatus: 'Unpaid',
        paymentMethod: 'Bank Transfer',
        createdAt: now,
      );
      await db.purchaseBatches.put(
        'batch_dey',
        PurchaseBatchModel.fromEntity(batch),
      );

      // Disburse payment of ₹12,000 from Bank Account
      await paymentRepo.recordPayment(
        PaymentRecord(
          id: 'pay_batch_1',
          fairId: fairId,
          amountPaise: 1200000, // ₹12,000
          paymentMethod: 'Bank Transfer',
          paymentDate: now,
          accountId: 'acc_bank',
          relatedEntityType: 'purchase_batch',
          relatedEntityId: 'batch_dey',
          createdAt: now,
        ),
      );

      // Verify Bank Account decreased by ₹12,000: 50,000 - 12,000 = 38,000
      final bankAccount = await cashbookRepo.getAccountById('acc_bank');
      expect(bankAccount?.currentBalancePaise, 3800000);

      // Verify Batch status is 'Partially Paid'
      final savedBatch = db.purchaseBatches.get('batch_dey')!.toEntity();
      expect(savedBatch.paymentStatus, 'Partially Paid');

      // Verify supplier payable equals ₹8,000 (20,000 - 12,000)
      final allBatches = [savedBatch];
      final allPayments = await paymentRepo.getPayments(fairId: fairId);
      final allAccounts = await cashbookRepo.getAccounts(fairId: fairId);

      final metrics = calculator.calculateMetrics(
        expenses: [],
        accounts: allAccounts,
        payments: allPayments,
        purchaseBatches: allBatches,
        investments: [],
      );

      expect(metrics.totalPurchaseOutlayPaise, 2000000);
      expect(metrics.totalPaidPurchaseOutlayPaise, 1200000);
      expect(metrics.totalSupplierPayablesPaise, 800000);
      expect(
        metrics.totalExpensesPaise,
        0,
      ); // Procurement is NOT an operational expense!
    });

    test('Scenario 6 — Expense cancellation preserves audit trace, zeroes obligations, and does not delete records', () async {
      await setupBaseEntities();

      // Create an expense of ₹8,000 with ₹3,000 partial payment from Cashbox
      final expense = Expense(
        id: 'exp_mic',
        fairId: fairId,
        title: 'Microphone & PA System',
        categoryId: 'cat_lighting',
        amountPaise: 800000, // ₹8,000
        outstandingAmountPaise: 800000,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await expenseRepo.createExpense(
        expense,
        initialPaymentAmountPaise: 300000, // ₹3,000 paid
        paymentMethod: 'Cash',
        paidFromAccountId: 'acc_cash',
      );

      // Cancel the expense with a documented reason and full refund to Cashbox
      await expenseRepo.cancelExpense(
        'exp_mic',
        'Organizers provided complimentary audio system',
        refundToAccountId: 'acc_cash',
      );

      // Verify expense record still exists in Hive (not deleted!)
      final cancelled = await expenseRepo.getExpenseById('exp_mic');
      expect(cancelled, isNotNull);
      expect(cancelled?.paymentStatus, 'Cancelled (Refunded)');
      expect(cancelled?.outstandingAmountPaise, 0); // Obligations zeroed
      expect(cancelled?.paidAmountPaise, 300000); // Disbursed amount preserved
      expect(
        cancelled?.notes,
        contains('Organizers provided complimentary audio system'),
      );

      // Verify payment record is preserved in history
      final payments = await paymentRepo.getPayments(
        relatedEntityType: 'expense',
        relatedEntityId: 'exp_mic',
      );
      expect(payments.length, 1);
      expect(payments.first.amountPaise, 300000);

      // Verify metrics exclude cancelled expense obligations
      final allExpenses = await expenseRepo.getExpenses(fairId: fairId);
      final allAccounts = await cashbookRepo.getAccounts(fairId: fairId);
      final allPayments = await paymentRepo.getPayments(fairId: fairId);

      final metrics = calculator.calculateMetrics(
        expenses: allExpenses,
        accounts: allAccounts,
        payments: allPayments,
        purchaseBatches: [],
        investments: [],
      );

      expect(metrics.totalExpensesPaise, 0);
      expect(metrics.outstandingExpensesPaise, 0);
    });

    test('Scenario 7 — Database restart persistence preserves balances, payments, and transaction history', () async {
      await setupBaseEntities();

      // Perform a series of representative transactions:
      // 1. Expense: ₹6,000 paid ₹6,000 from Cashbox
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_wifi',
          fairId: fairId,
          title: 'Wi-Fi Hotspot',
          categoryId: 'cat_internet',
          amountPaise: 600000,
          outstandingAmountPaise: 600000,
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        initialPaymentAmountPaise: 600000,
        paymentMethod: 'Cash',
        paidFromAccountId: 'acc_cash',
      );

      // 2. Transfer ₹5,000 from Bank to Cashbox
      await cashbookRepo.transferFunds(
        fairId: fairId,
        fromAccountId: 'acc_bank',
        toAccountId: 'acc_cash',
        amountPaise: 500000,
        transferDate: now,
        referenceNumber: 'ATM-WITHDRAWAL',
      );

      // Balances before restart:
      // Cashbox: 25,000 - 6,000 + 5,000 = 24,000 (2,400,000 paise)
      // Bank: 50,000 - 5,000 = 45,000 (4,500,000 paise)
      final cashBefore = (await cashbookRepo.getAccountById('acc_cash'))!
          .currentBalancePaise;
      final bankBefore = (await cashbookRepo.getAccountById('acc_bank'))!
          .currentBalancePaise;
      expect(cashBefore, 2400000);
      expect(bankBefore, 4500000);

      // Re-read directly from underlying Hive models (verifying persistence without memory cache)
      final persistedCashModel = db.cashbookAccounts.get('acc_cash');
      final persistedBankModel = db.cashbookAccounts.get('acc_bank');
      final persistedExpenseModel = db.expenses.get('exp_wifi');
      final persistedPayments = db.paymentRecords.values
          .where((p) => p.fairId == fairId)
          .toList();
      final persistedTxs = db.accountTransactions.values
          .where((t) => t.fairId == fairId)
          .toList();

      expect(persistedCashModel?.currentBalancePaise, 2400000);
      expect(persistedBankModel?.currentBalancePaise, 4500000);
      expect(persistedExpenseModel?.paymentStatus, 'Paid');
      expect(persistedPayments.length, 1);
      expect(
        persistedTxs.length,
        greaterThanOrEqualTo(4),
      ); // 2 opening, 2 transfer, 1 expense payment
    });
  });
}
