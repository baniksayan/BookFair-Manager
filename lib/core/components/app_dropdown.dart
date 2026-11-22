import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_button.dart';

/// An enriched dropdown menu item with optional dedicated icon, subtitle, and label.
/// Extends standard [DropdownMenuItem] for full backward compatibility across the app.
class AppDropdownItem<T> extends DropdownMenuItem<T> {
  const AppDropdownItem({
    super.key,
    super.onTap,
    required super.value,
    super.enabled = true,
    this.icon,
    this.iconData,
    this.subtitle,
    this.label,
    required super.child,
  });

  /// Custom leading icon widget.
  final Widget? icon;

  /// Custom leading icon data.
  final IconData? iconData;

  /// Explanatory subtitle displayed in the selection sheet.
  final String? subtitle;

  /// Plain string label representation.
  final String? label;
}

/// Premium, accessible dropdown field that triggers an intuitive, branded
/// modal bottom sheet selection picker adhering strictly to the BookFair Manager design system.
class AppDropdown<T> extends StatefulWidget {
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
    this.sheetTitle,
    this.sheetSubtitle,
    this.sheetIcon,
    this.searchable,
    this.actionButtonText,
    this.instantSelect,
    this.compact = false,
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

  /// Custom title for the modal bottom sheet header. Defaults to [label].
  final String? sheetTitle;

  /// Custom explanatory subtitle for the modal bottom sheet header.
  final String? sheetSubtitle;

  /// Custom header icon for the modal bottom sheet.
  final Widget? sheetIcon;

  /// Whether to include real-time search filtering in the modal bottom sheet.
  /// Defaults to true when items length exceeds 5.
  final bool? searchable;

  /// Custom label for the bottom confirmation button.
  final String? actionButtonText;

  /// When true, tapping an item card immediately selects it and dismisses the sheet.
  /// When false, tapping an item stages selection requiring the user to press the bottom action button.
  /// Defaults to true when [items.length] <= 5, [searchable] is not true, and [actionButtonText] is null.
  final bool? instantSelect;

  /// Compact presentation for filter bars and embedded table cells.
  final bool compact;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final GlobalKey<FormFieldState<T>> _fieldKey = GlobalKey<FormFieldState<T>>();

  DropdownMenuItem<T>? _findSelectedItem(T? val) {
    if (widget.items.isEmpty) return null;
    for (final item in widget.items) {
      if (item.value == val) return item;
    }
    return null;
  }

  String _extractLabel(DropdownMenuItem<T>? item) {
    if (item == null) return '';
    if (item is AppDropdownItem<T> && item.label != null) {
      return item.label!;
    }
    if (item.child is Text) {
      return (item.child as Text).data ?? '';
    }
    return item.value?.toString() ?? '';
  }

  Widget? _extractPrefixIcon(DropdownMenuItem<T>? item) {
    if (widget.prefixIcon != null) return widget.prefixIcon;
    if (item is AppDropdownItem<T>) {
      if (item.icon != null) return item.icon;
      if (item.iconData != null) {
        return Icon(item.iconData, size: 20.0);
      }
    }
    return null;
  }

