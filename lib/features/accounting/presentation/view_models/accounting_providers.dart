import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../book_fairs/domain/entities/investment.dart';
import '../../../book_fairs/domain/entities/partner.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../expenses/presentation/view_models/expense_providers.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';
import '../../../sales/presentation/view_models/sales_providers.dart';
import '../../domain/models/financial_models.dart';
import '../../domain/services/accounting_calculator.dart';

/// Provider for the pure financial calculations engine.
final accountingCalculatorProvider = Provider<AccountingCalculator>((ref) {
  return const AccountingCalculator();
});

/// Stream of partners, optionally filtered by [fairId].
final allPartnersStreamProvider = StreamProvider.family<List<Partner>, String?>(
  (ref, fairId) {
    if (fairId != null) {
      final repo = ref.watch(partnerRepositoryProvider);
      return repo.watchPartnersForFair(fairId);
    }
    final db = ref.watch(appDatabaseProvider);
    final controller = StreamController<List<Partner>>();
    List<Partner> getList() => db.partners.values
        .where((p) => p.isActive)
        .map((p) => p.toEntity())
        .toList();
    controller.add(getList());
    final sub = db.partners.watch().listen((_) {
      if (!controller.isClosed) controller.add(getList());
    });
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  },
);

/// Stream of investments, optionally filtered by [fairId].
final allInvestmentsStreamProvider =
    StreamProvider.family<List<Investment>, String?>((ref, fairId) {
      if (fairId != null) {
        final repo = ref.watch(investmentRepositoryProvider);
        return repo.watchInvestmentsForFair(fairId);
      }
      final db = ref.watch(appDatabaseProvider);
      final controller = StreamController<List<Investment>>();
      List<Investment> getList() =>
          db.investments.values.map((i) => i.toEntity()).toList();
      controller.add(getList());
      final sub = db.investments.watch().listen((_) {
        if (!controller.isClosed) controller.add(getList());
      });
      controller.onCancel = () => sub.cancel();
      return controller.stream;
    });

/// Computes comprehensive financial metrics for a selected [fairId] or all fairs.
final financialMetricsProvider = Provider.family<FinancialMetrics, String?>((
  ref,
  fairId,
) {
  final calculator = ref.watch(accountingCalculatorProvider);

  final expenses = ref.watch(expensesStreamProvider(fairId)).value ?? [];
  final accounts =
      ref.watch(cashbookAccountsStreamProvider(fairId)).value ?? [];
  final payments =
      ref
          .watch(
            paymentsStreamProvider((
              fairId: fairId,
              relatedEntityType: null,
              relatedEntityId: null,
            )),
          )
          .value ??
      [];
  final purchaseBatches =
      ref.watch(purchaseBatchesStreamProvider(fairId)).value ?? [];
  final investments =
      ref.watch(allInvestmentsStreamProvider(fairId)).value ?? [];
  final partners = ref.watch(allPartnersStreamProvider(fairId)).value ?? [];
  final receipts = ref.watch(salesReceiptsStreamProvider(fairId)).value ?? [];

  return calculator.calculateMetrics(
    expenses: expenses,
    accounts: accounts,
    payments: payments,
    purchaseBatches: purchaseBatches,
    investments: investments,
    partners: partners,
    receipts: receipts,
  );
});

/// Computes partner dues and reimbursement status for a specific [fairId].
final partnerDuesProvider = Provider.family<List<PartnerDuesSummary>, String>((
  ref,
  fairId,
) {
  final calculator = ref.watch(accountingCalculatorProvider);

  final partners = ref.watch(allPartnersStreamProvider(fairId)).value ?? [];
  final expenses = ref.watch(expensesStreamProvider(fairId)).value ?? [];
  final payments =
      ref
          .watch(
            paymentsStreamProvider((
              fairId: fairId,
              relatedEntityType: null,
              relatedEntityId: null,
            )),
          )
          .value ??
      [];
  final investments =
      ref.watch(allInvestmentsStreamProvider(fairId)).value ?? [];
  final batches = ref.watch(purchaseBatchesStreamProvider(fairId)).value ?? [];

  return calculator.calculatePartnerDues(
    partners: partners,
    expenses: expenses,
    payments: payments,
    investments: investments,
    purchaseBatches: batches,
  );
});

/// Computes category distribution breakdown for expenses in [fairId].
final categoryExpenseBreakdownProvider =
    Provider.family<List<CategoryExpenseBreakdown>, String?>((ref, fairId) {
      final calculator = ref.watch(accountingCalculatorProvider);

      final expenses = ref.watch(expensesStreamProvider(fairId)).value ?? [];
      final categories = ref.watch(expenseCategoriesStreamProvider).value ?? [];

      return calculator.calculateCategoryBreakdown(
        expenses: expenses,
        categories: categories,
      );
    });

/// Computes cash flow (inflow, outflow, net movement) from ledger transactions.
final cashFlowSummaryProvider = Provider.family<CashFlowSummary, String?>((
  ref,
  fairId,
) {
  final calculator = ref.watch(accountingCalculatorProvider);

  final txs =
      ref
          .watch(
            accountTransactionsStreamProvider((
              fairId: fairId,
              accountId: null,
            )),
          )
          .value ??
      [];

  return calculator.calculateCashFlow(transactions: txs);
});

/// Computes supplier payables and payment tracking across all suppliers.
final supplierPayablesProvider = Provider<List<SupplierPayableSummary>>((ref) {
  final calculator = ref.watch(accountingCalculatorProvider);

  final suppliers = ref.watch(suppliersStreamProvider).value ?? [];
  final batches = ref.watch(purchaseBatchesStreamProvider(null)).value ?? [];
  final payments =
      ref
          .watch(
            paymentsStreamProvider((
              fairId: null,
              relatedEntityType: 'purchase_batch',
              relatedEntityId: null,
            )),
          )
          .value ??
      [];

  return calculator.calculateSupplierPayables(
    suppliers: suppliers,
    batches: batches,
    payments: payments,
  );
});
