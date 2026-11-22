import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_button.dart';

/// Modal alert & confirmation dialog with editorial styling.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.primaryActionText,
    this.onPrimaryAction,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;
  final bool isDestructive;

  /// Static helper to display the dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
    String? primaryActionText,
    VoidCallback? onPrimaryAction,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        icon: icon,
        primaryActionText: primaryActionText,
        onPrimaryAction: onPrimaryAction,
        secondaryActionText: secondaryActionText,
        onSecondaryAction: onSecondaryAction,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brLarge,
        side: BorderSide(color: colors.border, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: Padding(
          padding: AppSpacing.insetAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: isDestructive ? colors.error : colors.primary,
                    borderRadius: AppRadius.brMedium,
                  ),
                  child: Icon(icon, color: AppColors.cFFFFFF, size: 24.0),
                ),
                AppSpacing.gapH16,
              ],
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              AppSpacing.gapH8,
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
              AppSpacing.gapH24,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryActionText != null) ...[
                    AppButton.text(
                      text: secondaryActionText!,
                      onPressed:
                          onSecondaryAction ??
                          () => Navigator.of(context).pop(),
                      size: AppButtonSize.small,
                    ),
                    AppSpacing.gapW8,
                  ],
                  if (primaryActionText != null)
                    AppButton(
                      text: primaryActionText!,
                      variant: isDestructive
                          ? AppButtonVariant.destructive
                          : AppButtonVariant.primary,
                      onPressed:
                          onPrimaryAction ?? () => Navigator.of(context).pop(),
                      size: AppButtonSize.small,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
