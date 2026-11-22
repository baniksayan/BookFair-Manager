import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/palette_switcher_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../view_models/accounting_providers.dart';

/// Screen 01: Complete Financial Accounting Dashboard consolidating investments, funds, obligations, and liabilities.
class AccountingDashboardScreen extends ConsumerStatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  ConsumerState<AccountingDashboardScreen> createState() =>
      _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState
    extends ConsumerState<AccountingDashboardScreen> {
  String? _selectedFairId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final metrics = ref.watch(financialMetricsProvider(_selectedFairId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Accounting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Financial Reports',
            onPressed: () => context.pushNamed(RouteNames.accountingReports),
          ),
          const PaletteSwitcherButton(),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.insetAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fair Selector Dropdown
                fairsAsync.when(
                  data: (fairs) {
                    if (fairs.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                      child: AppDropdown<String?>(
                        compact: true,
                        value: _selectedFairId,
                        sheetTitle: 'Select Book Fair',
                        sheetSubtitle: 'Filter accounting metrics by fair',
                        prefixIcon: const Icon(Icons.store_rounded, size: 20),
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
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Hero Capital & Liquid Funds Card
                AppCard(
                  padding: AppSpacing.insetAll16,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BUSINESS LIQUID FUNDS',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        CurrencyFormatter.formatPaise(
                          metrics.totalBusinessFundsPaise,
                        ),
                        style: textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Cash in Box',
                              value: CurrencyFormatter.formatPaise(
                                metrics.totalCashBalancePaise,
                              ),
                              color: colors.primary,
                              context: context,
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
                            child: _buildMetricTile(
                              label: 'UPI / Online',
                              value: CurrencyFormatter.formatPaise(
                                metrics.totalUpiBalancePaise,
                              ),
                              color: colors.warning,
                              context: context,
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
                            child: _buildMetricTile(
                              label: 'Bank Accounts',
                              value: CurrencyFormatter.formatPaise(
                                metrics.totalBankBalancePaise,
                              ),
                              color: colors.success,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Sales & Real-Time Profitability Card (Stage 05)
                AppCard(
                  padding: AppSpacing.insetAll16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SALES & PROFITABILITY',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: AppSpacing.s2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (metrics.netProfitPaise >= 0
                                          ? colors.success
                                          : colors.error)
                                      .withValues(alpha: 0.15),
                              borderRadius: AppRadius.brSmall,
                            ),
                            child: Text(
                              'Margin: ${metrics.grossMarginPercentage.toStringAsFixed(1)}%',
                              style: textTheme.labelSmall?.copyWith(
                                color: metrics.netProfitPaise >= 0
                                    ? colors.success
                                    : colors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Net Profit',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    metrics.netProfitPaise,
                                  ),
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: metrics.netProfitPaise >= 0
                                        ? colors.success
                                        : colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gross Profit',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    metrics.grossProfitPaise,
                                  ),
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.s24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Net Revenue',
                              value: CurrencyFormatter.formatPaise(
                                metrics.netSalesRevenuePaise,
                              ),
                              color: colors.primary,
                              context: context,
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
                            child: _buildMetricTile(
                              label: 'COGS',
                              value: CurrencyFormatter.formatPaise(
                                metrics.totalCogsPaise,
                              ),
                              color: colors.warning,
                              context: context,
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
                            child: _buildMetricTile(
                              label: 'Gross Sales',
                              value: CurrencyFormatter.formatPaise(
                                metrics.totalGrossSalesPaise,
                              ),
                              color: colors.info,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Capital & Outlay Row
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.insetAll16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL INVESTMENT',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Text(
                              CurrencyFormatter.formatPaise(
                                metrics.totalInvestmentPaise,
                              ),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Partner Capital',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.insetAll16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PURCHASE OUTLAY',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Text(
                              CurrencyFormatter.formatPaise(
                                metrics.totalPurchaseOutlayPaise,
                              ),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Paid: ${CurrencyFormatter.formatPaise(metrics.totalPaidPurchaseOutlayPaise)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.success,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),

                // Operational Expenses Row
                AppCard(
                  padding: AppSpacing.insetAll16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'OPERATING EXPENSES',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.pushNamed(RouteNames.expenses),
                            child: const Text('Manage Expenses'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        CurrencyFormatter.formatPaise(
                          metrics.totalExpensesPaise,
                        ),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Paid: ${CurrencyFormatter.formatPaise(metrics.paidExpensesPaise)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Outstanding: ${CurrencyFormatter.formatPaise(metrics.outstandingExpensesPaise)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: metrics.outstandingExpensesPaise > 0
                                    ? colors.error
                                    : colors.onSurfaceMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Liabilities Section
                Text(
                  'Outstanding Liabilities & Payables',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.insetAll16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUPPLIER PAYABLES',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Text(
                              CurrencyFormatter.formatPaise(
                                metrics.totalSupplierPayablesPaise,
                              ),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: metrics.totalSupplierPayablesPaise > 0
                                    ? colors.error
                                    : colors.success,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Book Vendor Dues',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.insetAll16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PARTNER DUES',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Text(
                              CurrencyFormatter.formatPaise(
                                metrics.totalPartnerReimbursementLiabilityPaise,
                              ),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    metrics.totalPartnerReimbursementLiabilityPaise >
                                        0
                                    ? colors.warning
                                    : colors.success,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Personal Outlays',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // Navigation Quick Links
                AppCard(
                  padding: AppSpacing.insetAll12,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.analytics_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        title: const Text('Financial Reports'),
                        subtitle: const Text(
                          'Category breakdowns, cash flows & payables',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () =>
                            context.pushNamed(RouteNames.accountingReports),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colors.warning,
                            size: 20,
                          ),
                        ),
                        title: const Text('Cashbook & Accounts'),
                        subtitle: const Text(
                          'Manage cashboxes, UPI accounts & transfers',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => context.pushNamed(RouteNames.cashbook),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),

                // Accounting Rules Disclaimer
                AppCard(
                  padding: AppSpacing.insetAll12,
                  backgroundColor: colors.surfaceContainer,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        size: 18,
                        color: colors.onSurfaceMuted,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          'Offline-first accounting integrity: Net profit = Net Sales Revenue - COGS - Realized Fair Expenses. Investments are treated as capital additions (not revenue), and partner reimbursements do not count as duplicate operating expenses.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
