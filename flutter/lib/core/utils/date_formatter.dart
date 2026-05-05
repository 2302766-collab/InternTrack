import 'package:intl/intl.dart';

class DateFormatter {
  const DateFormatter._();

  static String formatTimestamp(DateTime value) {
    return DateFormat('MMM d, y - h:mm a').format(value);
  }

  static String formatDateOnly(DateTime value) {
    return DateFormat('MMM d, y').format(value);
  }

  static String formatApiDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    return formatDateOnly(parsed);
  }

  static String formatMonthYear(DateTime value) {
    return DateFormat('MMMM y').format(value);
  }
}
