import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Editorial tooltip wrapping standard [Tooltip] with brand tokens.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 500),
  });

  final String message;
  final Widget child;
  final Duration waitDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      textStyle: const TextStyle(
        color: AppColors.cFFFFFF,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: colors.isDark ? AppColors.c370617 : AppColors.c03071E,
        borderRadius: AppRadius.brSmall,
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: child,
    );
  }
}
