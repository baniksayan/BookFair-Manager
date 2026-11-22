/// Application constants for BookFair Manager.
abstract final class AppConstants {
  static const String appName = 'BookFair Manager';
  static const String appVersion = '1.0.0';

  // Responsive Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double maxContentWidth = 840.0;

  // Currency
  static const String defaultCurrencySymbol = '₹';

  // Animation Durations
  static const Duration animDurationShort = Duration(milliseconds: 150);
  static const Duration animDurationNormal = Duration(milliseconds: 300);
  static const Duration animDurationLong = Duration(milliseconds: 500);

  // Snackbar Display Durations
  static const Duration snackbarDuration = Duration(seconds: 4);
}
