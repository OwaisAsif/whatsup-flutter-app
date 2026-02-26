// helpers/date_helper.dart
import 'package:intl/intl.dart';

class DateHelper {
  /// Converts a timestamp in milliseconds to a formatted date string.
  /// Example format: "21 Feb 2026, 02:15 PM"
  static String formatTimestamp(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  /// Optional: just get "time only" (hh:mm AM/PM)
  static String formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('hh:mm a').format(date);
  }
}
