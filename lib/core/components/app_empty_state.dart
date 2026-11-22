import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_button.dart';

/// Clean editorial empty state widget with optional call-to-action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                border: Border.all(color: colors.border, width: 1.5),
              ),
              child: Icon(icon, size: 32.0, color: colors.primary),
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
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.gapH24,
              AppButton(
                text: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
