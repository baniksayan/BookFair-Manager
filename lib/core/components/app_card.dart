import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

enum AppCardVariant { defaultCard, elevated, outlined, interactive }

/// Refined editorial card container strictly using brand tokens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.defaultCard,
    this.padding = AppSpacing.insetAll16,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.gradient,
  });

  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding = AppSpacing.insetAll16,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.gradient,
  }) : variant = AppCardVariant.outlined;

  const AppCard.elevated({
    super.key,
    required this.child,
    this.padding = AppSpacing.insetAll16,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.gradient,
  }) : variant = AppCardVariant.elevated;

  const AppCard.interactive({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = AppSpacing.insetAll16,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.gradient,
  }) : variant = AppCardVariant.interactive;

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = borderRadius ?? AppRadius.brLarge;
    final bg = backgroundColor ?? colors.surface;
    final border = borderColor ?? colors.border;

    final borderSide = variant == AppCardVariant.outlined
        ? Border.all(color: border, width: 1.5)
        : Border.all(color: border, width: 1.0);

    final isInteractive =
        onTap != null || variant == AppCardVariant.interactive;

    Widget cardInner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.transparent,
        gradient: gradient,
        borderRadius: radius,
        border: borderSide,
      ),
      child: child,
    );

    if (isInteractive) {
      cardInner = InkWell(onTap: onTap, borderRadius: radius, child: cardInner);
    }

    Widget cardContent = Material(
      color: gradient == null ? bg : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: cardInner,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: cardContent);
    }

    return cardContent;
  }
}
