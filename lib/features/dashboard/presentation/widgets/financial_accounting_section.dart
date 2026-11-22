import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../accounting/presentation/view_models/accounting_providers.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';

/// Dashboard integration section presenting real-time Stage 04 financial accounting indicators.
class FinancialAccountingSection extends ConsumerStatefulWidget {
  const FinancialAccountingSection({super.key});

  @override
  ConsumerState<FinancialAccountingSection> createState() =>
      _FinancialAccountingSectionState();
}

class _FinancialAccountingSectionState
    extends ConsumerState<FinancialAccountingSection> {
  String? _selectedFairId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final metrics = ref.watch(financialMetricsProvider(_selectedFairId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Financial Accounting & Cashbook',
                  style: textTheme.titleLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => context.pushNamed(RouteNames.accounting),
                child: const Text('Full View'),
              ),
            ],
          ),
          AppSpacing.gapH4,
          Text(
            'Liquid balances, outlays, payables & reimbursement dues',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          AppSpacing.gapH12,

          // Fair Filter
          fairsAsync.when(
            data: (fairs) {
              if (fairs.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: AppRadius.brSmall,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedFairId,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'All Book Fairs (Consolidated)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...fairs.map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              f.name,
                              style: const TextStyle(fontSize: 13),
                            ),
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

          // Liquid Funds Card
          AppCard.interactive(
            onTap: () => context.pushNamed(RouteNames.cashbook),
            padding: AppSpacing.insetAll16,
            backgroundColor: colors.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL BUSINESS FUNDS',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  CurrencyFormatter.formatPaise(
                    metrics.totalBusinessFundsPaise,
                  ),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceItem(
                        label: 'Cash',
                        value: CurrencyFormatter.formatPaise(
                          metrics.totalCashBalancePaise,
                        ),
                        color: colors.primary,
                        context: context,
                      ),
                    ),
                    Expanded(
                      child: _buildBalanceItem(
                        label: 'UPI',
                        value: CurrencyFormatter.formatPaise(
                          metrics.totalUpiBalancePaise,
                        ),
                        color: colors.warning,
                        context: context,
                      ),
                    ),
                    Expanded(
                      child: _buildBalanceItem(
                        label: 'Bank',
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
          const SizedBox(height: AppSpacing.s12),

          // Outlay & Obligations Row
          Row(
            children: [
              Expanded(
                child: AppCard.interactive(
                  onTap: () => context.pushNamed(RouteNames.expenses),
                  padding: AppSpacing.insetAll12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSES',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        CurrencyFormatter.formatPaise(
                          metrics.totalExpensesPaise,
                        ),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Due: ${CurrencyFormatter.formatPaise(metrics.outstandingExpensesPaise)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: metrics.outstandingExpensesPaise > 0
                              ? colors.error
                              : colors.success,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: AppCard.interactive(
                  onTap: () => context.pushNamed(RouteNames.accountingReports),
                  padding: AppSpacing.insetAll12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PURCHASES',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        CurrencyFormatter.formatPaise(
                          metrics.totalPurchaseOutlayPaise,
                        ),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Payable: ${CurrencyFormatter.formatPaise(metrics.totalSupplierPayablesPaise)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: metrics.totalSupplierPayablesPaise > 0
                              ? colors.error
                              : colors.success,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: AppCard.interactive(
                  onTap: () {
                    if (_selectedFairId != null) {
                      context.pushNamed(
                        RouteNames.partnerDues,
                        pathParameters: {'id': _selectedFairId!},
                      );
                    } else {
                      context.pushNamed(RouteNames.accounting);
                    }
                  },
                  padding: AppSpacing.insetAll12,
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
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        CurrencyFormatter.formatPaise(
                          metrics.totalPartnerReimbursementLiabilityPaise,
                        ),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              metrics.totalPartnerReimbursementLiabilityPaise >
                                  0
                              ? colors.warning
                              : colors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Reimbursements',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem({
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
              width: 6,
              height: 6,
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
        const SizedBox(height: AppSpacing.s2),
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
