import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_chip.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_search_bar.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book.dart';
import '../view_models/book_catalogue_view_model.dart';
import '../view_models/inventory_providers.dart';
import '../widgets/book_card.dart';

/// Screen 02: Book Catalogue & Master Exhibition Inventory List.
class BookCatalogueScreen extends ConsumerWidget {
  const BookCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final booksAsync = ref.watch(booksStreamProvider(null));
    final catalogueState = ref.watch(bookCatalogueViewModelProvider);
    final vm = ref.read(bookCatalogueViewModelProvider.notifier);

    return Scaffold(
      appBar: AppAppBar(
        title: 'Book Catalogue',
        subtitle: 'Master titles and stock levels',
        actions: [
          IconButton(
            tooltip: 'Add Book',
            icon: Icon(Icons.add_rounded, color: colors.textPrimary),
            onPressed: () => context.push('/inventory/books/create'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: booksAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(message: 'Loading catalogue...'),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: colors.error)),
            ),
            data: (allBooks) {
              final filteredBooks = vm.filterBooks(books: allBooks);

              return Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s16,
                      AppSpacing.s8,
                    ),
                    child: AppSearchBar(
                      hint: 'Search by title, author, ISBN, publisher...',
                      onChanged: vm.setSearchQuery,
                      onClear: () => vm.setSearchQuery(''),
                    ),
                  ),

                  // Stock Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s4,
                      AppSpacing.s16,
                      AppSpacing.s12,
                    ),
                    child: Row(
                      children: BookStockFilter.values.map((filter) {
                        final isSelected = catalogueState.stockFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.s8),
                          child: AppChip(
                            label: filter.displayName,
                            isSelected: isSelected,
                            onTap: () => vm.setStockFilter(filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Condition Filter Chips (Secondary Filter Strip)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        AppChip(
                          label: 'All Conditions',
                          isSelected: catalogueState.conditionFilter == null,
                          onTap: () => vm.setConditionFilter(null),
                        ),
                        AppSpacing.gapW8,
                        ...BookCondition.values.map((cond) {
                          final isSelected =
                              catalogueState.conditionFilter == cond;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.s8,
                            ),
                            child: AppChip(
                              label: cond.displayName,
                              isSelected: isSelected,
                              onTap: () => vm.setConditionFilter(
                                isSelected ? null : cond,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Results count
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filteredBooks.length} titles found',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Books List
                  Expanded(
                    child: filteredBooks.isEmpty
                        ? _buildEmptyState(context, allBooks.isEmpty)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filteredBooks.length,
                            separatorBuilder: (context, index) =>
                                AppSpacing.gapH12,
                            itemBuilder: (context, index) {
                              final book = filteredBooks[index];
                              return BookCard(
                                book: book,
                                availableStock: book.openingStockQuantity,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Book'),
        onPressed: () => context.push('/inventory/books/create'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDbEmpty) {
    if (isDbEmpty) {
      return AppEmptyState(
        icon: Icons.menu_book_rounded,
        title: 'No Books in Catalogue',
        description: 'Start by creating your first book title or recording an incoming purchase batch.',
        actionLabel: 'Add New Book',
        onAction: () => context.push('/inventory/books/create'),
      );
    }

    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Matching Books',
      description:
          'No book titles match the current search query or filter selection.',
      actionLabel: 'Clear Search',
      onAction: () {},
    );
  }
}
