import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_chip.dart';
import '../../../../core/components/app_dialog.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_search_bar.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book_fair.dart';
import '../view_models/book_fair_list_view_model.dart';
import '../view_models/book_fair_providers.dart';
import '../widgets/book_fair_card.dart';

/// Screen 01: Production Book Fair Management & Exhibition Catalog.
class BookFairListScreen extends ConsumerWidget {
  const BookFairListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final listState = ref.watch(bookFairListViewModelProvider);
    final vm = ref.read(bookFairListViewModelProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: fairsAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading fair exhibitions...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading fairs: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (allFairs) {
              final filteredFairs = vm.filterFairs(allFairs);

              final totalCount = allFairs.where((f) => !f.isArchived).length;
              final activeCount = allFairs
                  .where(
                    (f) => !f.isArchived && f.status == BookFairStatus.active,
                  )
                  .length;
              final completedCount = allFairs
                  .where(
                    (f) =>
                        !f.isArchived && f.status == BookFairStatus.completed,
                  )
                  .length;

              return Column(
                children: [
                  // --- Screen Header ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s16,
                      AppSpacing.s16,
                      AppSpacing.s8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  AppStrings.navBookFairs,
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontFamily: 'Georgia',
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                AppSpacing.gapW8,
                                AppBadge(
                                  label: '$totalCount FAIRS',
                                  variant: AppBadgeVariant.primary,
                                ),
                              ],
                            ),
                            AppSpacing.gapH4,
                            Text(
                              'Stall operations & regional exhibitions',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        AppButton(
                          text: 'New Fair',
                          icon: Icons.add_rounded,
                          size: AppButtonSize.small,
                          onPressed: () =>
                              context.pushNamed(RouteNames.createBookFair),
                        ),
                      ],
                    ),
                  ),

                  // --- Summary Cards Row ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryMetricPill(
                            label: 'TOTAL',
                            value: '$totalCount',
                            icon: Icons.storefront_outlined,
                          ),
                        ),
                        AppSpacing.gapW8,
                        Expanded(
                          child: _SummaryMetricPill(
                            label: 'ACTIVE',
                            value: '$activeCount',
                            icon: Icons.bolt_rounded,
                            isHighlighted: activeCount > 0,
                          ),
                        ),
                        AppSpacing.gapW8,
                        Expanded(
                          child: _SummaryMetricPill(
                            label: 'COMPLETED',
                            value: '$completedCount',
                            icon: Icons.done_all_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Search Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s4,
                    ),
                    child: AppSearchBar(
                      hint: 'Search by fair name, venue, city...',
                      onChanged: vm.setSearchQuery,
                      onClear: () => vm.setSearchQuery(''),
                    ),
                  ),

                  // --- Filter Tabs ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s8,
                      AppSpacing.s16,
                      AppSpacing.s12,
                    ),
                    child: Row(
                      children: BookFairFilter.values.map((filter) {
                        final isSelected = listState.activeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.s8),
                          child: AppChip(
                            label: filter.displayName,
                            isSelected: isSelected,
                            onTap: () => vm.setFilter(filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- Fair Cards List / Empty State ---
                  Expanded(
                    child: filteredFairs.isEmpty
                        ? _buildEmptyState(context, listState, allFairs.isEmpty)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s16,
                              AppSpacing.s4,
                              AppSpacing.s16,
                              AppSpacing.s32,
                            ),
                            itemCount: filteredFairs.length,
                            separatorBuilder: (context, index) =>
                                AppSpacing.gapH12,
                            itemBuilder: (context, index) {
                              final fair = filteredFairs[index];
                              return BookFairCard(
                                fair: fair,
                                onTap: () =>
                                    context.push('/book-fairs/${fair.id}'),
                                onEdit: () =>
                                    context.push('/book-fairs/${fair.id}/edit'),
                                onToggleArchive: () =>
                                    vm.toggleArchive(fair.id),
                                onDelete: () =>
                                    _confirmDelete(context, vm, fair),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    BookFairListState state,
    bool isDbEmpty,
  ) {
    if (isDbEmpty) {
      return AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'No Book Fairs Registered',
        description: 'Establish your first book fair exhibition workspace to track inventory, partners, and initial investments.',
        actionLabel: 'Add Your First Book Fair',
        onAction: () => context.pushNamed(RouteNames.createBookFair),
      );
    }

    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'No Matching Fairs',
      description: 'No book fair exhibitions match the current filter or search criteria.',
      actionLabel: 'Reset Filters',
      onAction: () {
        // Reset query and filter
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    BookFairListViewModel vm,
    BookFair fair,
  ) {
    AppDialog.show(
      context: context,
      title: 'Delete Book Fair?',
      message:
          'Are you sure you want to permanently delete "${fair.name}"? This action will remove all associated partner relationships and investment ledger records. This cannot be undone.',
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
      primaryActionText: 'Delete Permanently',
      onPrimaryAction: () async {
        Navigator.of(context).pop();
        await vm.deleteFair(fair.id);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Book fair "${fair.name}" has been removed.',
            variant: AppSnackbarVariant.info,
          );
        }
      },
      secondaryActionText: 'Cancel',
      onSecondaryAction: () => Navigator.of(context).pop(),
    );
  }
}

class _SummaryMetricPill extends StatelessWidget {
  const _SummaryMetricPill({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      borderColor: isHighlighted ? colors.primary : colors.border,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.0,
            color: isHighlighted ? colors.primary : colors.textSecondary,
          ),
          AppSpacing.gapW8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 9.0,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
