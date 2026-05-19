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
    return MonthlyDtrRow(
      day: MonthlyDtrSummary._parseInt(json['day']),
      amArrival: (json['am_arrival'] ?? '').toString(),
      amDeparture: (json['am_departure'] ?? '').toString(),
      pmArrival: (json['pm_arrival'] ?? '').toString(),
      pmDeparture: (json['pm_departure'] ?? '').toString(),
      undertimeHours: (json['undertime_hours'] ?? '').toString(),
      undertimeMinutes: (json['undertime_minutes'] ?? '').toString(),
      status: json['status']?.toString(),
    );
  }
}
