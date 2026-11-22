import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../view_models/sales_providers.dart';

/// Screen 07: Comprehensive point-of-sale history, filterable receipts, and sales ledger.
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  String? _selectedFairId;
  String _selectedStatusFilter = 'all'; // 'all', 'paid', 'refunded'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final receiptsAsync = ref.watch(
      salesReceiptsStreamProvider(_selectedFairId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Register & Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale_outlined),
            tooltip: 'Launch POS Counter',
            onPressed: () => context.pushNamed(RouteNames.posSalesCounter),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              // Fair Filter Header
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
                    child: AppDropdown<String?>(
                      compact: true,
                      value: _selectedFairId,
                      sheetTitle: 'Select Book Fair',
                      sheetSubtitle: 'Filter sales history by fair',
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

              // Status Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Receipts'),
                      selected: _selectedStatusFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = 'all'),
                    ),
                    AppSpacing.gapW8,
                    FilterChip(
                      label: const Text('Paid'),
                      selected: _selectedStatusFilter == 'paid',
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = 'paid'),
                    ),
                    AppSpacing.gapW8,
                    FilterChip(
                      label: const Text('Refunded'),
                      selected: _selectedStatusFilter == 'refunded',
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = 'refunded'),
                    ),
                  ],
                ),
              ),

              // Receipt List
              Expanded(
                child: receiptsAsync.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (err, _) =>
                      Center(child: Text('Error loading sales: $err')),
                  data: (allReceipts) {
                    var filtered = allReceipts;
                    if (_selectedStatusFilter == 'paid') {
                      filtered = filtered
                          .where((r) => r.paymentStatus == 'paid')
                          .toList();
                    } else if (_selectedStatusFilter == 'refunded') {
                      filtered = filtered.where((r) => r.hasRefunds).toList();
                    }

                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Sales Recorded',
                        description: _selectedFairId != null
                            ? 'No transactions recorded for this book fair yet. Launch the POS counter to bill items.'
                            : 'No customer sales receipts found. Launch the POS register to start billing.',
                        actionLabel: 'Open POS Sales Counter',
                        onAction: () =>
                            context.pushNamed(RouteNames.posSalesCounter),
                      );
                    }

                    // Compute aggregate summary metrics
                    final totalRevenue = filtered.fold<int>(
                      0,
                      (sum, r) => sum + r.totalAmountPaise,
                    );
                    final totalRefunded = filtered.fold<int>(
                      0,
                      (sum, r) => sum + r.refundedAmountPaise,
                    );
                    final netRevenue = totalRevenue - totalRefunded;

                    return Column(
                      children: [
                        // Metric summary strip
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s4,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: AppRadius.brMedium,
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem(
                                'Gross Sales',
                                CurrencyFormatter.format(totalRevenue / 100.0),
                                textTheme,
                                colors.primary,
                              ),
                              _buildMetricItem(
                                'Receipts',
                                '${filtered.length}',
                                textTheme,
                                colors.onSurface,
                              ),
                              _buildMetricItem(
                                'Net Revenue',
                                CurrencyFormatter.format(netRevenue / 100.0),
                                textTheme,
                                colors.success,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH8,

                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final receipt = filtered[index];
                              return AppCard(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.s8,
                                ),
                                onTap: () => context.pushNamed(
                                  RouteNames.saleReceiptDetails,
                                  pathParameters: {'id': receipt.id},
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.s10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: AppRadius.brSmall,
                                      ),
                                      child: Icon(
                                        Icons.receipt_outlined,
                                        color: colors.primary,
                                      ),
                                    ),
                                    AppSpacing.gapW12,
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            receipt.receiptNumber,
                                            style: textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          AppSpacing.gapH2,
                                          Text(
                                            '${DateFormatter.formatDate(receipt.createdAt)} • ${receipt.cashierName}',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colors.onSurfaceMuted,
                                                ),
                                          ),
                                          if (receipt.customerName != null) ...[
                                            AppSpacing.gapH2,
                                            Text(
                                              'Customer: ${receipt.customerName}',
                                              style: textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(
                                            receipt.total,
                                          ),
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        AppSpacing.gapH4,
                                        AppBadge(
                                          label: receipt.paymentStatus
                                              .toUpperCase(),
                                          variant: receipt.isFullyRefunded
                                              ? AppBadgeVariant.error
                                              : (receipt.isPartiallyRefunded
                                                    ? AppBadgeVariant.warning
                                                    : AppBadgeVariant.success),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.point_of_sale_outlined),
        label: const Text('POS Counter'),
        onPressed: () => context.pushNamed(RouteNames.posSalesCounter),
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    TextTheme textTheme,
    Color color,
  ) {
    return Column(
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(fontSize: 11)),
        AppSpacing.gapH2,
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
