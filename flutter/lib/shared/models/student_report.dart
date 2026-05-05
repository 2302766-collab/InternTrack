import 'log_entry.dart';

class StudentReportPerson {
  final int id;
  final String name;
  final String email;

  const StudentReportPerson({
    required this.id,
    required this.name,
    required this.email,
  });

  factory StudentReportPerson.fromJson(Map<String, dynamic> json) {
    return StudentReportPerson(
      id: _parseInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StudentReportDateRange {
  final String? startDate;
  final String? endDate;

  const StudentReportDateRange({
    this.startDate,
    this.endDate,
  });

  factory StudentReportDateRange.fromJson(Map<String, dynamic> json) {
    return StudentReportDateRange(
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
    );
  }
}

class StudentReportSummary {
  final int approvedHours;
  final int totalApprovedHours;
  final int requiredHours;
  final double completionPercentage;

  const StudentReportSummary({
    required this.approvedHours,
    required this.totalApprovedHours,
    required this.requiredHours,
    required this.completionPercentage,
  });

  factory StudentReportSummary.fromJson(Map<String, dynamic> json) {
    return StudentReportSummary(
      approvedHours: _parseInt(json['approved_hours']),
      totalApprovedHours: _parseInt(json['total_approved_hours']),
      requiredHours: _parseInt(json['required_hours']),
      completionPercentage: _parseDouble(json['completion_percentage']),
    );
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StudentReportData {
  final StudentReportPerson student;
  final StudentReportPerson supervisor;
  final StudentReportDateRange dateRange;
  final List<LogEntryItem> logs;
  final StudentReportSummary summary;

  const StudentReportData({
    required this.student,
    required this.supervisor,
    required this.dateRange,
    required this.logs,
    required this.summary,
  });

  factory StudentReportData.fromJson(Map<String, dynamic> json) {
    final logsJson = json['logs'];

    return StudentReportData(
      student: StudentReportPerson.fromJson(
        (json['student'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      supervisor: StudentReportPerson.fromJson(
        (json['supervisor'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      dateRange: StudentReportDateRange.fromJson(
        (json['date_range'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      logs: logsJson is List
          ? logsJson
              .whereType<Map<String, dynamic>>()
              .map(LogEntryItem.fromJson)
              .toList()
          : <LogEntryItem>[],
      summary: StudentReportSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}
