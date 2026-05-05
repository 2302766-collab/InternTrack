class LogDatePolicy {
  static const int maxBackdateDays = 1;
  static const String helperText = 'Allowed dates: today or yesterday';
  static const String rangeError = 'Date must be today or yesterday';
  static const String futureError = 'Future dates are not allowed';

  const LogDatePolicy._();

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime today() => dateOnly(DateTime.now());

  static DateTime earliestAllowedDate() {
    return today().subtract(const Duration(days: maxBackdateDays));
  }

  static DateTime clampToAllowedRange(DateTime date) {
    final normalized = dateOnly(date);
    final earliest = earliestAllowedDate();
    final latest = today();

    if (normalized.isBefore(earliest)) return earliest;
    if (normalized.isAfter(latest)) return latest;
    return normalized;
  }

  static String formatForApi(DateTime date) {
    final normalized = dateOnly(date);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static String? validate(String? value, {String? serverError}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Date is required';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return 'Invalid date';

    final selected = dateOnly(parsed);
    if (selected.isAfter(today())) return futureError;
    if (selected.isBefore(earliestAllowedDate())) return rangeError;

    return serverError;
  }
}
