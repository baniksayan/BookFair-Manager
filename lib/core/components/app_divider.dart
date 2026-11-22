import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Clean separator strictly using palette divider tokens.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.indent,
    this.endIndent,
    this.thickness = 1.0,
    this.color,
    this.label,
  });

  const AppDivider.vertical({
    super.key,
    this.indent,
    this.endIndent,
    this.thickness = 1.0,
    this.color,
  }) : label = null;

  final double? indent;
  final double? endIndent;
  final double thickness;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dividerColor = color ?? colors.divider;

    if (label != null) {
      return Row(
        children: [
          Expanded(
            child: Divider(
              color: dividerColor,
              thickness: thickness,
              endIndent: AppSpacing.s12,
            ),
          ),
          Text(
            label!,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          Expanded(
            child: Divider(
              color: dividerColor,
              thickness: thickness,
              indent: AppSpacing.s12,
            ),
          ),
        ],
      );
    }

    return Divider(
      color: dividerColor,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      height: thickness,
    );
  }
}
