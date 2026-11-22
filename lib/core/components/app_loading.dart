import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

enum AppLoadingSize { small, medium, large }

/// Circular spinner loading indicator styled strictly with brand tokens.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = AppLoadingSize.medium,
    this.color,
    this.message,
  });

  const AppLoadingIndicator.small({super.key, this.color, this.message})
    : size = AppLoadingSize.small;

  const AppLoadingIndicator.large({super.key, this.color, this.message})
    : size = AppLoadingSize.large;

  final AppLoadingSize size;
  final Color? color;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveColor = color ?? colors.primary;
    final (diameter, strokeWidth) = _resolveDimensions();

    final indicator = SizedBox(
      width: diameter,
      height: diameter,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        backgroundColor: colors.border,
      ),
    );

    if (message == null) return Center(child: indicator);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          AppSpacing.gapH16,
          Text(
            message!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  (double, double) _resolveDimensions() {
    switch (size) {
      case AppLoadingSize.small:
        return (16.0, 2.0);
      case AppLoadingSize.medium:
        return (28.0, 3.0);
      case AppLoadingSize.large:
        return (44.0, 4.0);
    }
  }
}
