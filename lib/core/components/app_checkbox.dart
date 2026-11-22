import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Accessible checkbox component adhering strictly to brand palette tokens.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final box = GestureDetector(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22.0,
        height: 22.0,
        decoration: BoxDecoration(
          color: value
              ? (enabled ? colors.primary : colors.disabled)
              : colors.surface,
          borderRadius: AppRadius.brSmall,
          border: Border.all(
            color: enabled
                ? (value ? colors.primary : colors.border)
                : colors.disabled,
            width: 1.5,
          ),
        ),
        child: value
            ? Icon(Icons.check_rounded, size: 16.0, color: colors.onPrimary)
            : null,
      ),
    );

    if (label == null) return box;

    return InkWell(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      borderRadius: AppRadius.brMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box,
            AppSpacing.gapW12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: enabled ? colors.textPrimary : colors.disabled,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.gapH4,
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: enabled ? colors.textSecondary : colors.disabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
