import 'package:intl/intl.dart';

import '../../app/constants/app_constants.dart';

/// Formatter for monetary values using standard locale conventions.
abstract final class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: '${AppConstants.defaultCurrencySymbol} ',
    decimalDigits: 0,
  );

  /// Formats a numeric value into a currency string (e.g. `₹ 1,85,000`).
  static String format(num amount) {
    return _formatter.format(amount);
  }

  /// Formats an integer amount in paise into a standard currency string.
  static String formatPaise(int paise) {
    return _formatter.format(paise / 100.0);
  }

  /// Parses a string into a number or returns null.
  static double? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }
}
