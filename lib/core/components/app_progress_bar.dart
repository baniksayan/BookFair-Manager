import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Linear progress bar adhering strictly to brand palette tokens.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.label,
    this.showPercentage = false,
    this.fillColor,
    this.trackColor,
  });

  /// Normalized progress between 0.0 and 1.0
  final double value;
  final double height;
  final String? label;
  final bool showPercentage;
  final Color? fillColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final clampedValue = value.clamp(0.0, 1.0);

    final effectiveFill = fillColor ?? colors.primary;
    final effectiveTrack = trackColor ?? colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              if (showPercentage)
                Text(
                  '${(clampedValue * 100).toInt()}%',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          AppSpacing.gapH8,
        ],
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: effectiveTrack,
            borderRadius: AppRadius.brFull,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: height,
                  width: constraints.maxWidth * clampedValue,
                  decoration: BoxDecoration(
                    color: effectiveFill,
                    borderRadius: AppRadius.brFull,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
