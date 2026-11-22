import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palettes.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/theme_controller.dart';
import '../extensions/context_extensions.dart';
import 'palette_switcher_sheet.dart';

/// Special interactive multicolor button displaying the active palette identity and
/// launching the full [PaletteSwitcherSheet] when tapped.
class PaletteSwitcherButton extends ConsumerWidget {
  const PaletteSwitcherButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentPalette = ref.watch(themeControllerProvider).palette;

    if (compact) {
      return IconButton(
        tooltip: 'Change Color Palette (${currentPalette.name})',
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border, width: 1.5),
                gradient: SweepGradient(
                  colors: currentPalette.colors.take(6).toList(),
                ),
              ),
            ),
            Icon(
              Icons.palette_rounded,
              size: 16.0,
              color: colors.isDark ? AppPalettes.black : AppPalettes.white,
            ),
          ],
        ),
        onPressed: () => PaletteSwitcherSheet.show(context),
      );
    }

    return InkWell(
      onTap: () => PaletteSwitcherSheet.show(context),
      borderRadius: AppRadius.brFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.brFull,
          border: Border.all(color: colors.border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18.0,
              height: 18.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: currentPalette.colors.take(6).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              currentPalette.name,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16.0,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
