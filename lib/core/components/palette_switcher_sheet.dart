import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palettes.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/theme_controller.dart';
import '../extensions/context_extensions.dart';
import 'app_button.dart';

/// Modal bottom sheet allowing users to interactively preview and apply all seven
/// brand color palettes.
class PaletteSwitcherSheet extends ConsumerStatefulWidget {
  const PaletteSwitcherSheet({super.key});

  /// Displays the palette switcher modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PaletteSwitcherSheet(),
    );
  }

  @override
  ConsumerState<PaletteSwitcherSheet> createState() =>
      _PaletteSwitcherSheetState();
}

class _PaletteSwitcherSheetState extends ConsumerState<PaletteSwitcherSheet> {
  late AppPalette _selectedPalette;

  @override
  void initState() {
    super.initState();
    _selectedPalette = ref.read(themeControllerProvider).palette;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final currentActivePalette = ref.watch(themeControllerProvider).palette;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.brTopExtraLarge,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.brTopExtraLarge,
          border: Border(
            top: BorderSide(color: colors.border, width: 1.5),
            left: BorderSide(color: colors.border, width: 1.0),
            right: BorderSide(color: colors.border, width: 1.0),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.s12),
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: AppRadius.brFull,
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s16,
                  AppSpacing.s20,
                  AppSpacing.s8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color Palette Presets',
                            style: textTheme.titleLarge?.copyWith(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          AppSpacing.gapH4,
                          Text(
                            'Select a brand theme identity for the application',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // List of Palettes
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: AppSpacing.insetAll16,
                  itemCount: AppPalettes.values.length,
                  separatorBuilder: (context, index) => AppSpacing.gapH12,
                  itemBuilder: (context, index) {
                    final palette = AppPalettes.values[index];
                    final isPreviewSelected = _selectedPalette.id == palette.id;
                    final isCurrentlyActive =
                        currentActivePalette.id == palette.id;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPalette = palette;
                        });
                      },
                      borderRadius: AppRadius.brLarge,
                      child: Container(
                        padding: AppSpacing.insetAll16,
                        decoration: BoxDecoration(
                          color: isPreviewSelected
                              ? colors.surfaceSecondary
                              : colors.surface,
                          borderRadius: AppRadius.brLarge,
                          border: Border.all(
                            color: isPreviewSelected
                                ? colors.primary
                                : colors.border,
                            width: isPreviewSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isPreviewSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      size: 20.0,
                                      color: isPreviewSelected
                                          ? colors.primary
                                          : colors.textSecondary,
                                    ),
                                    AppSpacing.gapW8,
                                    Text(
                                      palette.name,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isCurrentlyActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.s8,
                                      vertical: AppSpacing.s4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: AppRadius.brSmall,
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: colors.onPrimary,
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            AppSpacing.gapH8,
                            Text(
                              palette.description,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.0,
                              ),
                            ),
                            AppSpacing.gapH12,

                            // 10 Brand Swatches Strip
                            ClipRRect(
                              borderRadius: AppRadius.brSmall,
                              child: SizedBox(
                                height: 24.0,
                                child: Row(
                                  children: palette.colors.map((color) {
                                    return Expanded(
                                      child: Container(color: color),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            AppSpacing.gapH6,

                            // Black & White Neutral Indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Neutrals: ',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10.0,
                                  ),
                                ),
                                Container(
                                  width: 14.0,
                                  height: 14.0,
                                  decoration: BoxDecoration(
                                    color: AppPalette.neutralBlack,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                AppSpacing.gapW4,
                                Container(
                                  width: 14.0,
                                  height: 14.0,
                                  decoration: BoxDecoration(
                                    color: AppPalette.neutralWhite,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Actions (Apply & Cancel)
              Padding(
                padding: AppSpacing.insetAll16,
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        text: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'Apply Theme',
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          await ref
                              .read(themeControllerProvider.notifier)
                              .setPalette(_selectedPalette);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
