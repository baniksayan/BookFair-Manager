import 'package:flutter/foundation.dart';

/// Aggregated financial metrics for a specific Book Fair or across all Fairs.
@immutable
class FinancialMetrics {
  const FinancialMetrics({
    required this.totalExpensesPaise,
    required this.paidExpensesPaise,
    required this.outstandingExpensesPaise,
    required this.totalBusinessFundsPaise,
    required this.totalCashBalancePaise,
    required this.totalUpiBalancePaise,
    required this.totalBankBalancePaise,
    required this.totalPartnerReimbursementLiabilityPaise,
    required this.totalSupplierPayablesPaise,
    required this.totalInvestmentPaise,
    required this.totalPurchaseOutlayPaise,
    required this.totalPaidPurchaseOutlayPaise,
    this.totalGrossSalesPaise = 0,
    this.totalSalesRefundsPaise = 0,
    this.netSalesRevenuePaise = 0,
    this.totalCogsPaise = 0,
    this.provisionalCogsPaise = 0,
    this.grossProfitPaise = 0,
    this.grossMarginPercentage = 0.0,
    this.netProfitPaise = 0,
    this.totalReceiptsCount = 0,
    this.totalUnitsSold = 0,
    this.cashSalesCollectionPaise = 0,
    this.upiSalesCollectionPaise = 0,
    this.otherSalesCollectionPaise = 0,
  });

  final int totalExpensesPaise;
  final int paidExpensesPaise;
  final int outstandingExpensesPaise;

  final int totalBusinessFundsPaise;
  final int totalCashBalancePaise;
  final int totalUpiBalancePaise;
  final int totalBankBalancePaise;

  final int totalPartnerReimbursementLiabilityPaise;
  final int totalSupplierPayablesPaise;
  final int totalInvestmentPaise;
  final int totalPurchaseOutlayPaise;
  final int totalPaidPurchaseOutlayPaise;

  // --- Stage 05 Sales & Realized Profit Analytics ---
  final int totalGrossSalesPaise;
  final int totalSalesRefundsPaise;
  final int netSalesRevenuePaise;
  final int totalCogsPaise;
  final int provisionalCogsPaise;
  final int grossProfitPaise;
  final double grossMarginPercentage;
  final int netProfitPaise;
  final int totalReceiptsCount;
  final int totalUnitsSold;
  final int cashSalesCollectionPaise;
  final int upiSalesCollectionPaise;
  final int otherSalesCollectionPaise;

  // Rupee conversions
  double get totalExpenses => totalExpensesPaise / 100.0;
  double get paidExpenses => paidExpensesPaise / 100.0;
  double get outstandingExpenses => outstandingExpensesPaise / 100.0;
  double get totalBusinessFunds => totalBusinessFundsPaise / 100.0;
  double get totalCashBalance => totalCashBalancePaise / 100.0;
  double get totalUpiBalance => totalUpiBalancePaise / 100.0;
  double get totalBankBalance => totalBankBalancePaise / 100.0;
  double get totalPartnerReimbursementLiability =>
      totalPartnerReimbursementLiabilityPaise / 100.0;
  double get totalSupplierPayables => totalSupplierPayablesPaise / 100.0;
  double get totalInvestment => totalInvestmentPaise / 100.0;
  double get totalPurchaseOutlay => totalPurchaseOutlayPaise / 100.0;
  double get totalPaidPurchaseOutlay => totalPaidPurchaseOutlayPaise / 100.0;

  // Stage 05 Rupee getters
  double get totalGrossSales => totalGrossSalesPaise / 100.0;
  double get totalSalesRefunds => totalSalesRefundsPaise / 100.0;
  double get netSalesRevenue => netSalesRevenuePaise / 100.0;
  double get totalCogs => totalCogsPaise / 100.0;
  double get provisionalCogs => provisionalCogsPaise / 100.0;
  double get grossProfit => grossProfitPaise / 100.0;
  double get netProfit => netProfitPaise / 100.0;
  double get cashSalesCollection => cashSalesCollectionPaise / 100.0;
  double get upiSalesCollection => upiSalesCollectionPaise / 100.0;
  double get otherSalesCollection => otherSalesCollectionPaise / 100.0;

