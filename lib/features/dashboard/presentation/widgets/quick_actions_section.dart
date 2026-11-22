import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';

/// Quick actions grid offering fast access to daily stall management operations.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key, required this.onNavigateToCreateFair});

  final VoidCallback onNavigateToCreateFair;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final actions = [
      _ActionItem(
        title: AppStrings.actionAddBookFair,
        subtitle: AppStrings.actionAddBookFairDesc,
        icon: Icons.add_business_outlined,
        onTap: onNavigateToCreateFair,
      ),
      _ActionItem(
        title: AppStrings.actionAddBooks,
        subtitle: AppStrings.actionAddBooksDesc,
        icon: Icons.library_add_outlined,
        onTap: () => context.pushNamed(RouteNames.createBook),
      ),
      _ActionItem(
        title: AppStrings.actionRecordExpense,
        subtitle: AppStrings.actionRecordExpenseDesc,
        icon: Icons.receipt_outlined,
        onTap: () => context.pushNamed(RouteNames.createExpense),
      ),
      _ActionItem(
        title: AppStrings.actionSalesCounter,
        subtitle: AppStrings.actionSalesCounterDesc,
        icon: Icons.point_of_sale_outlined,
        onTap: () => context.pushNamed(RouteNames.posSalesCounter),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.quickActionsTitle,
            style: textTheme.titleLarge?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          AppSpacing.gapH4,
          Text(
            AppStrings.quickActionsSubtitle,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          AppSpacing.gapH12,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: AppSpacing.s12,
                  mainAxisSpacing: AppSpacing.s12,
                  childAspectRatio: isWide ? 1.35 : 1.05,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return AppCard.interactive(
                    onTap: action.onTap,
                    padding: AppSpacing.insetAll12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 32.0,
                          height: 32.0,
                          decoration: BoxDecoration(
                            gradient: colors.primaryGradient,
                            borderRadius: AppRadius.brSmall,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 4.0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            action.icon,
                            size: 16.0,
                            color: colors.onPrimary,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              action.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppSpacing.gapH4,
                            Text(
                              action.subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
