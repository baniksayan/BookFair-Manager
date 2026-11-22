import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Clean, editorial dropdown form field adhering to strict brand tokens.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: textTheme.labelLarge?.copyWith(
              color: enabled ? colors.textPrimary : colors.disabled,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapH8,
        ],
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          dropdownColor: colors.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? colors.textPrimary : colors.disabled,
            size: 22.0,
          ),
          style: textTheme.bodyLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.disabled,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
            hintStyle: textTheme.bodyMedium?.copyWith(color: colors.disabled),
            border: OutlineInputBorder(
              borderRadius: AppRadius.brMedium,
              borderSide: BorderSide(color: colors.border, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMedium,
              borderSide: BorderSide(color: colors.border, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMedium,
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMedium,
              borderSide: BorderSide(color: colors.error, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMedium,
              borderSide: BorderSide(color: colors.disabled, width: 1.0),
            ),
          ),
        ),
      ],
    );
  }
}