  static const empty = FinancialMetrics(
    totalExpensesPaise: 0,
    paidExpensesPaise: 0,
    outstandingExpensesPaise: 0,
    totalBusinessFundsPaise: 0,
    totalCashBalancePaise: 0,
    totalUpiBalancePaise: 0,
    totalBankBalancePaise: 0,
    totalPartnerReimbursementLiabilityPaise: 0,
    totalSupplierPayablesPaise: 0,
    totalInvestmentPaise: 0,
    totalPurchaseOutlayPaise: 0,
    totalPaidPurchaseOutlayPaise: 0,
  );
}

/// Dues and reimbursement breakdown for an individual partner.
@immutable
class PartnerDuesSummary {
  const PartnerDuesSummary({
    required this.partnerId,
    required this.partnerName,
    required this.role,
    required this.personallyPaidPaise,
    required this.reimbursedPaise,
    required this.outstandingReimbursementPaise,
    required this.totalCapitalInvestedPaise,
  });

  final String partnerId;
  final String partnerName;
  final String role;
  final int personallyPaidPaise;
  final int reimbursedPaise;
  final int outstandingReimbursementPaise;
  final int totalCapitalInvestedPaise;

  int get totalBusinessContributionsPaise =>
      personallyPaidPaise + totalCapitalInvestedPaise;

  double get personallyPaid => personallyPaidPaise / 100.0;
  double get reimbursed => reimbursedPaise / 100.0;
  double get outstandingReimbursement => outstandingReimbursementPaise / 100.0;
  double get totalCapitalInvested => totalCapitalInvestedPaise / 100.0;
  double get totalBusinessContributions =>
      totalBusinessContributionsPaise / 100.0;
}

/// Category-wise expense distribution summary.
@immutable
class CategoryExpenseBreakdown {
  const CategoryExpenseBreakdown({
    required this.categoryId,
    required this.categoryName,
    this.iconName,
    required this.totalAmountPaise,
    required this.expenseCount,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final String? iconName;
  final int totalAmountPaise;
  final int expenseCount;
  final double percentage;

  double get totalAmount => totalAmountPaise / 100.0;
}

/// Summary of cash inflows and outflows derived from account transactions.
@immutable
class CashFlowSummary {
  const CashFlowSummary({
    required this.totalInflowPaise,
    required this.totalOutflowPaise,
    required this.netMovementPaise,
  });

  final int totalInflowPaise;
  final int totalOutflowPaise;
  final int netMovementPaise;

  double get totalInflow => totalInflowPaise / 100.0;
  double get totalOutflow => totalOutflowPaise / 100.0;
  double get netMovement => netMovementPaise / 100.0;

  static const empty = CashFlowSummary(
    totalInflowPaise: 0,
    totalOutflowPaise: 0,
    netMovementPaise: 0,
  );
}

/// Supplier payable summary detailing purchase totals and pending dues.
@immutable
class SupplierPayableSummary {
  const SupplierPayableSummary({
    required this.supplierId,
    required this.supplierName,
    required this.totalPurchasesPaise,
    required this.totalPaidPaise,
    required this.outstandingPayablesPaise,
    required this.batchCount,
    this.lastPaymentDate,
  });

  final String supplierId;
  final String supplierName;
  final int totalPurchasesPaise;
  final int totalPaidPaise;
  final int outstandingPayablesPaise;
  final int batchCount;
  final DateTime? lastPaymentDate;

  double get totalPurchases => totalPurchasesPaise / 100.0;
  double get totalPaid => totalPaidPaise / 100.0;
  double get outstandingPayables => outstandingPayablesPaise / 100.0;
}
