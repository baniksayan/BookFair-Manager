import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/utils/date_formatter.dart';

/// Top header banner for the Dashboard screen.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final currentDateStr = DateFormatter.formatLong(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brand Emblem
          Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: AppRadius.brMedium,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF,
              size: 22.0,
            ),
          ),
          AppSpacing.gapW12,

          // Branding & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      AppStrings.appName,
                      style: textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    AppSpacing.gapW8,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadius.brSmall,
                        border: Border.all(color: colors.border, width: 1.0),
                      ),
                      child: Text(
                        AppStrings.offlineModeBadge,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH4,
                Text(
                  currentDateStr,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Theme Toggle Action
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.brMedium,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: IconButton(
              tooltip: colors.isDark ? 'Switch to Light' : 'Switch to Dark',
              icon: Icon(
                colors.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: colors.textPrimary,
                size: 20.0,
              ),
              onPressed: () {
                ref.read(themeModeProvider.notifier).toggleTheme(colors.isDark);
              },
            ),
          ),
        ],
      ),
    );
  }
}
