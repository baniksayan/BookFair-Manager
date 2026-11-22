import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_progress_bar.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../view_models/accounting_providers.dart';

/// Screen 02: Analytical financial reports covering category distributions, cash flows, and obligations.
class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends ConsumerState<FinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedFairId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final categoryBreakdowns = ref.watch(
      categoryExpenseBreakdownProvider(_selectedFairId),
    );
    final cashFlow = ref.watch(cashFlowSummaryProvider(_selectedFairId));
    final supplierPayables = ref.watch(supplierPayablesProvider);
    final partnerDues = _selectedFairId != null
        ? ref.watch(partnerDuesProvider(_selectedFairId!))
        : const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceMuted,
          indicatorColor: colors.primary,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Cash Flow'),
            Tab(text: 'Supplier Payables'),
            Tab(text: 'Partner Dues'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              // Fair Selector Header
              fairsAsync.when(
                data: (fairs) {
                  if (fairs.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s16,
                      AppSpacing.s4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: AppRadius.brMedium,
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedFairId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Book Fairs Combined',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            ...fairs.map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(f.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedFairId = val);
                          },
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Categories
                    _buildCategoryReport(categoryBreakdowns, colors, textTheme),

                    // Tab 2: Cash Flow
                    _buildCashFlowReport(cashFlow, colors, textTheme),

                    // Tab 3: Supplier Payables
                    _buildSupplierReport(supplierPayables, colors, textTheme),

                    // Tab 4: Partner Dues
                    _buildPartnerDuesReport(partnerDues, colors, textTheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryReport(
    List<dynamic> breakdowns,
    AppColorScheme colors,
    TextTheme textTheme,
  ) {
    if (breakdowns.isEmpty) {
      return const AppEmptyState(
        title: 'No Expense Distribution',
        description: 'Record operating expenses to see category breakdowns.',
        icon: Icons.pie_chart_outline_rounded,
      );
    }

    return ListView.builder(
      padding: AppSpacing.insetAll16,
      itemCount: breakdowns.length,
      itemBuilder: (context, index) {
        final item = breakdowns[index];
        final fraction = (item.percentage / 100.0).clamp(0.0, 1.0);

        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: AppSpacing.insetAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.categoryName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(item.totalAmountPaise),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.expenseCount} record(s)',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    '${item.percentage.toStringAsFixed(1)}%',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              AppProgressBar(
                value: fraction,
                fillColor: colors.primary,
                trackColor: colors.surfaceSecondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashFlowReport(
    dynamic flow,
    AppColorScheme colors,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: AppSpacing.insetAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: AppSpacing.insetAll16,
            backgroundColor: colors.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NET CASHFLOW MOVEMENT',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceMuted,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  CurrencyFormatter.formatPaise(flow.netMovementPaise),
                  style: textTheme.headlineMedium?.copyWith(
                    color: flow.netMovementPaise >= 0
                        ? colors.success
                        : colors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Inflows',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            CurrencyFormatter.formatPaise(
                              flow.totalInflowPaise,
                            ),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: colors.borderSubtle,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outflows',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            CurrencyFormatter.formatPaise(
                              flow.totalOutflowPaise,
                            ),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            padding: AppSpacing.insetAll12,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    'Internal transfers between cash and bank accounts are excluded from net inflows and outflows to maintain audit clarity.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierReport(
    List<dynamic> suppliers,
    AppColorScheme colors,
    TextTheme textTheme,
  ) {
    if (suppliers.isEmpty) {
      return const AppEmptyState(
        title: 'No Supplier Obligations',
        description: 'Book acquisition batches from suppliers will be listed here with pending balances.',
        icon: Icons.local_shipping_outlined,
      );
    }

    return ListView.builder(
      padding: AppSpacing.insetAll16,
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final s = suppliers[index];

        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: AppSpacing.insetAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s.supplierName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  AppBadge(
                    label: s.outstandingPayablesPaise > 0
                        ? 'Dues Pending'
                        : 'Settled',
                    variant: s.outstandingPayablesPaise > 0
                        ? AppBadgeVariant.warning
                        : AppBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Purchases: ${CurrencyFormatter.formatPaise(s.totalPurchasesPaise)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'Paid: ${CurrencyFormatter.formatPaise(s.totalPaidPaise)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${s.batchCount} batch(es)',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'Payable: ${CurrencyFormatter.formatPaise(s.outstandingPayablesPaise)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: s.outstandingPayablesPaise > 0
                          ? colors.error
                          : colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerDuesReport(
    List<dynamic> dues,
    AppColorScheme colors,
    TextTheme textTheme,
  ) {
    if (dues.isEmpty) {
      return const AppEmptyState(
        title: 'Select a Book Fair',
        description: 'Partner dues and reimbursement schedules are tracked per Book Fair. Select a fair from the selector above.',
        icon: Icons.handshake_outlined,
      );
    }

    return ListView.builder(
      padding: AppSpacing.insetAll16,
      itemCount: dues.length,
      itemBuilder: (context, index) {
        final d = dues[index];

        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: AppSpacing.insetAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    d.partnerName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  AppBadge(
                    label: d.outstandingReimbursementPaise > 0
                        ? 'Liability Pending'
                        : 'Settled',
                    variant: d.outstandingReimbursementPaise > 0
                        ? AppBadgeVariant.warning
                        : AppBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                'Personal Outlay: ${CurrencyFormatter.formatPaise(d.personallyPaidPaise)} • Reimbursed: ${CurrencyFormatter.formatPaise(d.reimbursedPaise)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Outstanding Reimbursement Due: ${CurrencyFormatter.formatPaise(d.outstandingReimbursementPaise)}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: d.outstandingReimbursementPaise > 0
                      ? colors.error
                      : colors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
