import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../view_models/pos_cart_view_model.dart';

/// Item tile displayed inside the POS cart list.
class PosCartItemTile extends StatelessWidget {
  const PosCartItemTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onOverrideRequested,
  });

  final PosCartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onOverrideRequested;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppRadius.brMedium,
        border: Border.all(
          color: item.isStockDepleted && !item.isUnverifiedStock
              ? colors.error
              : colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.book.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapH4,
                    Text(
                      item.book.author,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurfaceMuted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
            ],
          ),
          AppSpacing.gapH8,

          // Price & Discount Information
          Row(
            children: [
              Text(
                CurrencyFormatter.format(item.unitSellingPrice),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              if (item.unitMrpPaise > item.unitSellingPricePaise) ...[
                AppSpacing.gapW8,
                Text(
                  CurrencyFormatter.format(item.unitMrp),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                AppSpacing.gapW8,
                AppBadge(
                  label:
                      '${item.book.condition.displayName} (-₹${(item.itemDiscountPaise / 100.0).toStringAsFixed(0)})',
                  variant: AppBadgeVariant.success,
                ),
              ],
            ],
          ),

          // Warnings: Below Cost or Insufficient Stock
          if (item.isBelowCost) ...[
            AppSpacing.gapH6,
            AppBadge(
              label:
                  'Selling below acquisition cost (Cost: ${CurrencyFormatter.format(item.unitCost)})',
              variant: AppBadgeVariant.warning,
            ),
          ],
          if (item.isStockDepleted) ...[
            AppSpacing.gapH6,
            Row(
              children: [
                Expanded(
                  child: AppBadge(
                    label: item.isUnverifiedStock
                        ? 'Manager Override: Authorized (${item.overrideReason ?? ''})'
                        : 'Stock Alert: Only ${item.availableStock} in recorded stock',
                    variant: item.isUnverifiedStock
                        ? AppBadgeVariant.warning
                        : AppBadgeVariant.error,
                  ),
                ),
                if (!item.isUnverifiedStock) ...[
                  AppSpacing.gapW8,
                  TextButton(
                    onPressed: onOverrideRequested,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Authorize',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],

          AppSpacing.gapH8,
          // Quantity selector & line total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.brSmall,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      constraints: const BoxConstraints(),
                      onPressed: () => onQuantityChanged(item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      constraints: const BoxConstraints(),
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                    ),
                  ],
                ),
              ),
              Text(
                'Line Total: ${CurrencyFormatter.format(item.lineTotal)}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
