import 'package:flutter/material.dart';

import '../../app/constants/app_constants.dart';
import '../../app/theme/app_colors.dart';

/// Extension methods on [BuildContext] for ergonomic theme, color, and layout access.
extension ContextExtensions on BuildContext {
  /// Retrieves the active [AppColorScheme] token set
  AppColorScheme get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorScheme>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }

  /// Retrieves the current [TextTheme]
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Check if the active theme is in dark mode
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// MediaQuery data
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen dimensions
  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;

  /// Responsive layout helpers
  bool get isMobile => screenWidth < AppConstants.mobileBreakpoint;
  bool get isTablet =>
      screenWidth >= AppConstants.mobileBreakpoint &&
      screenWidth < AppConstants.tabletBreakpoint;
  bool get isDesktop => screenWidth >= AppConstants.tabletBreakpoint;
}
