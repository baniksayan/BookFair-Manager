import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Modal bottom sheet with editorial handle and strict brand tokens.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailingAction,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailingAction;

  /// Static helper to display the bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    Widget? trailingAction,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.brTopExtraLarge,
      ),
      builder: (ctx) => AppBottomSheet(
        title: title,
        subtitle: subtitle,
        trailingAction: trailingAction,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.s12),
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: AppRadius.brFull,
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s20,
                AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          AppSpacing.gapH4,
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailingAction,
                ],
              ),
            ),
            Divider(color: colors.divider, height: 1.0),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
