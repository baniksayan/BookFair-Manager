import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../inventory/presentation/view_models/inventory_providers.dart';

/// Screen 08: High-contrast, read-only fast book inventory lookup interface for stall volunteers.
class SellerBookSearchScreen extends ConsumerStatefulWidget {
  const SellerBookSearchScreen({super.key, this.fairId});

  final String? fairId;

  @override
  ConsumerState<SellerBookSearchScreen> createState() =>
      _SellerBookSearchScreenState();
}

class _SellerBookSearchScreenState
    extends ConsumerState<SellerBookSearchScreen> {
  String _searchQuery = '';
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

    final booksAsync = ref.watch(booksStreamProvider(widget.fairId));
    final stockMovementsAsync = ref.watch(stockMovementsStreamProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stall Inventory Lookup'),
        backgroundColor: colors.surface,
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: AppSearchBar(
                  controller: _searchController,
                  hint: 'Search by title, author, or ISBN...',
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),
              Expanded(
                child: booksAsync.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (err, _) =>
                      Center(child: Text('Error loading catalogue: $err')),
                  data: (allBooks) {
                    final movements = stockMovementsAsync.value ?? [];

                    var filtered = allBooks.where((b) {
                      if (!b.isActive) return false;
                      if (_searchQuery.isEmpty) return true;
                      return b.title.toLowerCase().contains(_searchQuery) ||
                          b.author.toLowerCase().contains(_searchQuery) ||
                          (b.isbn13 != null &&
                              b.isbn13!.contains(_searchQuery)) ||
                          (b.isbn10 != null &&
                              b.isbn10!.contains(_searchQuery));
                    }).toList();

                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No Matching Titles',
                        description: _searchQuery.isEmpty
                            ? 'No books registered in the catalogue.'
                            : 'No book matches "$_searchQuery". Verify spelling or ISBN.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final book = filtered[index];
                        final availableStock = movements
                            .where((m) => m.bookId == book.id)
                            .fold<int>(0, (sum, m) => sum + m.netDelta);

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover / book icon placeholder
                              Container(
                                width: 50,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainer,
                                  borderRadius: AppRadius.brSmall,
                                  border: Border.all(
                                    color: colors.borderSubtle,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 24,
                                    color: colors.onSurfaceMuted,
                                  ),
                                ),
                              ),
                              AppSpacing.gapW12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    AppSpacing.gapH2,
                                    Text(
                                      book.author,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceMuted,
                                      ),
                                    ),
                                    AppSpacing.gapH4,
                                    Row(
                                      children: [
                                        AppBadge(
                                          label: book.condition.displayName,
                                          variant: AppBadgeVariant.neutral,
                                        ),
                                        AppSpacing.gapW6,
                                        AppBadge(
                                          label:
                                              'Rec. Disc: ${book.condition.defaultDiscountPercentage.toStringAsFixed(0)}%',
                                          variant: AppBadgeVariant.primary,
                                        ),
                                        if (book.primaryIsbn != null) ...[
                                          AppSpacing.gapW6,
                                          Text(
                                            book.primaryIsbn!,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colors.onSurfaceMuted,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(
                                      book.defaultSellingPrice,
                                    ),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                  if (book.mrpPaise >
                                      book.defaultSellingPricePaise) ...[
                                    AppSpacing.gapH2,
                                    Text(
                                      'MRP ${CurrencyFormatter.format(book.mrp)}',
                                      style: textTheme.bodySmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: colors.onSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                  AppSpacing.gapH6,
                                  AppBadge(
                                    label: availableStock > 0
                                        ? '$availableStock In Stock'
                                        : 'Out of Stock',
                                    variant: availableStock > 0
                                        ? AppBadgeVariant.success
                                        : AppBadgeVariant.error,
                                  ),
                                ],
                              ),
                            ],
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
}
