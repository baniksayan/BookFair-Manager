import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';

/// Visually distinctive editorial Hero Card featured at the top of the dashboard.
class DashboardHeroCard extends StatelessWidget {
  const DashboardHeroCard({super.key, required this.onStartNewBookFair});

  final VoidCallback onStartNewBookFair;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final badgeAccent = colors.isDark ? colors.accent : AppColors.cFFFFFF;

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      padding: AppSpacing.insetAll24,
      gradient: colors.heroGradient,
      borderColor: colors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.25),
                  borderRadius: AppRadius.brSmall,
                  border: Border.all(
                    color: badgeAccent.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12.0,
                      color: badgeAccent,
                    ),
                    AppSpacing.gapW4,
                    Text(
                      'EST. 2026',
                      style: textTheme.labelSmall?.copyWith(
                        color: badgeAccent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const AppBadge(
                label: 'STALL MANAGEMENT',
                variant: AppBadgeVariant.neutral,
              ),
            ],
          ),
          AppSpacing.gapH16,

          // Editorial Title (Always high-contrast white on rich hero gradient)
          Text(
            AppStrings.dashboardHeroTitle,
            style: textTheme.headlineLarge?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              color: AppColors.cFFFFFF,
              height: 1.25,
            ),
          ),
          AppSpacing.gapH8,

          // Editorial Description (Guaranteed high-contrast subtitle)
          Text(
            AppStrings.dashboardHeroSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.isDark
                  ? colors.accent
                  : AppColors.cFFFFFF.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
          AppSpacing.gapH20,

          // Call to Action
          AppButton(
            text: AppStrings.dashboardHeroAction,
            onPressed: onStartNewBookFair,
            icon: Icons.add_circle_outline_rounded,
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }
}
