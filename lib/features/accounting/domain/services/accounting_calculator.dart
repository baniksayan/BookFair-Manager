import 'dart:math';

import '../../../book_fairs/domain/entities/investment.dart';
import '../../../book_fairs/domain/entities/partner.dart';
import '../../../cashbook/domain/entities/account_transaction.dart';
import '../../../cashbook/domain/entities/cashbook_account.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../inventory/domain/entities/purchase_batch.dart';
import '../../../inventory/domain/entities/supplier.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../../sales/domain/entities/sale_receipt.dart';
import '../models/financial_models.dart';

/// Pure calculation engine for BookFair Manager financial accounting metrics.
/// Adheres strictly to offline accounting rules:
/// - Investments != Revenue
/// - Personal payments != Business Cash reduction
/// - Reimbursements != New Expenses
/// - Account Transfers leave Total Business Funds unchanged
class AccountingCalculator {
  const AccountingCalculator();

  /// Computes overall financial metrics for an individual Book Fair or across all Fairs.
  FinancialMetrics calculateMetrics({
    required List<Expense> expenses,
    required List<CashbookAccount> accounts,
    required List<PaymentRecord> payments,
    required List<PurchaseBatch> purchaseBatches,
    required List<Investment> investments,
    List<Partner> partners = const [],
    List<SaleReceipt> receipts = const [],
  }) {
    // 1. Operating Expenses
    final validExpenses = expenses.where((e) => !e.isCancelled).toList();
    final totalExpensesPaise = validExpenses.fold<int>(
      0,
      (sum, e) => sum + e.amountPaise,
    );
    final paidExpensesPaise = validExpenses.fold<int>(
      0,
      (sum, e) => sum + e.paidAmountPaise,
    );
    final outstandingExpensesPaise = validExpenses.fold<int>(
      0,
      (sum, e) => sum + e.outstandingAmountPaise,
    );

    // 2. Business Cashbook Balances
    final activeAccounts = accounts.where((a) => a.isActive).toList();
    int cashBalance = 0;
    int upiBalance = 0;
    int bankBalance = 0;
    int totalFunds = 0;

    for (final acc in activeAccounts) {
      totalFunds += acc.currentBalancePaise;
      switch (acc.accountType.toLowerCase()) {
        case 'cash':
          cashBalance += acc.currentBalancePaise;
          break;
        case 'upi':
          upiBalance += acc.currentBalancePaise;
          break;
        case 'bank':
          bankBalance += acc.currentBalancePaise;
          break;
        default:
          // Other accounts contribute to totalFunds
          break;
      }
    }

    // 3. Purchase Outlay & Supplier Payables
    final totalPurchaseOutlayPaise = purchaseBatches.fold<int>(
      0,
      (sum, b) => sum + b.totalAcquisitionCostPaise,
    );

    final purchasePayments = payments.where(
      (p) => p.relatedEntityType == 'purchase_batch',
    );
    final totalPaidPurchaseOutlayPaise = purchasePayments.fold<int>(
      0,
      (sum, p) => sum + p.amountPaise,
    );

    final totalSupplierPayablesPaise = max(
      0,
      totalPurchaseOutlayPaise - totalPaidPurchaseOutlayPaise,
    );

    // 4. Partner Reimbursement Liability
    final partnerDues = calculatePartnerDues(
      partners: partners,
      expenses: validExpenses,
      payments: payments,
      investments: investments,
    );
    final totalPartnerReimbursementLiabilityPaise = partnerDues.fold<int>(
      0,
      (sum, d) => sum + d.outstandingReimbursementPaise,
    );

    // 5. Total Investment Capital
    final totalInvestmentPaise = investments.fold<int>(
      0,
      (sum, i) => sum + i.amountPaise,
    );

    // 6. Stage 05 Sales Analytics, COGS, Gross Profit & Net Profit
    final totalGrossSalesPaise = receipts.fold<int>(
      0,
      (sum, r) => sum + r.totalAmountPaise,
    );
    final totalSalesRefundsPaise = receipts.fold<int>(
      0,
      (sum, r) => sum + r.refundedAmountPaise,
    );
    final netSalesRevenuePaise = totalGrossSalesPaise - totalSalesRefundsPaise;

    int totalCogsPaise = 0;
    int provisionalCogsPaise = 0;
    int totalUnitsSold = 0;

    for (final r in receipts) {
      for (final item in r.items) {
        final netQty = max(0, item.quantity - item.returnedQuantity);
        totalUnitsSold += netQty;
        if (item.isCostProvisional) {
          provisionalCogsPaise += (netQty * item.unitCostPaise);
        } else {
          totalCogsPaise += (netQty * item.unitCostPaise);
        }
      }
    }

    final grossProfitPaise = netSalesRevenuePaise - totalCogsPaise;
    final grossMarginPercentage = netSalesRevenuePaise > 0
        ? (grossProfitPaise.toDouble() / netSalesRevenuePaise.toDouble()) *
              100.0
        : 0.0;

    // Realized Fair Net Profit = Realized Gross Profit - Fair-Allocated Operating Expenses
    final netProfitPaise = grossProfitPaise - totalExpensesPaise;

    // Sales Payment Rail Collections
    final salesPayments = payments.where((p) => p.relatedEntityType == 'sale');
    int cashSalesCollectionPaise = 0;
    int upiSalesCollectionPaise = 0;
    int otherSalesCollectionPaise = 0;

    for (final p in salesPayments) {
      final method = p.paymentMethod.toLowerCase();
      if (method == 'cash') {
        cashSalesCollectionPaise += p.amountPaise;
      } else if (method == 'upi' || method.contains('upi')) {
        upiSalesCollectionPaise += p.amountPaise;
      } else {
        otherSalesCollectionPaise += p.amountPaise;
      }
    }

    return FinancialMetrics(
      totalExpensesPaise: totalExpensesPaise,
      paidExpensesPaise: paidExpensesPaise,
      outstandingExpensesPaise: outstandingExpensesPaise,
      totalBusinessFundsPaise: totalFunds,
      totalCashBalancePaise: cashBalance,
      totalUpiBalancePaise: upiBalance,
      totalBankBalancePaise: bankBalance,
      totalPartnerReimbursementLiabilityPaise:
          totalPartnerReimbursementLiabilityPaise,
      totalSupplierPayablesPaise: totalSupplierPayablesPaise,
      totalInvestmentPaise: totalInvestmentPaise,
      totalPurchaseOutlayPaise: totalPurchaseOutlayPaise,
      totalPaidPurchaseOutlayPaise: totalPaidPurchaseOutlayPaise,
      totalGrossSalesPaise: totalGrossSalesPaise,
      totalSalesRefundsPaise: totalSalesRefundsPaise,
      netSalesRevenuePaise: netSalesRevenuePaise,
      totalCogsPaise: totalCogsPaise,
      provisionalCogsPaise: provisionalCogsPaise,
      grossProfitPaise: grossProfitPaise,
      grossMarginPercentage: double.parse(
        grossMarginPercentage.toStringAsFixed(2),
      ),
      netProfitPaise: netProfitPaise,
      totalReceiptsCount: receipts.length,
      totalUnitsSold: totalUnitsSold,
      cashSalesCollectionPaise: cashSalesCollectionPaise,
      upiSalesCollectionPaise: upiSalesCollectionPaise,
      otherSalesCollectionPaise: otherSalesCollectionPaise,
    );
  }

