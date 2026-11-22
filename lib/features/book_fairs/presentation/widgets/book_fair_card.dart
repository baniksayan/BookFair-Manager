import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/book_fair.dart';

/// Editorial card representing an individual Book Fair in list views.
class BookFairCard extends StatelessWidget {
  const BookFairCard({
    super.key,
    required this.fair,
    required this.onTap,
    required this.onEdit,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final BookFair fair;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final dateRangeStr = DateFormatter.formatRange(
      fair.startDate,
      fair.endDate,
    );
    final locationDisplay = [
      fair.location,
      if (fair.city.isNotEmpty) fair.city,
      if (fair.state.isNotEmpty) fair.state,
    ].join(', ');

    return AppCard.interactive(
      onTap: onTap,
      padding: AppSpacing.insetAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status Badge & Popup Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(fair.status),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: colors.textSecondary,
                  size: 20.0,
                ),
                color: colors.surface,
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.brMedium,
                  side: BorderSide(color: colors.border, width: 1.0),
                ),
                onSelected: (val) {
                  switch (val) {
                    case 'view':
                      onTap();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'archive':
                      onToggleArchive();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16.0,
                          color: colors.textPrimary,
                        ),
                        AppSpacing.gapW8,
                        Text(
                          'Open Details',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16.0,
                          color: colors.textPrimary,
                        ),
                        AppSpacing.gapW8,
                        Text(
                          'Edit Fair',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          fair.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 16.0,
                          color: colors.textPrimary,
                        ),
                        AppSpacing.gapW8,
                        Text(
                          fair.isArchived ? 'Restore Fair' : 'Archive Fair',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16.0,
                          color: colors.error,
                        ),
                        AppSpacing.gapW8,
                        Text(
                          'Delete Fair',
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.gapH8,

          // Fair Title
          Text(
            fair.name,
            style: textTheme.titleMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          AppSpacing.gapH4,

          // Location
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14.0,
                color: colors.textSecondary,
              ),
              AppSpacing.gapW4,
              Expanded(
                child: Text(
                  locationDisplay,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapH4,

          // Schedule Dates
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14.0,
                color: colors.textSecondary,
              ),
              AppSpacing.gapW4,
              Text(
                dateRangeStr,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          Divider(color: colors.divider, height: 1.0),
          AppSpacing.gapH12,

          // Financial & Partnership Metadata Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTIMATED BUDGET',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                      fontSize: 9.0,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    CurrencyFormatter.format(fair.estimatedBudget),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INITIAL CAPITAL',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                      fontSize: 9.0,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    CurrencyFormatter.format(fair.initialInvestment),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PARTNERS',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                      fontSize: 9.0,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 14.0,
                        color: colors.textSecondary,
                      ),
                      AppSpacing.gapW4,
                      Text(
                        '${fair.partnerCount}',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BookFairStatus status) {
    switch (status) {
      case BookFairStatus.active:
        return const AppBadge(
          label: 'ACTIVE',
          variant: AppBadgeVariant.success,
          icon: Icons.circle,
        );
      case BookFairStatus.upcoming:
        return const AppBadge(
          label: 'UPCOMING',
          variant: AppBadgeVariant.warning,
          icon: Icons.access_time_rounded,
        );
      case BookFairStatus.completed:
        return const AppBadge(
          label: 'COMPLETED',
          variant: AppBadgeVariant.neutral,
          icon: Icons.done_all_rounded,
        );
      case BookFairStatus.archived:
        return const AppBadge(
          label: 'ARCHIVED',
          variant: AppBadgeVariant.neutral,
          icon: Icons.archive_outlined,
        );
    }
  }
}
