import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book.dart';
import '../../domain/services/inventory_cost_calculator.dart';
import '../view_models/inventory_providers.dart';
import '../widgets/stock_movement_dialog.dart';

/// Screen 04: Comprehensive Book Details, Financial Margin Analysis, and Stock History.
class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final bookAsync = ref.watch(bookDetailsStreamProvider(bookId));
    final movementsAsync = ref.watch(bookStockMovementsStreamProvider(bookId));

    return Scaffold(
      appBar: AppAppBar(
        title: 'Book Details',
        subtitle: 'Inventory ledger & margin analytics',
        actions: [
          IconButton(
            tooltip: 'Edit Book Details',
            icon: Icon(Icons.edit_outlined, color: colors.textPrimary),
            onPressed: () => context.push('/inventory/books/$bookId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: bookAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading book specifications...',
              ),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: colors.error)),
            ),
            data: (book) {
              if (book == null) {
                return Center(
                  child: Text(
                    'Book record not found.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                );
              }

              final movements = movementsAsync.value ?? [];
              final availableStock =
                  InventoryCostCalculator.calculateAvailableStock(movements);

              // Calculate perpetual weighted average cost
              final avgCostPaise =
                  book.estimatedCostPaise ??
                  (book.mrpPaise > 0 ? (book.mrpPaise * 0.4).round() : 0);

              final pricingAnalysis = InventoryCostCalculator.analyzePricing(
                mrpPaise: book.mrpPaise,
                sellingPricePaise: book.defaultSellingPricePaise,
                averageCostPaise: avgCostPaise,
              );

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64.0,
                            height: 96.0,
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: AppRadius.brMedium,
                              border: Border.all(
                                color: colors.border,
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: colors.primary,
                                size: 32.0,
                              ),
                            ),
                          ),
                          AppSpacing.gapW16,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    AppBadge(
                                      label: book.condition.displayName
                                          .toUpperCase(),
                                      variant:
                                          book.condition ==
                                              BookCondition.brandNew
                                          ? AppBadgeVariant.primary
                                          : AppBadgeVariant.neutral,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 3.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: availableStock > 0
                                            ? colors.surface
                                            : colors.error,
                                        borderRadius: AppRadius.brSmall,
                                        border: Border.all(
                                          color: availableStock > 0
                                              ? colors.border
                                              : colors.error,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        '$availableStock COPIES AVAILABLE',
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w700,
                                          color: availableStock > 0
                                              ? colors.textPrimary
                                              : (colors.isDark
                                                    ? AppColors.c03071E
                                                    : AppColors.cFFFFFF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.gapH6,
                                Text(
                                  book.title,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Georgia',
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (book.subtitle?.isNotEmpty == true) ...[
                                  AppSpacing.gapH2,
                                  Text(
                                    book.subtitle!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                AppSpacing.gapH4,
                                Text(
                                  'by ${book.author}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if (book.publisher.isNotEmpty)
                                  Text(
                                    'Publisher: ${book.publisher}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                if (book.primaryIsbn != null)
                                  Text(
                                    'ISBN: ${book.primaryIsbn}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapH16,

                    // Commercial Financial Pricing Grid
                    Text(
                      'Commercial Pricing & Profit Analytics',
                      style: textTheme.titleSmall?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    AppSpacing.gapH12,
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinancialCell(
                            context,
                            label: 'LISTING MRP',
                            value: CurrencyFormatter.format(book.mrp),
                            caption: 'Catalogue Benchmark',
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: _buildFinancialCell(
                            context,
                            label: 'SELLING PRICE',
                            value: CurrencyFormatter.format(
                              book.defaultSellingPrice,
                            ),
                            caption:
                                '${pricingAnalysis.discountPercentage.round()}% Discount Applied',
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH12,
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinancialCell(
                            context,
                            label: 'WEIGHTED AVG COST',
                            value: CurrencyFormatter.format(
                              pricingAnalysis.averageCost,
                            ),
                            caption: book.isPreviousStock
                                ? 'Est. Opening Acquisition'
                                : 'Perpetual Weighted Unit Cost',
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: _buildFinancialCell(
                            context,
                            label: 'EXPECTED GROSS PROFIT',
                            value: CurrencyFormatter.format(
                              pricingAnalysis.expectedGrossProfit,
                            ),
                            caption:
                                '${pricingAnalysis.grossMarginPercentage}% Gross Margin',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH24,

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.outlined(
                            text: 'Adjust Stock',
                            icon: Icons.tune_rounded,
                            onPressed: () => StockMovementDialog.show(
                              context,
                              book: book,
                              currentStock: availableStock,
                            ),
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: AppButton(
                            text: 'Edit Book',
                            icon: Icons.edit_rounded,
                            onPressed: () =>
                                context.push('/inventory/books/$bookId/edit'),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH28,

                    // Stock Movement History Section
                    Text(
                      'Stock Movement Audit Ledger (${movements.length})',
                      style: textTheme.titleSmall?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    AppSpacing.gapH12,

                    if (movements.isEmpty)
                      AppCard(
                        padding: AppSpacing.insetAll24,
                        child: Center(
                          child: Text(
                            'No stock movements recorded yet.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: movements.length,
                        separatorBuilder: (context, index) => AppSpacing.gapH8,
                        itemBuilder: (context, index) {
                          final movement = movements[index];
                          final isPos = movement.netDelta > 0;

                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPos
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isPos
                                      ? colors.primary
                                      : colors.warning,
                                  size: 18.0,
                                ),
                                AppSpacing.gapW12,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movement.movementType.displayName,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      if (movement.notes.isNotEmpty)
                                        Text(
                                          movement.notes,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 11.0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isPos ? '+' : ''}${movement.netDelta} qty',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isPos
                                        ? colors.primary
                                        : colors.warning,
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

  Widget _buildFinancialCell(
    BuildContext context, {
    required String label,
    required String value,
    required String caption,
    bool isHighlighted = false,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: AppSpacing.insetAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          AppSpacing.gapH6,
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isHighlighted ? colors.primary : colors.textPrimary,
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
}