  /// Calculates partner dues, personally disbursed funds, settled reimbursements, and capital investments.
  List<PartnerDuesSummary> calculatePartnerDues({
    required List<Partner> partners,
    required List<Expense> expenses,
    required List<PaymentRecord> payments,
    required List<Investment> investments,
    List<PurchaseBatch> purchaseBatches = const [],
  }) {
    final summaries = <PartnerDuesSummary>[];

    for (final partner in partners) {
      // Personally paid funds by this partner (excluding business cashbook accounts and reimbursements)
      final personalPayments = payments.where(
        (p) =>
            p.paidByPartnerId == partner.id &&
            p.accountId == null &&
            p.relatedEntityType != 'reimbursement',
      );

      int personallyPaidPaise = personalPayments.fold<int>(
        0,
        (sum, p) => sum + p.amountPaise,
      );

      // Also check expenses directly marked as paid by partner where payment records might not exist yet
      final expensesByPartner = expenses.where(
        (e) =>
            !e.isCancelled &&
            e.paidByPartnerId == partner.id &&
            e.paidFromAccountId == null,
      );
      for (final exp in expensesByPartner) {
        final hasPaymentRecord = personalPayments.any(
          (p) =>
              p.relatedEntityType == 'expense' && p.relatedEntityId == exp.id,
        );
        if (!hasPaymentRecord && exp.paidAmountPaise > 0) {
          personallyPaidPaise += exp.paidAmountPaise;
        }
      }

      // Reimbursed amounts paid by business back to this partner
      final reimbursementPayments = payments.where(
        (p) =>
            p.relatedEntityType == 'reimbursement' &&
            p.recipientPartnerId == partner.id,
      );
      final reimbursedPaise = reimbursementPayments.fold<int>(
        0,
        (sum, p) => sum + p.amountPaise,
      );

      final outstandingReimbursementPaise = max(
        0,
        personallyPaidPaise - reimbursedPaise,
      );

      // Capital investments made by this partner
      final partnerInvestments = investments.where(
        (i) => i.partnerId == partner.id,
      );
      final totalCapitalInvestedPaise = partnerInvestments.fold<int>(
        0,
        (sum, i) => sum + i.amountPaise,
      );

      summaries.add(
        PartnerDuesSummary(
          partnerId: partner.id,
          partnerName: partner.fullName,
          role: partner.role.displayName,
          personallyPaidPaise: personallyPaidPaise,
          reimbursedPaise: reimbursedPaise,
          outstandingReimbursementPaise: outstandingReimbursementPaise,
          totalCapitalInvestedPaise: totalCapitalInvestedPaise,
        ),
      );
    }

    return summaries;
  }

