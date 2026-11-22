import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Editorial toggle switch strictly adhering to brand palette tokens.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
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

    final toggleTrack = GestureDetector(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48.0,
        height: 28.0,
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.brFull,
          color: enabled
              ? (value ? colors.primary : colors.surface)
              : colors.disabled,
          border: Border.all(
            color: enabled
                ? (value ? colors.primary : colors.border)
                : colors.disabled,
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? (colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF)
                  : colors.textSecondary,
            ),
          ),
        ),
      ),
    );

    if (label == null) return toggleTrack;

    return InkWell(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      borderRadius: AppRadius.brMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            AppSpacing.gapW16,
            toggleTrack,
          ],
        ),
      ),
    );
  }
}
