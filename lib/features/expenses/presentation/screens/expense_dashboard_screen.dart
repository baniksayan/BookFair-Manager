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
import '../../../../core/components/palette_switcher_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../domain/entities/expense.dart';
import '../view_models/expense_providers.dart';

/// Screen 01: Expense Dashboard displaying key metrics, breakdowns and recent expenses.
class ExpenseDashboardScreen extends ConsumerStatefulWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  ConsumerState<ExpenseDashboardScreen> createState() =>
      _ExpenseDashboardScreenState();
}

class _ExpenseDashboardScreenState
    extends ConsumerState<ExpenseDashboardScreen> {
  String? _selectedFairId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider(_selectedFairId));
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Expense History',
            onPressed: () => context.pushNamed(RouteNames.expenseHistory),
          ),
          const PaletteSwitcherButton(),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(
          RouteNames.createExpense,
          queryParameters: _selectedFairId != null
              ? {'fairId': _selectedFairId!}
              : const {},
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: expensesAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading expense ledger...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to load expenses: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (expenses) {
              final categories = categoriesAsync.value ?? [];
              final categoryMap = {for (final c in categories) c.id: c};

              // Filter out cancelled for summary calculations
              final validExpenses = expenses
                  .where((e) => !e.isCancelled)
                  .toList();

              final totalPaise = validExpenses.fold<int>(
                0,
                (sum, e) => sum + e.amountPaise,
              );
              final paidPaise = validExpenses.fold<int>(
                0,
                (sum, e) => sum + e.paidAmountPaise,
              );
              final outstandingPaise = validExpenses.fold<int>(
                0,
                (sum, e) => sum + e.outstandingAmountPaise,
              );

              final now = DateTime.now();
              final thisMonthExpenses = validExpenses.where(
                (e) =>
                    e.expenseDate.year == now.year &&
                    e.expenseDate.month == now.month,
              );
              final thisMonthPaise = thisMonthExpenses.fold<int>(
                0,
                (sum, e) => sum + e.amountPaise,
              );

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fair Selector
                    fairsAsync.when(
                      data: (fairs) {
                        if (fairs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s16,
                          ),
                          child: AppDropdown<String?>(
                            compact: true,
                            value: _selectedFairId,
                            sheetTitle: 'Select Book Fair',
                            sheetSubtitle: 'Filter expenses by fair',
                            prefixIcon: const Icon(
                              Icons.store_rounded,
                              size: 20,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'All Book Fairs',
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

                    if (expenses.isEmpty) ...[
                      AppEmptyState(
                        title: 'No Expenses Recorded',
                        description: 'Track stall rent, decor, banners, logistics, and refreshments with multi-payment auditing.',
                        icon: Icons.receipt_long_rounded,
                        actionLabel: 'Record First Expense',
                        onAction: () => context.pushNamed(
                          RouteNames.createExpense,
                          queryParameters: _selectedFairId != null
                              ? {'fairId': _selectedFairId!}
                              : const {},
                        ),
                      ),
                    ] else ...[
                      // Primary Summary Card
                      AppCard(
                        padding: AppSpacing.insetAll16,
                        backgroundColor: colors.surfaceContainerHigh,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL RECORDED EXPENSES',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceMuted,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              CurrencyFormatter.formatPaise(totalPaise),
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
                                    label: 'Paid',
                                    value: CurrencyFormatter.formatPaise(
                                      paidPaise,
                                    ),
                                    badgeColor: colors.success,
                                    context: context,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: colors.borderSubtle,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s8,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Outstanding',
                                    value: CurrencyFormatter.formatPaise(
                                      outstandingPaise,
                                    ),
                                    badgeColor: outstandingPaise > 0
                                        ? colors.error
                                        : colors.onSurfaceMuted,
                                    context: context,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: colors.borderSubtle,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s8,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'This Month',
                                    value: CurrencyFormatter.formatPaise(
                                      thisMonthPaise,
                                    ),
                                    badgeColor: colors.primary,
                                    context: context,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // Category Breakdown Section
                      Text(
                        'Category Distribution',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _buildCategoryDistribution(
                        validExpenses: validExpenses,
                        categoryMap: categoryMap,
                        totalPaise: totalPaise,
                        context: context,
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // Recent Expenses Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Expenses',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.pushNamed(RouteNames.expenseHistory),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      ...expenses
                          .take(6)
                          .map(
                            (e) => _buildExpenseItemCard(
                              expense: e,
                              categoryName:
                                  categoryMap[e.categoryId]?.name ??
                                  'Uncategorized',
                              context: context,
                            ),
                          ),
                      const SizedBox(height: AppSpacing.s80), // FAB clearance
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color badgeColor,
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
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
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
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCategoryDistribution({
    required List<Expense> validExpenses,
    required Map<String, dynamic> categoryMap,
    required int totalPaise,
    required BuildContext context,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final Map<String, int> grouped = {};
    for (final exp in validExpenses) {
      grouped[exp.categoryId] =
          (grouped[exp.categoryId] ?? 0) + exp.amountPaise;
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sortedEntries.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s12),
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          final catName = categoryMap[entry.key]?.name ?? 'Uncategorized';
          final pct = totalPaise > 0
              ? ((entry.value / totalPaise) * 100).toStringAsFixed(0)
              : '0';

          return AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            backgroundColor: colors.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      catName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s6,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.brSmall,
                      ),
                      child: Text(
                        '$pct%',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  CurrencyFormatter.formatPaise(entry.value),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseItemCard({
    required Expense expense,
    required String categoryName,
    required BuildContext context,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    AppBadgeVariant badgeVariant;
    if (expense.isPaid) {
      badgeVariant = AppBadgeVariant.success;
    } else if (expense.isPartiallyPaid) {
      badgeVariant = AppBadgeVariant.warning;
    } else if (expense.isCancelled) {
      badgeVariant = AppBadgeVariant.neutral;
    } else {
      badgeVariant = AppBadgeVariant.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppCard.interactive(
        padding: AppSpacing.insetAll16,
        onTap: () => context.pushNamed(
          RouteNames.expenseDetails,
          pathParameters: {'id': expense.id},
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: AppRadius.brMedium,
              ),
              child: Icon(
                Icons.receipt_rounded,
                color: colors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Text(
                        categoryName,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text('•', style: TextStyle(color: colors.onSurfaceMuted)),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        '${expense.expenseDate.day}/${expense.expenseDate.month}/${expense.expenseDate.year}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(expense.amountPaise),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                AppBadge(label: expense.paymentStatus, variant: badgeVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