  /// Calculates distribution of expenses across categories with percentages.
  List<CategoryExpenseBreakdown> calculateCategoryBreakdown({
    required List<Expense> expenses,
    required List<ExpenseCategory> categories,
  }) {
    final validExpenses = expenses.where((e) => !e.isCancelled).toList();
    final totalAllExpensesPaise = validExpenses.fold<int>(
      0,
      (sum, e) => sum + e.amountPaise,
    );

    final categoryMap = {for (final c in categories) c.id: c};
    final groupedAmount = <String, int>{};
    final groupedCount = <String, int>{};

    for (final exp in validExpenses) {
      groupedAmount[exp.categoryId] =
          (groupedAmount[exp.categoryId] ?? 0) + exp.amountPaise;
      groupedCount[exp.categoryId] = (groupedCount[exp.categoryId] ?? 0) + 1;
    }

    final results = <CategoryExpenseBreakdown>[];
    groupedAmount.forEach((catId, amountPaise) {
      final category = categoryMap[catId];
      final name = category?.name ?? 'Uncategorized';
      final icon = category?.iconName;
      final count = groupedCount[catId] ?? 0;
      final percentage = totalAllExpensesPaise > 0
          ? (amountPaise / totalAllExpensesPaise) * 100.0
          : 0.0;

      results.add(
        CategoryExpenseBreakdown(
          categoryId: catId,
          categoryName: name,
          iconName: icon,
          totalAmountPaise: amountPaise,
          expenseCount: count,
          percentage: percentage,
        ),
      );
    });

    results.sort((a, b) => b.totalAmountPaise.compareTo(a.totalAmountPaise));
    return results;
  }

  /// Calculates cash inflows and outflows from ledger transactions.
  CashFlowSummary calculateCashFlow({
    required List<AccountTransaction> transactions,
  }) {
    int inflow = 0;
    int outflow = 0;

    for (final tx in transactions) {
      // Exclude transfers to avoid counting internal account moves as net cash movement
      if (tx.transactionType == 'account_transfer_in' ||
          tx.transactionType == 'account_transfer_out') {
        continue;
      }

      if (tx.direction.toLowerCase() == 'inflow') {
        inflow += tx.amountPaise;
      } else if (tx.direction.toLowerCase() == 'outflow') {
        outflow += tx.amountPaise;
      }
    }

    return CashFlowSummary(
      totalInflowPaise: inflow,
      totalOutflowPaise: outflow,
      netMovementPaise: inflow - outflow,
    );
  }

  /// Calculates payables and payment history for suppliers.
  List<SupplierPayableSummary> calculateSupplierPayables({
    required List<Supplier> suppliers,
    required List<PurchaseBatch> batches,
    required List<PaymentRecord> payments,
  }) {
    final summaries = <SupplierPayableSummary>[];

    for (final supplier in suppliers) {
      final supplierBatches = batches
          .where((b) => b.supplierId == supplier.id)
          .toList();
      final totalPurchasesPaise = supplierBatches.fold<int>(
        0,
        (sum, b) => sum + b.totalAcquisitionCostPaise,
      );

      final batchIds = supplierBatches.map((b) => b.id).toSet();
      final supplierPayments = payments
          .where(
            (p) =>
                p.relatedEntityType == 'purchase_batch' &&
                batchIds.contains(p.relatedEntityId),
          )
          .toList();

      final totalPaidPaise = supplierPayments.fold<int>(
        0,
        (sum, p) => sum + p.amountPaise,
      );

      final outstandingPayablesPaise = max(
        0,
        totalPurchasesPaise - totalPaidPaise,
      );

      DateTime? lastPaymentDate;
      if (supplierPayments.isNotEmpty) {
        supplierPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        lastPaymentDate = supplierPayments.first.paymentDate;
      }

      summaries.add(
        SupplierPayableSummary(
          supplierId: supplier.id,
          supplierName: supplier.name,
          totalPurchasesPaise: totalPurchasesPaise,
          totalPaidPaise: totalPaidPaise,
          outstandingPayablesPaise: outstandingPayablesPaise,
          batchCount: supplierBatches.length,
          lastPaymentDate: lastPaymentDate,
        ),
      );
    }

    summaries.sort(
      (a, b) =>
          b.outstandingPayablesPaise.compareTo(a.outstandingPayablesPaise),
    );
    return summaries;
  }
}
