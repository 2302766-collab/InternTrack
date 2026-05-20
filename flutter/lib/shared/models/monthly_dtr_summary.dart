class MonthlyDtrSummary {
  const MonthlyDtrSummary({
    required this.month,
    required this.year,
    required this.monthYear,
    required this.studentName,
    required this.companyName,
    required this.regularDays,
    required this.amSchedule,
    required this.pmSchedule,
    required this.notes,
    required this.rows,
  });

  final int month;
  final int year;
  final String monthYear;
  final String studentName;
  final String? companyName;
  final String regularDays;
  final String amSchedule;
  final String pmSchedule;
  final String notes;
  final List<MonthlyDtrRow> rows;

  factory MonthlyDtrSummary.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'] is Map<String, dynamic>
        ? json['schedule'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawRows = json['rows'] is List
        ? json['rows'] as List<dynamic>
        : const <dynamic>[];

    return MonthlyDtrSummary(
      month: _parseInt(json['month']),
      year: _parseInt(json['year']),
      monthYear: (json['month_year'] ?? '').toString(),
      studentName: (json['student_name'] ?? '').toString(),
      companyName: json['company_name']?.toString(),
      regularDays: (schedule['regular_days'] ?? '').toString(),
      amSchedule: (schedule['am_schedule'] ?? '').toString(),
      pmSchedule: (schedule['pm_schedule'] ?? '').toString(),
      notes: (schedule['notes'] ?? '').toString(),
      rows: rawRows
          .whereType<Map<String, dynamic>>()
          .map(MonthlyDtrRow.fromJson)
          .toList(),
    );
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class MonthlyDtrRow {
  const MonthlyDtrRow({
    required this.day,
    required this.amArrival,
    required this.amDeparture,
    required this.pmArrival,
    required this.pmDeparture,
    required this.undertimeHours,
    required this.undertimeMinutes,
    required this.status,
  });

  final int day;
  final String amArrival;
  final String amDeparture;
  final String pmArrival;
  final String pmDeparture;
  final String undertimeHours;
  final String undertimeMinutes;
  final String? status;

  factory MonthlyDtrRow.fromJson(Map<String, dynamic> json) {
    final normalizedSessions = _normalizeSessions(
      amArrival: (json['am_arrival'] ?? '').toString(),
      amDeparture: (json['am_departure'] ?? '').toString(),
      pmArrival: (json['pm_arrival'] ?? '').toString(),
      pmDeparture: (json['pm_departure'] ?? '').toString(),
    );

    return MonthlyDtrRow(
      day: MonthlyDtrSummary._parseInt(json['day']),
      amArrival: normalizedSessions.amArrival,
      amDeparture: normalizedSessions.amDeparture,
      pmArrival: normalizedSessions.pmArrival,
      pmDeparture: normalizedSessions.pmDeparture,
      undertimeHours: (json['undertime_hours'] ?? '').toString(),
      undertimeMinutes: (json['undertime_minutes'] ?? '').toString(),
      status: json['status']?.toString(),
    );
  }

  static ({
    String amArrival,
    String amDeparture,
    String pmArrival,
    String pmDeparture,
  }) _normalizeSessions({
    required String amArrival,
    required String amDeparture,
    required String pmArrival,
    required String pmDeparture,
  }) {
    final trimmedAmArrival = amArrival.trim();
    final trimmedAmDeparture = amDeparture.trim();
    final trimmedPmArrival = pmArrival.trim();
    final trimmedPmDeparture = pmDeparture.trim();

    final pmColumnsEmpty =
        trimmedPmArrival.isEmpty && trimmedPmDeparture.isEmpty;
    final amValues = <String>[
      if (trimmedAmArrival.isNotEmpty) trimmedAmArrival,
      if (trimmedAmDeparture.isNotEmpty) trimmedAmDeparture,
    ];

    final shouldShiftToPm =
        pmColumnsEmpty &&
        amValues.isNotEmpty &&
        amValues.every(_isAfternoonTimeText);

    if (!shouldShiftToPm) {
      return (
        amArrival: trimmedAmArrival,
        amDeparture: trimmedAmDeparture,
        pmArrival: trimmedPmArrival,
        pmDeparture: trimmedPmDeparture,
      );
    }

    return (
      amArrival: '',
      amDeparture: '',
      pmArrival: trimmedAmArrival,
      pmDeparture: trimmedAmDeparture,
    );
  }

  static bool _isAfternoonTimeText(String value) {
    final upper = value.trim().toUpperCase();
    if (upper.isEmpty) return false;
    if (upper.contains('PM')) return true;

    final match = RegExp(r'^(\d{1,2})').firstMatch(upper);
    if (match == null) return false;

    final hour = int.tryParse(match.group(1) ?? '');
    return hour != null && hour >= 12;
  }
}
