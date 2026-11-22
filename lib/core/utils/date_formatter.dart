import 'package:intl/intl.dart';

/// Formatter for exhibition dates and ledger timestamps.
abstract final class DateFormatter {
  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _longFormat = DateFormat('EEEE, dd MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('MMM dd');

  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Formats a [DateTime] into a standard display date (e.g. `21 Nov 2026`).
  static String formatDisplay(DateTime date) => _displayFormat.format(date);

  /// Alias for formatDisplay.
  static String formatDate(DateTime date) => _displayFormat.format(date);

  /// Formats a [DateTime] into a date and time string (e.g. `21 Nov 2026, 02:30 PM`).
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Formats a [DateTime] into a formal editorial date (e.g. `Friday, 21 November 2026`).
  static String formatLong(DateTime date) => _longFormat.format(date);

  /// Formats a date range (e.g. `Nov 15 - Nov 28, 2026`).
  static String formatRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      return '${_shortDate.format(start)} – ${_displayFormat.format(end)}';
    }
    return '${_displayFormat.format(start)} – ${_displayFormat.format(end)}';
  }
}
