import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

enum AppBadgeVariant { neutral, primary, success, warning, error }

/// Editorial status or counter badge.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
  });

  const AppBadge.sampleData({
    super.key,
    this.label = 'SAMPLE DATA',
    this.variant = AppBadgeVariant.warning,
    this.icon = Icons.info_outline_rounded,
  });

  const AppBadge.active({
    super.key,
    this.label = 'ACTIVE',
    this.variant = AppBadgeVariant.success,
    this.icon = Icons.circle,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bgColor, fgColor, borderColor) = _resolveColors(colors);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.brSmall,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.0, color: fgColor),
            AppSpacing.gapW4,
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _resolveColors(AppColorScheme colors) {
    switch (variant) {
      case AppBadgeVariant.neutral:
        return (colors.surface, colors.textSecondary, colors.border);
      case AppBadgeVariant.primary:
        return (
          colors.primary,
          colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF,
          colors.primary,
        );
      case AppBadgeVariant.success:
        return (colors.surface, colors.success, colors.success);
      case AppBadgeVariant.warning:
        return (colors.surface, colors.warning, colors.warning);
      case AppBadgeVariant.error:
        return (colors.surface, colors.error, colors.error);
    }
  }
}
