import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_button.dart';

/// Error state presentation widget with optional retry action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.description,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Center(
      child: Padding(
        padding: AppSpacing.insetAll32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.brLarge,
                border: Border.all(color: colors.error, width: 1.5),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32.0,
                color: colors.error,
              ),
            ),
            AppSpacing.gapH20,
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontFamily: 'Georgia',
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapH8,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340.0),
              child: Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.gapH24,
              AppButton(
                text: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.medium,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
