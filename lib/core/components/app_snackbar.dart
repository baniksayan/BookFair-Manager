import 'package:flutter/material.dart';

import '../../app/constants/app_constants.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

enum AppSnackbarVariant { info, success, warning, error }

/// Accessible SnackBar adhering strictly to approved brand tokens.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarVariant variant = AppSnackbarVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = AppConstants.snackbarDuration,
  }) {
    final colors = context.colors;
    final (indicatorColor, iconData) = _resolveVariant(variant, colors);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: colors.isDark ? AppColors.c370617 : AppColors.c03071E,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMedium,
          side: BorderSide(color: indicatorColor, width: 1.5),
        ),
        margin: AppSpacing.insetAll16,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        content: Row(
          children: [
            Icon(iconData, color: indicatorColor, size: 20.0),
            AppSpacing.gapW12,
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.cFFFFFF,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: indicatorColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      show(context, message: message, variant: AppSnackbarVariant.success);

  static void showError(BuildContext context, String message) =>
      show(context, message: message, variant: AppSnackbarVariant.error);

  static void showWarning(BuildContext context, String message) =>
      show(context, message: message, variant: AppSnackbarVariant.warning);

  static (Color, IconData) _resolveVariant(
    AppSnackbarVariant variant,
    AppColorScheme colors,
  ) {
    switch (variant) {
      case AppSnackbarVariant.info:
        return (colors.info, Icons.info_outline_rounded);
      case AppSnackbarVariant.success:
        return (colors.success, Icons.check_circle_outline_rounded);
      case AppSnackbarVariant.warning:
        return (colors.warning, Icons.warning_amber_rounded);
      case AppSnackbarVariant.error:
        return (colors.error, Icons.error_outline_rounded);
    }
  }
}
