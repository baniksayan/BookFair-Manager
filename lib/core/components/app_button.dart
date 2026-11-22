import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_loading.dart';

enum AppButtonVariant { primary, secondary, outlined, text, destructive }

enum AppButtonSize { small, medium, large }

/// Comprehensive, accessible button component strictly adhering to brand tokens.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  });

  /// Factory constructor for destructive actions
  const AppButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  }) : variant = AppButtonVariant.destructive;

  /// Factory constructor for outlined buttons
  const AppButton.outlined({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  }) : variant = AppButtonVariant.outlined;

  /// Factory constructor for text-only buttons
  const AppButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  }) : variant = AppButtonVariant.text;

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bgColor, fgColor, borderColor) = _resolveColors(colors);
    final (height, padding, textStyle, iconSize) = _resolveDimensions(context);

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          AppLoadingIndicator.small(color: fgColor),
          AppSpacing.gapW8,
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: fgColor),
          AppSpacing.gapW8,
        ],
        Flexible(
          child: Text(
            text,
            style: textStyle.copyWith(color: fgColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          AppSpacing.gapW8,
          Icon(trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );

    final buttonWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.brMedium,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: Center(child: content),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: semanticLabel ?? text,
      child: Material(
        color: AppColors.c000000, // masked by outer shape
        type: MaterialType.transparency,
        borderRadius: AppRadius.brMedium,
        child: InkWell(
          onTap: _isEnabled ? onPressed : null,
          borderRadius: AppRadius.brMedium,
          child: isFullWidth
              ? SizedBox(width: double.infinity, child: buttonWidget)
              : buttonWidget,
        ),
      ),
    );
  }

  (Color, Color, Color?) _resolveColors(AppColorScheme colors) {
    if (!_isEnabled) {
      if (variant == AppButtonVariant.outlined ||
          variant == AppButtonVariant.text) {
        return (colors.surface, colors.disabled, colors.border);
      }
      return (colors.disabled, colors.surface, colors.disabled);
    }

    switch (variant) {
      case AppButtonVariant.primary:
        final fg = colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF;
        return (colors.primary, fg, colors.primary);

      case AppButtonVariant.secondary:
        return (colors.secondary, AppColors.cFFFFFF, colors.secondary);

      case AppButtonVariant.outlined:
        return (colors.surface, colors.primary, colors.border);

      case AppButtonVariant.text:
        return (colors.surface, colors.primary, null);

      case AppButtonVariant.destructive:
        return (colors.error, AppColors.cFFFFFF, colors.error);
    }
  }

  (double, EdgeInsets, TextStyle, double) _resolveDimensions(
    BuildContext context,
  ) {
    final textTheme = context.textTheme;
    switch (size) {
      case AppButtonSize.small:
        return (
          36.0,
          const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          textTheme.labelMedium ?? const TextStyle(fontSize: 12.0),
          16.0,
        );
      case AppButtonSize.medium:
        return (
          48.0,
          const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          textTheme.labelLarge ?? const TextStyle(fontSize: 14.0),
          18.0,
        );
      case AppButtonSize.large:
        return (
          56.0,
          const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          textTheme.titleMedium ?? const TextStyle(fontSize: 16.0),
          20.0,
        );
    }
  }
}
