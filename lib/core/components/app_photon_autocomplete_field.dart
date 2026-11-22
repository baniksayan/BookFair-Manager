import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import '../services/geocoding/geocoding_providers.dart';
import '../services/geocoding/photon_geocoding_service.dart';
import '../services/geocoding/photon_place.dart';
import 'app_text_field.dart';

/// Production-ready typeahead autocomplete field integrating Komoot Photon (OpenStreetMap).
///
/// Features:
/// - Real-time debounced typeahead suggestions (450 ms).
/// - Non-blocking asynchronous query fetching with stale response protection.
/// - Prioritized results for venues, cities, or states.
/// - Tap-outside and keyboard dismissal via [TapRegion] and [OverlayPortal].
/// - 100% manual text entry preserved without forcing option selection.
/// - Strict brand design system adherence (colors, radius, typography).
class AppPhotonAutocompleteField extends ConsumerStatefulWidget {
  const AppPhotonAutocompleteField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.searchType = PhotonSearchType.venue,
    this.latitude,
    this.longitude,
    this.onChanged,
    this.onPlaceSelected,
    this.enabled = true,
    this.debounceDuration = const Duration(milliseconds: 450),
    this.minChars = 2,
    this.limit = 8,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final Widget? prefixIcon;
  final PhotonSearchType searchType;
  final double? latitude;
  final double? longitude;
  final ValueChanged<String>? onChanged;
  final ValueChanged<PhotonPlace>? onPlaceSelected;
  final bool enabled;
  final Duration debounceDuration;
  final int minChars;
  final int limit;

  @override
  ConsumerState<AppPhotonAutocompleteField> createState() =>
      _AppPhotonAutocompleteFieldState();
}

class _AppPhotonAutocompleteFieldState
    extends ConsumerState<AppPhotonAutocompleteField> {
  final _portalController = OverlayPortalController();
  final _layerLink = LayerLink();
  final _tapRegionGroupId = UniqueKey();

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isInternalController = false;
  bool _isInternalFocusNode = false;

  Timer? _debounceTimer;
  int _activeRequestId = 0;
  bool _isLoading = false;
  List<PhotonPlace> _suggestions = const [];
  double _fieldWidth = 300.0;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _isInternalController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }

    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_handleFocusChanged);
    if (_isInternalFocusNode) _focusNode.dispose();
    if (_isInternalController) _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideDropdown();
    }
  }

  void _hideDropdown() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
  }

  void _showDropdown() {
    if (!_portalController.isShowing && mounted && _focusNode.hasFocus) {
      _portalController.show();
    }
  }

  void _measureFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final width = renderBox.size.width;
      if (width > 0 && width != _fieldWidth) {
        setState(() => _fieldWidth = width);
      }
    }
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);

    _debounceTimer?.cancel();
    final trimmed = text.trim();

    if (trimmed.length < widget.minChars) {
      setState(() {
        _isLoading = false;
        _suggestions = const [];
      });
      _hideDropdown();
      return;
    }

    // Capture render box dimensions
    _measureFieldWidth();

    _debounceTimer = Timer(widget.debounceDuration, () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_activeRequestId;
    setState(() => _isLoading = true);
    _showDropdown();

    final service = ref.read(photonGeocodingServiceProvider);
    final results = await service.search(
      query: query,
      type: widget.searchType,
      latitude: widget.latitude,
      longitude: widget.longitude,
      limit: widget.limit,
    );

    if (!mounted || requestId != _activeRequestId) return;

    setState(() {
      _isLoading = false;
      _suggestions = results;
    });

    if (_suggestions.isEmpty && query.trim().length >= widget.minChars) {
      // Keep overlay showing so empty state is visible
      _showDropdown();
    } else if (_suggestions.isNotEmpty) {
      _showDropdown();
    } else {
      _hideDropdown();
    }
  }

  void _selectPlace(PhotonPlace place) {
    _debounceTimer?.cancel();
    _hideDropdown();

    widget.onPlaceSelected?.call(place);
  }

  IconData get _typeIcon {
    switch (widget.searchType) {
      case PhotonSearchType.city:
        return Icons.location_city_rounded;
      case PhotonSearchType.state:
        return Icons.map_outlined;
      case PhotonSearchType.venue:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    Widget? effectiveSuffix;
    if (_isLoading) {
      effectiveSuffix = Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16.0,
          height: 16.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: colors.primary,
          ),
        ),
      );
    } else if (_controller.text.isNotEmpty && widget.enabled) {
      effectiveSuffix = IconButton(
        icon: Icon(
          Icons.clear_rounded,
          size: 18.0,
          color: colors.textSecondary,
        ),
        tooltip: 'Clear',
        onPressed: () {
          _controller.clear();
          widget.onChanged?.call('');
          _debounceTimer?.cancel();
          setState(() {
            _suggestions = const [];
            _isLoading = false;
          });
          _hideDropdown();
        },
      );
    }

    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) => _hideDropdown(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _portalController,
          overlayChildBuilder: (overlayContext) =>
              _buildDropdownOverlay(overlayContext, colors, textTheme),
          child: AppTextField(
            controller: _controller,
            focusNode: _focusNode,
            label: widget.label,
            hint: widget.hint,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: effectiveSuffix,
            enabled: widget.enabled,
            onChanged: _onTextChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownOverlay(
    BuildContext context,
    dynamic colors,
    TextTheme textTheme,
  ) {
    return Positioned(
      width: _fieldWidth > 50 ? _fieldWidth : 320.0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4.0),
        child: TapRegion(
          groupId: _tapRegionGroupId,
          child: Material(
            elevation: 8.0,
            shadowColor: colors.primaryDark,
            color: colors.surface,
            borderRadius: AppRadius.brLarge,
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260.0),
              decoration: BoxDecoration(
                borderRadius: AppRadius.brLarge,
                border: Border.all(color: colors.border, width: 1.0),
              ),
              child: _buildDropdownContent(colors, textTheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent(dynamic colors, TextTheme textTheme) {
    if (_isLoading && _suggestions.isEmpty) {
      return Padding(
        padding: AppSpacing.insetAll20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: colors.primary,
              ),
            ),
            AppSpacing.gapW12,
            Text(
              'Searching locations...',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: AppSpacing.insetAll20,
        child: Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 20.0,
              color: colors.textSecondary,
            ),
            AppSpacing.gapW12,
            Expanded(
              child: Text(
                'No matching locations found.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1.0, thickness: 0.5, color: colors.divider),
      itemBuilder: (context, index) {
        final place = _suggestions[index];
        final subtitle = place.secondarySubtitle;

        return InkWell(
          onTap: () => _selectPlace(place),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32.0,
                  height: 32.0,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: AppRadius.brSmall,
                    border: Border.all(color: colors.border, width: 0.8),
                  ),
                  child: Icon(_typeIcon, size: 16.0, color: colors.primary),
                ),
                AppSpacing.gapW12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        place.primaryTitle,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        AppSpacing.gapH2,
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11.0,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (place.countryCode != null &&
                    place.countryCode!.isNotEmpty) ...[
                  AppSpacing.gapW8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: AppRadius.brSmall,
                      border: Border.all(color: colors.border, width: 0.6),
                    ),
                    child: Text(
                      place.countryCode!,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
