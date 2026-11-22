import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Accessible radio button component adhering strictly to brand palette tokens.
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? subtitle;
  final bool enabled;

  bool get _isSelected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final radioCircle = GestureDetector(
      onTap: enabled ? () => onChanged?.call(value) : null,
      child: Container(
        width: 22.0,
        height: 22.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(
            color: enabled
                ? (_isSelected ? colors.primary : colors.border)
                : colors.disabled,
            width: 2.0,
          ),
        ),
        child: _isSelected
            ? Center(
                child: Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? colors.primary : colors.disabled,
                  ),
                ),
              )
            : null,
      ),
    );

    if (label == null) return radioCircle;

    return InkWell(
      onTap: enabled ? () => onChanged?.call(value) : null,
      borderRadius: AppRadius.brMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            radioCircle,
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
