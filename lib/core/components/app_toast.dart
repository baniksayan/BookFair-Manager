import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Lightweight editorial toast banner.
abstract final class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlayState = Overlay.of(context);
    final colors = context.colors;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 80.0,
        left: 24.0,
        right: 24.0,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: colors.isDark ? AppColors.c370617 : AppColors.c03071E,
                borderRadius: AppRadius.brFull,
                border: Border.all(color: colors.border, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16.0, color: colors.accent),
                    AppSpacing.gapW8,
                  ],
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.cFFFFFF,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}
