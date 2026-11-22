import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/palette_switcher_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../view_models/inventory_dashboard_view_model.dart';
import '../view_models/inventory_providers.dart';

/// Screen 01: Inventory Dashboard & Operational Stock Control Center.
class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final summaryAsync = ref.watch(inventoryDashboardSummaryProvider(null));
    final booksAsync = ref.watch(booksStreamProvider(null));
    final batchesAsync = ref.watch(purchaseBatchesStreamProvider(null));

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: summaryAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Calculating stock valuations...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading inventory: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (summary) {
              final books = booksAsync.value ?? [];
              final batches = batchesAsync.value ?? [];

              if (books.isEmpty && batches.isEmpty) {
                return _buildEmptyState(context);
              }

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Inventory Control',
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontFamily: 'Georgia',
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                AppSpacing.gapW8,
                                AppBadge(
                                  label: '${summary.totalUniqueTitles} TITLES',
                                  variant: AppBadgeVariant.primary,
                                ),
                              ],
                            ),
                            AppSpacing.gapH4,
                            Text(
                              'Stall catalogue, purchase batches & stock ledger',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const PaletteSwitcherButton(compact: true),
                      ],
                    ),
                    AppSpacing.gapH20,

                    // Key Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'TOTAL TITLES',
                            value: '${summary.totalUniqueTitles}',
                            icon: Icons.auto_stories_rounded,
                            caption: 'Master Catalog',
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'PURCHASE VALUE',
                            value: CurrencyFormatter.format(
                              summary.totalPurchaseValue,
                            ),
                            icon: Icons.receipt_long_rounded,
                            caption: 'Acquisition Outlay',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH12,
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'STOCK VALUATION',
                            value: CurrencyFormatter.format(
                              summary.currentStockValuation,
                            ),
                            icon: Icons.account_balance_wallet_rounded,
                            caption: 'Asset Ledger',
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'PURCHASE BATCHES',
                            value: '${batches.length}',
                            icon: Icons.inventory_2_rounded,
                            caption: 'Vendor Tranches',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH24,

                    // Quick Actions Hub
                    Text(
                      'Operational Workflows',
                      style: textTheme.titleSmall?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    AppSpacing.gapH12,
                    Wrap(
                      spacing: AppSpacing.s12,
                      runSpacing: AppSpacing.s12,
                      children: [
                        _buildActionPill(
                          context,
                          label: 'Book Catalogue',
                          icon: Icons.menu_book_rounded,
                          onTap: () => context.push('/inventory/books'),
                        ),
                        _buildActionPill(
                          context,
                          label: 'Add Book Title',
                          icon: Icons.add_circle_outline_rounded,
                          onTap: () => context.push('/inventory/books/create'),
                        ),
                        _buildActionPill(
                          context,
                          label: 'New Purchase Batch',
                          icon: Icons.post_add_rounded,
                          isProminent: true,
                          onTap: () =>
                              context.push('/inventory/purchases/create'),
                        ),
                        _buildActionPill(
                          context,
                          label: 'Purchase History',
                          icon: Icons.history_rounded,
                          onTap: () => context.push('/inventory/purchases'),
                        ),
                        _buildActionPill(
                          context,
                          label: 'Suppliers & Vendors',
                          icon: Icons.local_shipping_outlined,
                          onTap: () => context.push('/inventory/suppliers'),
                        ),
                      ],
                    ),
                    AppSpacing.gapH28,

                    // Recent Purchase Batches Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Purchase Batches',
                          style: textTheme.titleSmall?.copyWith(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (batches.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                context.push('/inventory/purchases'),
                            child: Text(
                              'View All (${batches.length})',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                    AppSpacing.gapH12,

                    if (batches.isEmpty)
                      AppCard(
                        padding: AppSpacing.insetAll24,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 36.0,
                                color: colors.textSecondary,
                              ),
                              AppSpacing.gapH8,
                              Text(
                                'No Purchase Batches Yet',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Text(
                                'Create a purchase batch to log acquired inventory.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: batches.take(5).length,
                        separatorBuilder: (context, index) => AppSpacing.gapH12,
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          return AppCard(
                            padding: AppSpacing.insetAll16,
                            child: Row(
                              children: [
                                Container(
                                  padding: AppSpacing.insetAll10,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSecondary,
                                    borderRadius: AppRadius.brMedium,
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: colors.primary,
                                    size: 20.0,
                                  ),
                                ),
                                AppSpacing.gapW12,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        batch.invoiceNumber?.isNotEmpty == true
                                            ? 'Invoice #${batch.invoiceNumber}'
                                            : 'Batch (${batch.totalQuantity} copies)',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      AppSpacing.gapH2,
                                      Text(
                                        'Payment: ${batch.paymentMethod} • ${batch.paymentStatus}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 11.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    batch.totalAcquisitionCost,
                                  ),
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    AppSpacing.gapH32,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory Ledger Empty',
      description: 'Establish your book catalogue or record your first vendor purchase batch to track titles, copies, and weighted costs.',
      actionLabel: 'Create First Purchase Batch',
      onAction: () => context.push('/inventory/purchases/create'),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required String caption,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: AppSpacing.insetAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 9.0,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(icon, size: 16.0, color: colors.primary),
            ],
          ),
          AppSpacing.gapH8,
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          AppSpacing.gapH2,
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isProminent = false,
  }) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brLarge,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isProminent ? colors.primary : colors.surface,
          borderRadius: AppRadius.brLarge,
          border: Border.all(
            color: isProminent ? colors.primary : colors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: isProminent
                  ? (colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF)
                  : colors.primary,
            ),
            AppSpacing.gapW8,
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: isProminent
                    ? (colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF)
                    : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
