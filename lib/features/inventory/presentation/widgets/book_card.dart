import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/book.dart';
import 'stock_badge.dart';

/// Card widget rendering an individual book title in catalogue listings.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.availableStock = 0,
    this.onTap,
  });

  final Book book;
  final int availableStock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final discount = book.mrpPaise > book.defaultSellingPricePaise
        ? ((book.mrpPaise - book.defaultSellingPricePaise) /
                  book.mrpPaise *
                  100)
              .round()
        : 0;

    return AppCard(
      onTap: onTap ?? () => context.push('/inventory/books/${book.id}'),
      padding: AppSpacing.insetAll16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book spine / cover representation
          Container(
            width: 58.0,
            height: 84.0,
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: AppRadius.brSmall,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Center(
              child: Icon(
                Icons.menu_book_rounded,
                color: colors.primary,
                size: 28.0,
              ),
            ),
          ),
          AppSpacing.gapW16,

          // Details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Condition & Stock Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBadge(
                      label: book.condition.displayName.toUpperCase(),
                      variant: book.condition == BookCondition.brandNew
                          ? AppBadgeVariant.primary
                          : AppBadgeVariant.neutral,
                    ),
                    StockBadge(quantity: availableStock),
                  ],
                ),
                AppSpacing.gapH6,

                // Title
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    fontFamily: 'Georgia',
                  ),
                ),
                AppSpacing.gapH2,

                // Author & Publisher
                Text(
                  'by ${book.author}${book.publisher.isNotEmpty ? ' • ${book.publisher}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                AppSpacing.gapH8,

                // Pricing Row
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.format(book.defaultSellingPrice),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                    AppSpacing.gapW8,
                    if (book.mrpPaise > book.defaultSellingPricePaise) ...[
                      Text(
                        CurrencyFormatter.format(book.mrp),
                        style: textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: colors.disabled,
                        ),
                      ),
                      AppSpacing.gapW8,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: AppRadius.brSmall,
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            color: colors.isDark
                                ? AppColors.c03071E
                                : AppColors.cFFFFFF,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
