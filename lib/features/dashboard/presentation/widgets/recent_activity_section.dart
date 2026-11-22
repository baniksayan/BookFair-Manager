import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../book_fairs/domain/entities/activity_log.dart';

/// Recent stall activity list displaying real logged lifecycle transactions.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.activities});

  final List<ActivityLog> activities;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Ledger Activities',
                style: textTheme.titleLarge?.copyWith(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const AppBadge(
                label: 'AUDIT TRAIL',
                variant: AppBadgeVariant.neutral,
              ),
            ],
          ),
          AppSpacing.gapH4,
          Text(
            'Chronological system events & contribution entries',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          AppSpacing.gapH12,
          if (activities.isEmpty)
            AppCard(
              padding: AppSpacing.insetAll20,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 28.0,
                      color: colors.textSecondary,
                    ),
                    AppSpacing.gapH8,
                    Text(
                      'No Ledger Activities Yet',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    AppSpacing.gapH4,
                    Text(
                      'Activities will be automatically recorded here as you create fairs, register partners, and log contributions.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) =>
                    Divider(color: colors.divider, height: 1.0),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _ActivityListTile(activity: activity);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityListTile extends StatelessWidget {
  const _ActivityListTile({required this.activity});

  final ActivityLog activity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final (icon, iconBg) = _resolveIcon(activity.type, colors);

    final isPositive = activity.amount.startsWith('+');

    return Padding(
      padding: AppSpacing.insetAll16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppRadius.brSmall,
            ),
            child: Icon(
              icon,
              size: 18.0,
              color: colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF,
            ),
          ),
          AppSpacing.gapW12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                AppSpacing.gapH4,
                Text(
                  activity.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                AppSpacing.gapH4,
                Text(
                  DateFormatter.formatDisplay(activity.timestamp),
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.0,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapW8,
          Text(
            activity.amount,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isPositive ? colors.primary : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _resolveIcon(ActivityLogType type, AppColorScheme colors) {
    switch (type) {
      case ActivityLogType.fairCreated:
        return (Icons.add_business_rounded, colors.primary);
      case ActivityLogType.fairUpdated:
        return (Icons.edit_note_rounded, colors.accent);
      case ActivityLogType.fairArchived:
        return (Icons.archive_outlined, colors.textSecondary);
      case ActivityLogType.partnerAdded:
        return (Icons.person_add_rounded, colors.secondary);
      case ActivityLogType.investmentRecorded:
        return (Icons.monetization_on_outlined, colors.success);
      case ActivityLogType.bookAdded:
        return (Icons.menu_book_rounded, colors.primary);
      case ActivityLogType.bookUpdated:
        return (Icons.auto_stories_rounded, colors.accent);
      case ActivityLogType.purchaseBatchCreated:
        return (Icons.shopping_bag_outlined, colors.secondary);
      case ActivityLogType.stockAdded:
        return (Icons.inventory_2_outlined, colors.success);
      case ActivityLogType.stockAdjusted:
        return (Icons.tune_rounded, colors.warning);
      case ActivityLogType.previousStockRegistered:
        return (Icons.history_edu_rounded, colors.primary);
      case ActivityLogType.supplierAdded:
        return (Icons.local_shipping_outlined, colors.secondary);
      case ActivityLogType.themeChanged:
        return (Icons.palette_outlined, colors.accent);
      case ActivityLogType.expenseRecorded:
        return (Icons.receipt_long_rounded, colors.error);
      case ActivityLogType.paymentRecorded:
        return (Icons.payments_rounded, colors.primary);
      case ActivityLogType.fundsTransferred:
        return (Icons.swap_horiz_rounded, colors.accent);
      case ActivityLogType.reimbursementSettled:
        return (Icons.handshake_rounded, colors.success);
    }
  }
}
