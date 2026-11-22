import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/dashboard_summary.dart';

/// Business overview displaying real operational metrics and active fair status.
class BusinessOverviewSection extends StatelessWidget {
  const BusinessOverviewSection({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Financial & Operational Overview',
                  style: textTheme.titleLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.gapW8,
              const AppBadge(
                label: 'LIVE LOCAL LEDGER',
                variant: AppBadgeVariant.neutral,
              ),
            ],
          ),
          AppSpacing.gapH4,
          Text(
            'Aggregated metrics from local Hive storage',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          AppSpacing.gapH12,

          // Active Fair Header Card (if one exists)
          if (summary.activeFair != null) ...[
            AppCard.interactive(
              onTap: () =>
                  context.push('/book-fairs/${summary.activeFair!.id}'),
              padding: AppSpacing.insetAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppSpacing.gapW8,
                          Text(
                            'CURRENT FOCUS FAIR',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      AppBadge(
                        label: '${summary.activeFair!.daysRemaining} Days Left',
                        variant: AppBadgeVariant.warning,
                        icon: Icons.access_time_rounded,
                      ),
                    ],
                  ),
                  AppSpacing.gapH8,
                  Text(
                    summary.activeFair!.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    [
                      summary.activeFair!.location,
                      if (summary.activeFair!.city.isNotEmpty)
                        summary.activeFair!.city,
                    ].join(', '),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapH12,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormatter.formatRange(
                          summary.activeFair!.startDate,
                          summary.activeFair!.endDate,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Target Budget: ${CurrencyFormatter.format(summary.activeFair!.estimatedBudget)}',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppSpacing.gapH12,
          ],

          // 2x2 Metric Cards Grid (Total Fairs, Active Fairs, Upcoming Fairs, Total Investment)
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'TOTAL BOOK FAIRS',
                  value: '${summary.totalFairs}',
                  subtitle: '${summary.totalFairs} workspaces in Hive',
                  icon: Icons.storefront_outlined,
                ),
              ),
              AppSpacing.gapW12,
              Expanded(
                child: _MetricTile(
                  title: 'ACTIVE STALLS',
                  value: '${summary.activeFairs}',
                  subtitle: summary.activeFairs > 0
                      ? 'Live fair in progress'
                      : 'No fairs active today',
                  icon: Icons.bolt_rounded,
                  isHighlighted: summary.activeFairs > 0,
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'UPCOMING FAIRS',
                  value: '${summary.upcomingFairs}',
                  subtitle: 'Scheduled exhibitions',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              AppSpacing.gapW12,
              Expanded(
                child: _MetricTile(
                  title: 'TOTAL MOBILIZED',
                  value: CurrencyFormatter.format(
                    summary.totalRecordedInvestment,
                  ),
                  subtitle: 'Partner capital recorded',
                  icon: Icons.savings_outlined,
                  isHighlighted: summary.totalRecordedInvestment > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.isHighlighted = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: AppSpacing.insetAll16,
      borderColor: isHighlighted ? colors.primary : colors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 9.0,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 16.0,
                color: isHighlighted ? colors.primary : colors.textSecondary,
              ),
            ],
          ),
          AppSpacing.gapH8,
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapH4,
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 11.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
