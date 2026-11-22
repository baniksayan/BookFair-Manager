import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Editorial chip component for filters, categories, and tags.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.onDeleted,
    this.enabled = true,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final VoidCallback? onDeleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final Color bgColor = !enabled
        ? colors.surface
        : isSelected
        ? colors.primary
        : colors.surface;

    final Color fgColor = !enabled
        ? colors.disabled
        : isSelected
        ? colors.onPrimary
        : colors.textPrimary;

    final Color borderColor = !enabled
        ? colors.disabled
        : isSelected
        ? colors.primary
        : colors.border;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppRadius.brFull,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.brFull,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.brFull,
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14.0, color: fgColor),
                  AppSpacing.gapW8,
                ],
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: fgColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (onDeleted != null && enabled) ...[
                  AppSpacing.gapW4,
                  GestureDetector(
                    onTap: onDeleted,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14.0,
                      color: fgColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