  Future<void> _openPickerSheet(
    BuildContext context,
    FormFieldState<T> field,
  ) async {
    if (!widget.enabled) return;
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AppDropdownSheet<T>(
          items: widget.items,
          initialValue: widget.value ?? field.value,
          title: widget.sheetTitle ?? widget.label?.replaceAll('*', '').trim(),
          subtitle: widget.sheetSubtitle,
          headerIcon: widget.sheetIcon,
          searchable: widget.searchable,
          actionButtonText: widget.actionButtonText,
          instantSelect: widget.instantSelect,
        );
      },
    );

    // If an item was confirmed (including explicitly choosing null)
    if (selected != null || widget.items.any((i) => i.value == selected)) {
      field.didChange(selected);
      widget.onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return FormField<T>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      enabled: widget.enabled,
      builder: (field) {
        final currentValue = widget.value ?? field.value;
        final selectedItem = _findSelectedItem(currentValue);
        final hasSelection = selectedItem != null;
        final displayText = hasSelection ? _extractLabel(selectedItem) : '';
        final effectiveError = widget.errorText ?? field.errorText;
        final hasError = effectiveError != null && effectiveError.isNotEmpty;

        final prefixWidget = _extractPrefixIcon(selectedItem);

        Widget triggerBox = Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 48.0 : 54.0),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.s12 : AppSpacing.s16,
            vertical: widget.compact ? AppSpacing.s10 : AppSpacing.s14,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.brMedium,
            border: Border.all(
              color: hasError
                  ? colors.error
                  : (!widget.enabled
                        ? colors.disabled
                        : colors.border.withValues(
                            alpha: colors.isDark ? 0.4 : 0.7,
                          )),
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (prefixWidget != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: widget.enabled
                        ? colors.textSecondary
                        : colors.disabled,
                    size: 20.0,
                  ),
                  child: prefixWidget,
                ),
                AppSpacing.gapW12,
              ],
              Expanded(
                child: Text(
                  hasSelection
                      ? displayText
                      : (widget.hint ?? 'Select an option'),
                  style: textTheme.bodyLarge?.copyWith(
                    color: !widget.enabled
                        ? colors.disabled
                        : (hasSelection ? colors.textPrimary : colors.disabled),
                    fontWeight: hasSelection
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              AppSpacing.gapW8,
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: widget.enabled ? colors.textPrimary : colors.disabled,
                size: 22.0,
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null && !widget.compact) ...[
              Text(
                widget.label!,
                style: textTheme.labelLarge?.copyWith(
                  color: widget.enabled ? colors.textPrimary : colors.disabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.gapH8,
            ],
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.enabled
                    ? () => _openPickerSheet(context, field)
                    : null,
                borderRadius: AppRadius.brMedium,
                child: triggerBox,
              ),
            ),
            if (hasError) ...[
              AppSpacing.gapH4,
              Text(
                effectiveError,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.error,
                  fontSize: 12.0,
                ),
              ),
            ] else if (widget.helperText != null) ...[
              AppSpacing.gapH4,
              Text(
                widget.helperText!,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The rich modal bottom sheet UI presenting items as cards with icons,
/// subtitles, real-time search, and a full-width confirmation action.
class AppDropdownSheet<T> extends StatefulWidget {
  const AppDropdownSheet({
    super.key,
    required this.items,
    this.initialValue,
    this.title,
    this.subtitle,
    this.headerIcon,
    this.searchable,
    this.actionButtonText,
    this.instantSelect,
  });

  final List<DropdownMenuItem<T>> items;
  final T? initialValue;
  final String? title;
  final String? subtitle;
  final Widget? headerIcon;
  final bool? searchable;
  final String? actionButtonText;
  final bool? instantSelect;

  @override
  State<AppDropdownSheet<T>> createState() => _AppDropdownSheetState<T>();
}

class _AppDropdownSheetState<T> extends State<AppDropdownSheet<T>> {
  late T? _tempSelectedValue;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isInstantSelect {
    if (widget.instantSelect != null) return widget.instantSelect!;
    if (widget.actionButtonText != null &&
        widget.actionButtonText!.isNotEmpty) {
      return false;
    }
    final isSearchable = widget.searchable ?? (widget.items.length > 5);
    if (isSearchable) {
      return false;
    }
    return widget.items.length <= 5;
  }

  @override
  void initState() {
    super.initState();
    _tempSelectedValue = widget.initialValue;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _cleanTitle() {
    return widget.title?.replaceAll('*', '').trim() ?? 'Select Option';
  }

  String _cleanSubtitle() {
    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) {
      return widget.subtitle!;
    }
    return _inferHeaderSubtitle(_cleanTitle());
  }

  Widget _buildHeaderIcon(BuildContext context) {
    if (widget.headerIcon != null) return widget.headerIcon!;
    final colors = context.colors;
    final iconData = _inferHeaderIcon(_cleanTitle());
    return Icon(iconData, color: colors.primary, size: 22.0);
  }

  String _buildActionButtonText() {
    if (widget.actionButtonText != null &&
        widget.actionButtonText!.isNotEmpty) {
      return widget.actionButtonText!;
    }
    return _inferActionButtonText(_cleanTitle());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final cleanTitle = _cleanTitle();
    final cleanSubtitle = _cleanSubtitle();
    final actionBtnText = _buildActionButtonText();

    final isSearchable = widget.searchable ?? (widget.items.length > 5);

    // Resolve item metadata
    final resolvedItems = widget.items.map((item) {
      String label = '';
      if (item is AppDropdownItem<T> && item.label != null) {
        label = item.label!;
      } else if (item.child is Text) {
        label = (item.child as Text).data ?? '';
      } else {
        label = item.value?.toString() ?? '';
      }

      String? subtitle;
      if (item is AppDropdownItem<T> && item.subtitle != null) {
        subtitle = item.subtitle;
      } else {
        subtitle = _inferSubtitle(label, item.value);
      }

      Widget? icon;
      IconData? iconData;
      if (item is AppDropdownItem<T>) {
        icon = item.icon;
        iconData = item.iconData;
      }
      iconData ??= _inferItemIcon(label, item.value);

      return _DropdownItemMetadata<T>(
        item: item,
        label: label,
        subtitle: subtitle,
        icon: icon,
        iconData: iconData,
      );
    }).toList();

    // Filter items based on real-time query
    final filteredItems = resolvedItems.where((meta) {
      if (_searchQuery.isEmpty) return true;
      final labelMatch = meta.label.toLowerCase().contains(_searchQuery);
      final subtitleMatch =
          meta.subtitle?.toLowerCase().contains(_searchQuery) ?? false;
      return labelMatch || subtitleMatch;
    }).toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.brTopExtraLarge,
          border: Border(
            top: BorderSide(
              color: colors.border.withValues(alpha: 0.6),
              width: 1.5,
            ),
            left: BorderSide(
              color: colors.border.withValues(alpha: 0.6),
              width: 1.0,
            ),
            right: BorderSide(
              color: colors.border.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle Pill
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.s12),
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.8),
                    borderRadius: AppRadius.brFull,
                  ),
                ),
              ),

              // Header Section with Rounded Leading Icon Container
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s14,
                  AppSpacing.s16,
                  AppSpacing.s10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          colors.primary.withValues(
                            alpha: colors.isDark ? 0.22 : 0.08,
                          ),
                          colors.surface,
                        ),
                        borderRadius: AppRadius.brMedium,
                        border: Border.all(
                          color: colors.primary.withValues(
                            alpha: colors.isDark ? 0.35 : 0.18,
                          ),
                          width: 1.0,
                        ),
                      ),
                      child: Center(child: _buildHeaderIcon(context)),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanTitle,
                            style: textTheme.titleLarge?.copyWith(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (cleanSubtitle.isNotEmpty) ...[
                            AppSpacing.gapH2,
                            Text(
                              cleanSubtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 22.0,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Real-time Search Input Field (when searchable or >5 items)
              if (isSearchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s4,
                    AppSpacing.s16,
                    AppSpacing.s10,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ${cleanTitle.toLowerCase()}...',
                      hintStyle: textTheme.bodyMedium?.copyWith(
                        color: colors.disabled,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 20.0,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18.0),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Color.alphaBlend(
                        colors.primary.withValues(
                          alpha: colors.isDark ? 0.12 : 0.04,
                        ),
                        colors.surface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s14,
                        vertical: AppSpacing.s10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.brMedium,
                        borderSide: BorderSide(
                          color: colors.border.withValues(
                            alpha: colors.isDark ? 0.35 : 0.6,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.brMedium,
                        borderSide: BorderSide(
                          color: colors.border.withValues(
                            alpha: colors.isDark ? 0.35 : 0.6,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.brMedium,
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

              const Divider(height: 1.0),

              // Option Cards List
              Flexible(
                child: filteredItems.isEmpty
                    ? Padding(
                        padding: AppSpacing.insetAll32,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40.0,
                                color: colors.disabled,
                              ),
                              AppSpacing.gapH8,
                              Text(
                                'No matching options found',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: AppSpacing.insetAll16,
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => AppSpacing.gapH10,
                        itemBuilder: (context, index) {
                          final meta = filteredItems[index];
                          final isSelected =
                              meta.item.value == _tempSelectedValue;

                          final leadingIconWidget =
                              meta.icon ??
                              (meta.iconData != null
                                  ? Icon(
                                      meta.iconData,
                                      size: 20.0,
                                      color: colors.primary,
                                    )
                                  : Icon(
                                      Icons.label_outline_rounded,
                                      size: 20.0,
                                      color: colors.primary,
                                    ));

                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (_isInstantSelect) {
                                Navigator.of(context).pop(meta.item.value);
                              } else {
                                setState(() {
                                  _tempSelectedValue = meta.item.value;
                                });
                              }
                            },
                            borderRadius: AppRadius.brLarge,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color.alphaBlend(
                                        colors.primary.withValues(
                                          alpha: colors.isDark ? 0.22 : 0.08,
                                        ),
                                        colors.surface,
                                      )
                                    : colors.surface,
                                borderRadius: AppRadius.brLarge,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.border.withValues(
                                          alpha: colors.isDark ? 0.35 : 0.5,
                                        ),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: colors.isDark ? 0.3 : 0.12,
                                          ),
                                          blurRadius: 6.0,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: colors.isDark ? 0.15 : 0.03,
                                          ),
                                          blurRadius: 3.0,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  // Left Icon Box
                                  Container(
                                    width: 40.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: Color.alphaBlend(
                                        colors.primary.withValues(
                                          alpha: isSelected ? 0.18 : 0.07,
                                        ),
                                        colors.surface,
                                      ),
                                      borderRadius: AppRadius.brMedium,
                                    ),
                                    child: Center(child: leadingIconWidget),
                                  ),
                                  AppSpacing.gapW12,

                                  // Title & Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meta.label,
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        if (meta.subtitle != null &&
                                            meta.subtitle!.isNotEmpty) ...[
                                          AppSpacing.gapH2,
                                          Text(
                                            meta.subtitle!,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colors.textSecondary,
                                                  fontSize: 12.0,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Right Selection Indicator
                                  if (isSelected)
                                    Container(
                                      width: 22.0,
                                      height: 22.0,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14.0,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 22.0,
                                      height: 22.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.border.withValues(
                                            alpha: 0.6,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Confirmation Button (only when 2-step confirmation is active)
              if (!_isInstantSelect)
                Padding(
                  padding: AppSpacing.insetAll16,
                  child: AppButton(
                    text: actionBtnText,
                    isFullWidth: true,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(_tempSelectedValue);
                    },
                  ),
                )
              else
                const SizedBox(height: AppSpacing.s12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownItemMetadata<T> {
  const _DropdownItemMetadata({
    required this.item,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconData,
  });

  final DropdownMenuItem<T> item;
  final String label;
  final String? subtitle;
  final Widget? icon;
  final IconData? iconData;
}

// ==========================================
// INTELLIGENT INFERENCE DICTIONARY
// ==========================================

IconData _inferHeaderIcon(String cleanTitle) {
  final t = cleanTitle.toLowerCase();
  if (t.contains('payment')) return Icons.account_balance_wallet_outlined;
  if (t.contains('partner') || t.contains('investor')) {
    return Icons.groups_outlined;
  }
  if (t.contains('vendor') || t.contains('supplier')) {
    return Icons.storefront_outlined;
  }
  if (t.contains('category') || t.contains('expense')) {
    return Icons.layers_outlined;
  }
  if (t.contains('condition')) return Icons.verified_outlined;
  if (t.contains('fair') || t.contains('exhibition')) {
    return Icons.store_rounded;
  }
  if (t.contains('account') || t.contains('bank')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (t.contains('movement') || t.contains('stock')) {
    return Icons.swap_horiz_rounded;
  }
  if (t.contains('role')) return Icons.badge_outlined;
  return Icons.tune_rounded;
}

String _inferHeaderSubtitle(String cleanTitle) {
  final t = cleanTitle.toLowerCase();
  if (t.contains('payment')) return 'Choose how this contribution was paid.';
  if (t.contains('partner') || t.contains('investor')) {
    return 'Select the business ownership structure';
  }
  if (t.contains('vendor') || t.contains('supplier')) {
    return 'Select the type of vendor for this purchase.';
  }
  if (t.contains('expense') || t.contains('category')) {
    return 'Select the type of expense';
  }
  if (t.contains('fair')) return 'Select active book fair workspace';
  if (t.contains('account')) return 'Select cashbook account for settlement';
  if (t.contains('condition')) return 'Select condition of the book inventory';
  if (t.contains('role')) return 'Select organizational partnership role';
  if (t.contains('contribution')) {
    return 'Select type of investment contribution';
  }
  return 'Choose an option from the list below';
}

String _inferActionButtonText(String cleanTitle) {
  final t = cleanTitle.toLowerCase();
  if (t.contains('payment')) return 'Select Payment Method';
  if (t.contains('partner') || t.contains('investor')) return 'Select';
  if (t.contains('vendor') || t.contains('supplier')) return 'Select Vendor';
  if (t.contains('category') || t.contains('expense')) return 'Select Category';
  if (t.contains('fair')) return 'Select Fair';
  if (t.contains('account')) return 'Select Account';
  if (cleanTitle.isNotEmpty && cleanTitle != 'Select Option') {
    return 'Select $cleanTitle';
  }
  return 'Select';
}

IconData _inferItemIcon(String label, dynamic value) {
  final l = label.toLowerCase().trim();
  final valStr = value?.toString().toLowerCase().trim() ?? '';

  // Payment methods
  if (l == 'cash' || valStr.contains('cash')) return Icons.payments_outlined;
  if (l == 'upi' || valStr.contains('upi')) return Icons.smartphone_rounded;
  if (l.contains('bank') ||
      valStr.contains('bank') ||
      l.contains('neft') ||
      l.contains('rtgs')) {
    return Icons.account_balance_rounded;
  }
  if (l.contains('cheque') || valStr.contains('cheque')) {
    return Icons.receipt_long_outlined;
  }

  // Number of partners
  if (value == 1 || l.startsWith('sole') || l.contains('1 organizer')) {
    return Icons.person_outline_rounded;
  }
  if (value == 2 || l.startsWith('2 partner')) {
    return Icons.people_outline_rounded;
  }
  if (value == 3 || l.startsWith('3 partner')) {
    return Icons.groups_outlined;
  }
  if (value == 4 || l.startsWith('4 partner')) {
    return Icons.group_outlined;
  }
  if (value == 5 || l.contains('5+') || l.contains('syndicate')) {
    return Icons.diversity_3_outlined;
  }

  // Vendors
  if (l.contains('direct') || l.contains('independent')) {
    return Icons.storefront_outlined;
  }
  if (l.contains('distributor') || l.contains('wholesaler')) {
    return Icons.account_balance_outlined;
  }

  // Expense categories
  if (l.contains('banner') || l.contains('flex')) return Icons.flag_outlined;
  if (l.contains('chair') || l.contains('table') || l.contains('furniture')) {
    return Icons.chair_outlined;
  }
  if (l.contains('comm') || l.contains('phone') || l.contains('internet')) {
    return Icons.wifi_rounded;
  }
  if (l.contains('decor')) return Icons.celebration_outlined;
  if (l.contains('elect') || l.contains('power')) return Icons.bolt_rounded;
  if (l.contains('equip')) return Icons.inventory_2_outlined;
  if (l.contains('food') ||
      l.contains('refresh') ||
      l.contains('meal') ||
      l.contains('tea')) {
    return Icons.lunch_dining_outlined;
  }
  if (l.contains('labour') ||
      l.contains('labor') ||
      l.contains('staff') ||
      l.contains('wage')) {
    return Icons.engineering_outlined;
  }
  if (l.contains('light')) return Icons.lightbulb_outlined;
  if (l.contains('load') ||
      l.contains('transport') ||
      l.contains('freight') ||
      l.contains('unload')) {
    return Icons.local_shipping_outlined;
  }
  if (l.contains('maint') || l.contains('repair')) return Icons.build_outlined;
  if (l.contains('pack') || l.contains('box')) return Icons.all_inbox_outlined;
  if (l.contains('print')) return Icons.print_outlined;
  if (l.contains('stall adv')) return Icons.store_outlined;
  if (l.contains('stall rent') || l.contains('rent')) {
    return Icons.domain_outlined;
  }
  if (l.contains('stationery') || l.contains('pen') || l.contains('paper')) {
    return Icons.edit_note_outlined;
  }

  // Contribution types
  if (l.contains('book') || l.contains('inventory')) {
    return Icons.menu_book_rounded;
  }
  if (l.contains('asset')) return Icons.inventory_2_outlined;

  // Partner roles
  if (l.contains('managing')) return Icons.star_outline_rounded;
  if (l.contains('operating')) return Icons.work_outline_rounded;
  if (l.contains('financial')) return Icons.account_balance_outlined;
  if (l.contains('silent')) return Icons.person_outline_rounded;

  // Book conditions
  if (l == 'new') return Icons.auto_awesome_rounded;
  if (l.contains('like new')) return Icons.thumb_up_outlined;
  if (l == 'good') return Icons.check_circle_outline_rounded;
  if (l == 'fair') return Icons.menu_book_outlined;
  if (l == 'poor') return Icons.history_edu_outlined;

  // Stock movement
  if (l.contains('purchase') || l.contains('inflow')) {
    return Icons.add_shopping_cart_rounded;
  }
  if (l.contains('opening')) return Icons.inventory_rounded;
  if (l.contains('sale') || l.contains('sold')) {
    return Icons.point_of_sale_rounded;
  }
  if (l.contains('damage') || l.contains('lost')) {
    return Icons.remove_circle_outline_rounded;
  }
  if (l.contains('return')) return Icons.keyboard_return_rounded;
  if (l.contains('adjust')) return Icons.tune_rounded;

  // Accounts
  if (l.contains('cash in hand') ||
      l.contains('cashbox') ||
      l.contains('petty')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (l.contains('bank')) return Icons.account_balance_outlined;

  // All Fairs
  if (l.contains('all book fairs') || l.contains('combined')) {
    return Icons.apps_rounded;
  }

  // Fallback
  if (l.contains('other')) {
    return Icons.more_horiz_rounded;
  }
  return Icons.label_outline_rounded;
}

String? _inferSubtitle(String label, dynamic value) {
  final l = label.toLowerCase().trim();
  final valStr = value?.toString().toLowerCase().trim() ?? '';

  // Payment methods
  if (l == 'cash' || valStr == 'cash') return 'Physical cash payment';
  if (l == 'upi' || valStr == 'upi') {
    return 'Google Pay, PhonePe, Paytm etc.';
  }
  if (l.contains('bank transfer') || valStr.contains('bank')) {
    return 'Direct bank transaction (NEFT/IMPS/RTGS)';
  }
  if (l == 'other' || valStr == 'other') return 'Any other payment method';
  if (l == 'cheque' || valStr == 'cheque') return 'Bank cheque settlement';

  // Number of partners
  if (value == 1 || l.startsWith('sole') || l.contains('1 organizer')) {
    return 'Run and manage the fair alone';
  }
  if (value == 2 || l.startsWith('2 partner')) {
    return 'A business with two partners.';
  }
  if (value == 3 || l.startsWith('3 partner')) {
    return 'A business with three partners.';
  }
  if (value == 4 || l.startsWith('4 partner')) {
    return 'A business with four partners.';
  }
  if (value == 5 || l.contains('5+') || l.contains('syndicate')) {
    return 'Five or more partners (syndicate/group).';
  }

  // Vendor / Supplier
  if (l.contains('direct') || l.contains('independent')) {
    return 'Purchase directly from a publisher, author, or seller.';
  }
  if (l.contains('distributor') || l.contains('wholesaler')) {
    return 'Purchase through a distributor or third-party supplier.';
  }

  // Expense categories
  if (l.contains('banner') || l.contains('flex')) {
    return 'Flex printing, stall banners, and promotional posters';
  }
  if (l.contains('chair')) {
    return 'Tables, chairs, and visitor seating arrangements';
  }
  if (l.contains('comm')) {
    return 'Internet, phone recharges, and mobile POS SIMs';
  }
  if (l.contains('decor')) {
    return 'Festive stall lighting, fabrics, and decorative displays';
  }
  if (l.contains('elect')) {
    return 'Power lines, generator charges, and electrical fittings';
  }
  if (l.contains('equip')) {
    return 'Display racks, barcode scanners, and calculation tools';
  }
  if (l.contains('food') || l.contains('refresh')) {
    return 'Meals, snacks, and tea for stall staff and volunteers';
  }
  if (l.contains('labour') || l.contains('labor')) {
    return 'Staff wages, loading help, and stall setup workers';
  }
  if (l.contains('light')) {
    return 'Halogens, spotlights, and ambient book illumination';
  }
  if (l.contains('load') || l.contains('unload') || l.contains('transp')) {
    return 'Cartage, vehicle freight, and box handling fees';
  }
  if (l.contains('maint')) {
    return 'Repairs, dust covers, and stall hardware upkeep';
  }
  if (l.contains('pack')) {
    return 'Carry bags, wrapping paper, bubble wrap, and boxes';
  }
  if (l.contains('print')) {
    return 'Receipts, bookmarks, flyers, and catalogue prints';
  }
  if (l.contains('stall adv')) {
    return 'Advance deposit paid to organizers for stall allocation';
  }
  if (l.contains('stall rent')) {
    return 'Remaining rent and space lease payments';
  }
  if (l.contains('stationery')) {
    return 'Pens, tapes, markers, staplers, and billing pads';
  }

  // Book conditions
  if (l == 'new') {
    return 'Pristine brand-new publisher stock';
  }
  if (l.contains('like new')) {
    return 'Near perfect condition with uncreased spine';
  }
  if (l == 'good') {
    return 'Clean readable copy with minimal shelf wear';
  }
  if (l == 'fair') {
    return 'Noticeable reading wear, intact pages and binding';
  }
  if (l == 'poor') {
    return 'Heavy wear or markings, reading copy';
  }

  // Partner roles
  if (l.contains('managing')) {
    return 'Primary executor with full operational authority';
  }
  if (l.contains('financial')) {
    return 'Capital investor focusing on financing & returns';
  }
  if (l.contains('operating')) {
    return 'On-site stall runner handling inventory and sales';
  }
  if (l.contains('silent')) {
    return 'Non-operational investor with equity share';
  }

  // Stock movement
  if (l.contains('purchase') || l.contains('inflow')) {
    return 'New stock arrival from supplier or publisher';
  }
  if (l.contains('opening')) return 'Initial inventory brought into the fair';
  if (l.contains('sale')) return 'Sold to reader or customer at sales counter';
  if (l.contains('damage')) {
    return 'Damaged, soiled, or misplaced inventory';
  }
  if (l.contains('return')) {
    return 'Returned to supplier or received from buyer';
  }
  if (l.contains('adjust')) return 'Physical count reconciliation correction';

  // Accounts
  if (l.contains('cash in hand') || l.contains('cashbox')) {
    return 'Physical liquid cash in counter cashbox';
  }
  if (l.contains('bank')) {
    return 'Current or savings bank ledger account';
  }

  // All Fairs
  if (l.contains('all book fairs') || l.contains('combined')) {
    return 'Consolidated view across all exhibitions';
  }

  return null;
}
