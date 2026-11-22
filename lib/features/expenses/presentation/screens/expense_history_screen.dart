import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_search_bar.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../view_models/expense_providers.dart';

/// Screen 04: Searchable, filterable audit history of all operational expenses.
class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  String _searchQuery = '';
  String? _selectedFairId;
  String? _selectedCategoryId;
  String _statusFilter =
      'All'; // 'All', 'Unpaid', 'Partially Paid', 'Paid', 'Cancelled'
  final _sortBy = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider(_selectedFairId));

    return Scaffold(
      appBar: AppBar(title: const Text('Expense History')),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s12,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Column(
                  children: [
                    AppSearchBar(
                      hint: 'Search expenses, bills, references...',
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Filter dropdowns row
                    Row(
                      children: [
                        // Fair filter
                        Expanded(
                          child: fairsAsync.when(
                            data: (fairs) => Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
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
                                        'All Fairs',
                                        style: TextStyle(fontSize: 13),
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
                                  onChanged: (val) =>
                                      setState(() => _selectedFairId = val),
                                ),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),

                        // Category filter
                        Expanded(
                          child: categoriesAsync.when(
                            data: (categories) => Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainer,
                                borderRadius: AppRadius.brSmall,
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedCategoryId,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'All Categories',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    ...categories.map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _selectedCategoryId = val),
                                ),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    // Status Chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          const SizedBox(width: AppSpacing.s6),
                          _buildFilterChip('Unpaid'),
                          const SizedBox(width: AppSpacing.s6),
                          _buildFilterChip('Partially Paid'),
                          const SizedBox(width: AppSpacing.s6),
                          _buildFilterChip('Paid'),
                          const SizedBox(width: AppSpacing.s6),
                          _buildFilterChip('Cancelled'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Filtered List
              Expanded(
                child: expensesAsync.when(
                  loading: () => const Center(
                    child: AppLoadingIndicator.large(
                      message: 'Filtering records...',
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  data: (expenses) {
                    final categories = categoriesAsync.value ?? [];
                    final categoryMap = {for (final c in categories) c.id: c};

                    var filtered = expenses.where((e) {
                      if (_selectedCategoryId != null &&
                          e.categoryId != _selectedCategoryId) {
                        return false;
                      }

                      if (_statusFilter != 'All' &&
                          e.paymentStatus.toLowerCase() !=
                              _statusFilter.toLowerCase()) {
                        return false;
                      }

                      if (_searchQuery.trim().isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final matchesTitle = e.title.toLowerCase().contains(q);
                        final matchesDesc = e.description
                            .toLowerCase()
                            .contains(q);
                        final matchesRef =
                            e.referenceNumber?.toLowerCase().contains(q) ??
                            false;
                        if (!matchesTitle && !matchesDesc && !matchesRef) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    // Sort
                    switch (_sortBy) {
                      case 'newest':
                        filtered.sort(
                          (a, b) => b.expenseDate.compareTo(a.expenseDate),
                        );
                        break;
                      case 'oldest':
                        filtered.sort(
                          (a, b) => a.expenseDate.compareTo(b.expenseDate),
                        );
                        break;
                      case 'highest':
                        filtered.sort(
                          (a, b) => b.amountPaise.compareTo(a.amountPaise),
                        );
                        break;
                      case 'lowest':
                        filtered.sort(
                          (a, b) => a.amountPaise.compareTo(b.amountPaise),
                        );
                        break;
                    }

                    if (filtered.isEmpty) {
                      return const AppEmptyState(
                        title: 'No Matching Expenses',
                        description: 'Try adjusting your search criteria, category or payment filters.',
                        icon: Icons.search_off_rounded,
                      );
                    }

                    return ListView.builder(
                      padding: AppSpacing.insetAll16,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final expense = filtered[index];
                        final catName =
                            categoryMap[expense.categoryId]?.name ??
                            'Uncategorized';

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
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s12,
                          ),
                          child: AppCard.interactive(
                            padding: AppSpacing.insetAll16,
                            onTap: () => context.pushNamed(
                              RouteNames.expenseDetails,
                              pathParameters: {'id': expense.id},
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: AppRadius.brMedium,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      Text(
                                        '$catName • ${expense.expenseDate.day}/${expense.expenseDate.month}/${expense.expenseDate.year}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatPaise(
                                        expense.amountPaise,
                                      ),
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.s4),
                                    AppBadge(
                                      label: expense.paymentStatus,
                                      variant: badgeVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    final colors = context.colors;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = label),
      selectedColor: colors.primary.withValues(alpha: 0.2),
      checkmarkColor: colors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colors.primary : colors.onSurface,
      ),
    );
  }
}
