import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Clean stock quantity badge displaying status (In Stock, Low Stock, Out of Stock).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (label, bgColor, fgColor) = _resolveStyle(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.brSmall,
        border: Border.all(color: fgColor, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  (String, Color, Color) _resolveStyle(AppColorScheme colors) {
    if (quantity <= 0) {
      return ('OUT OF STOCK', colors.error, AppColors.cFFFFFF);
    } else if (quantity <= 5) {
      return (
        'LOW: $quantity LEFT',
        colors.warning,
        colors.isDark ? AppColors.c03071E : AppColors.c000000,
      );
    } else {
      return ('$quantity COPIES', colors.surface, colors.textPrimary);
    }
  }
}
