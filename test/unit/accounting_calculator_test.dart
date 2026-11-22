import 'package:flutter_test/flutter_test.dart';
import 'package:bookfair_manager/features/accounting/domain/services/accounting_calculator.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/partner.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/account_transaction.dart';
import 'package:bookfair_manager/features/cashbook/domain/entities/cashbook_account.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense.dart';
import 'package:bookfair_manager/features/expenses/domain/entities/expense_category.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_batch.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/supplier.dart';
import 'package:bookfair_manager/features/payments/domain/entities/payment_record.dart';

void main() {
  const calculator = AccountingCalculator();

  group('AccountingCalculator - Stage 04 Rules', () {
    test('Operating expenses accurately computes total, paid, and outstanding obligations', () {
      final expenses = [
        Expense(
          id: 'exp1',
          fairId: 'fair1',
          title: 'Stall Rent',
          categoryId: 'cat1',
          amountPaise: 400000, // ₹4000
          paidAmountPaise: 200000, // ₹2000 paid
          outstandingAmountPaise: 200000, // ₹2000 outstanding
          expenseDate: DateTime.now(),
          paymentStatus: 'Partially Paid',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Expense(
          id: 'exp2',
          fairId: 'fair1',
          title: 'Flex Banner',
          categoryId: 'cat2',
          amountPaise: 150000, // ₹1500
          paidAmountPaise: 150000, // ₹1500 paid
          outstandingAmountPaise: 0,
          expenseDate: DateTime.now(),
          paymentStatus: 'Paid',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Expense(
          id: 'exp3',
          fairId: 'fair1',
          title: 'Cancelled Printing',
          categoryId: 'cat2',
          amountPaise: 80000, // ₹800
          paidAmountPaise: 0,
          outstandingAmountPaise: 0,
          expenseDate: DateTime.now(),
          paymentStatus: 'Cancelled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final metrics = calculator.calculateMetrics(
        expenses: expenses,
        accounts: [],
        payments: [],
        purchaseBatches: [],
        investments: [],
      );

      // Excludes cancelled ₹800: Total is 4000 + 1500 = ₹5500
      expect(metrics.totalExpensesPaise, 550000);
      expect(metrics.paidExpensesPaise, 350000);
      expect(metrics.outstandingExpensesPaise, 200000);
      expect(metrics.totalExpenses, 5500.0);
      expect(metrics.paidExpenses, 3500.0);
      expect(metrics.outstandingExpenses, 2000.0);
    });

    test('Liquid business cashbook balances strictly aggregates cash, upi, and bank accounts', () {
      final accounts = [
        CashbookAccount(
          id: 'acc1',
          fairId: 'fair1',
          accountName: 'Main Cashbox',
          accountType: 'cash',
          openingBalancePaise: 500000, // ₹5000
          currentBalancePaise: 750000, // ₹7500
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CashbookAccount(
          id: 'acc2',
          fairId: 'fair1',
          accountName: 'GPay Merchant',
          accountType: 'upi',
          openingBalancePaise: 0,
          currentBalancePaise: 1200000, // ₹12000
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CashbookAccount(
          id: 'acc3',
          fairId: 'fair1',
          accountName: 'HDFC Current',
          accountType: 'bank',
          openingBalancePaise: 2000000, // ₹20000
          currentBalancePaise: 2500000, // ₹25000
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final metrics = calculator.calculateMetrics(
        expenses: [],
        accounts: accounts,
        payments: [],
        purchaseBatches: [],
        investments: [],
      );

      expect(metrics.totalCashBalancePaise, 750000);
      expect(metrics.totalUpiBalancePaise, 1200000);
      expect(metrics.totalBankBalancePaise, 2500000);
      expect(metrics.totalBusinessFundsPaise, 4450000); // ₹44,500
    });

    test('Partner personal payment creates reimbursement liability without modifying business cashbox', () {
      final partner = Partner(
        id: 'p1',
        fairId: 'fair1',
        fullName: 'Abir Roy',
        role: PartnerRole.partner,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Abir personally disbursed ₹2,000 for Stall Rent
      final personalPayment = PaymentRecord(
        id: 'pmt1',
        fairId: 'fair1',
        amountPaise: 200000, // ₹2000
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        accountId: null, // NOT paid from business account
        payerPartnerId: 'p1',
        relatedEntityType: 'expense',
        relatedEntityId: 'exp1',
        createdAt: DateTime.now(),
      );

      final dues = calculator.calculatePartnerDues(
        partners: [partner],
        expenses: [],
        payments: [personalPayment],
        investments: [],
      );

      expect(dues.length, 1);
      expect(dues.first.personallyPaidPaise, 200000);
      expect(dues.first.reimbursedPaise, 0);
      expect(dues.first.outstandingReimbursementPaise, 200000);
      expect(dues.first.outstandingReimbursement, 2000.0);
    });

    test('Reimbursement payment reduces liability to zero without double-counting as an expense', () {
      final partner = Partner(
        id: 'p1',
        fairId: 'fair1',
        fullName: 'Abir Roy',
        role: PartnerRole.partner,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // 1. Personal payment of ₹2,000
      final personalPayment = PaymentRecord(
        id: 'pmt1',
        fairId: 'fair1',
        amountPaise: 200000,
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        accountId: null,
        payerPartnerId: 'p1',
        relatedEntityType: 'expense',
        relatedEntityId: 'exp1',
        createdAt: DateTime.now(),
      );

      // 2. Business reimburses ₹2,000 from cashbox to Abir
      final reimbursementPayment = PaymentRecord(
        id: 'pmt2',
        fairId: 'fair1',
        amountPaise: 200000,
        paymentMethod: 'Cash',
        paymentDate: DateTime.now(),
        accountId: 'acc1', // Paid from business cashbox
        recipientPartnerId: 'p1',
        relatedEntityType: 'reimbursement',
        relatedEntityId: 'p1',
        createdAt: DateTime.now(),
      );

      final dues = calculator.calculatePartnerDues(
        partners: [partner],
        expenses: [],
        payments: [personalPayment, reimbursementPayment],
        investments: [],
      );

      expect(dues.first.personallyPaidPaise, 200000);
      expect(dues.first.reimbursedPaise, 200000);
      expect(dues.first.outstandingReimbursementPaise, 0);
    });

    test(
      'Supplier payables derive from purchase batches and payment records',
      () {
        final supplier = Supplier(
          id: 'sup1',
          name: 'Ananda Publishers',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final batch = PurchaseBatch(
          id: 'batch1',
          fairId: 'fair1',
          supplierId: 'sup1',
          purchaseDate: DateTime.now(),
          totalQuantity: 100,
          totalBookCostPaise: 1000000, // ₹10,000
          totalAcquisitionCostPaise: 1000000,
          createdAt: DateTime.now(),
        );

        // Paid advance ₹4,000
        final advancePayment = PaymentRecord(
          id: 'pmt3',
          fairId: 'fair1',
          amountPaise: 400000,
          paymentMethod: 'Bank Transfer',
          paymentDate: DateTime.now(),
          accountId: 'acc3',
          supplierId: 'sup1',
          relatedEntityType: 'purchase_batch',
          relatedEntityId: 'batch1',
          createdAt: DateTime.now(),
        );

        final payables = calculator.calculateSupplierPayables(
          suppliers: [supplier],
          batches: [batch],
          payments: [advancePayment],
        );

        expect(payables.length, 1);
        expect(payables.first.totalPurchasesPaise, 1000000);
        expect(payables.first.totalPaidPaise, 400000);
        expect(
          payables.first.outstandingPayablesPaise,
          600000,
        ); // ₹6,000 pending
        expect(payables.first.outstandingPayables, 6000.0);
      },
    );

    test(
      'Cash flow calculation excludes internal transfers between accounts',
      () {
        final txs = [
          AccountTransaction(
            id: 'tx1',
            fairId: 'fair1',
            accountId: 'acc1',
            transactionType: 'investment_received',
            direction: 'inflow',
            amountPaise: 500000, // +₹5000
            transactionDate: DateTime.now(),
            referenceType: 'investment',
            description: 'Partner investment',
            createdAt: DateTime.now(),
          ),
          AccountTransaction(
            id: 'tx2',
            fairId: 'fair1',
            accountId: 'acc1',
            transactionType: 'account_transfer_out',
            direction: 'outflow',
            amountPaise: 100000, // Transfer out ₹1000
            transactionDate: DateTime.now(),
            referenceType: 'account_transfer',
            description: 'Transfer to UPI',
            createdAt: DateTime.now(),
          ),
          AccountTransaction(
            id: 'tx3',
            fairId: 'fair1',
            accountId: 'acc2',
            transactionType: 'account_transfer_in',
            direction: 'inflow',
            amountPaise: 100000, // Transfer in ₹1000
            transactionDate: DateTime.now(),
            referenceType: 'account_transfer',
            description: 'Transfer from Cash',
            createdAt: DateTime.now(),
          ),
          AccountTransaction(
            id: 'tx4',
            fairId: 'fair1',
            accountId: 'acc1',
            transactionType: 'expense_payment',
            direction: 'outflow',
            amountPaise: 200000, // -₹2000
            transactionDate: DateTime.now(),
            referenceType: 'expense',
            description: 'Stall advance',
            createdAt: DateTime.now(),
          ),
        ];

        final flow = calculator.calculateCashFlow(transactions: txs);

        // Transfers are excluded:
        // Inflow = ₹5000
        // Outflow = ₹2000
        // Net = ₹3000
        expect(flow.totalInflowPaise, 500000);
        expect(flow.totalOutflowPaise, 200000);
        expect(flow.netMovementPaise, 300000);
      },
    );

    test('Category distribution computes accurate percentages and counts', () {
      final categories = [
        ExpenseCategory(
          id: 'cat_rent',
          name: 'Stall Rent',
          createdAt: DateTime(2026, 1, 1),
        ),
        ExpenseCategory(
          id: 'cat_food',
          name: 'Food & Refreshments',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final expenses = [
        Expense(
          id: 'e1',
          fairId: 'f1',
          title: 'Rent',
          categoryId: 'cat_rent',
          amountPaise: 800000, // ₹8,000 (80%)
          outstandingAmountPaise: 0,
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Expense(
          id: 'e2',
          fairId: 'f1',
          title: 'Lunch',
          categoryId: 'cat_food',
          amountPaise: 200000, // ₹2,000 (20%)
          outstandingAmountPaise: 0,
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final breakdown = calculator.calculateCategoryBreakdown(
        expenses: expenses,
        categories: categories,
      );

      expect(breakdown.length, 2);
      expect(breakdown.first.categoryId, 'cat_rent');
      expect(breakdown.first.percentage, 80.0);
      expect(breakdown.last.categoryId, 'cat_food');
      expect(breakdown.last.percentage, 20.0);
    });
  });
}
