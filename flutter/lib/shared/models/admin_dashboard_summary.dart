class AdminDashboardSummary {
  final int totalStudents;
  final int pendingLogs;
  final int approvedLogs;
  final int studentsWithoutProfile;
  final int studentsWithoutSupervisor;
  final int studentsWithoutAdviser;
  final int studentsRequiringAttention;
  final int maleStudents;
  final int femaleStudents;
  final int unspecifiedStudents;
  final double averageCompletionPercentage;
  final String logsPerDayMonth;
  final List<AdminDashboardLogPoint> logsPerDay;

  const AdminDashboardSummary({
    required this.totalStudents,
    required this.pendingLogs,
    required this.approvedLogs,
    required this.studentsWithoutProfile,
    required this.studentsWithoutSupervisor,
    required this.studentsWithoutAdviser,
    required this.studentsRequiringAttention,
    required this.maleStudents,
    required this.femaleStudents,
    required this.unspecifiedStudents,
    required this.averageCompletionPercentage,
    required this.logsPerDayMonth,
    required this.logsPerDay,
  });

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      totalStudents: _parseInt(json['total_students']),
      pendingLogs: _parseInt(json['pending_logs']),
      approvedLogs: _parseInt(json['approved_logs']),
      studentsWithoutProfile: _parseInt(json['students_without_profile']),
      studentsWithoutSupervisor: _parseInt(json['students_without_supervisor']),
      studentsWithoutAdviser: _parseInt(json['students_without_adviser']),
      studentsRequiringAttention: _parseInt(
        json['students_requiring_attention'],
      ),
      maleStudents: _parseInt(json['male_students']),
      femaleStudents: _parseInt(json['female_students']),
      unspecifiedStudents: _parseInt(json['unspecified_students']),
      averageCompletionPercentage: _parseDouble(
        json['average_completion_percentage'],
      ),
      logsPerDayMonth: json['logs_per_day_month']?.toString() ?? '',
      logsPerDay: (json['logs_per_day'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminDashboardLogPoint.fromJson)
          .toList(),
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

class AdminDashboardLogPoint {
  final String date;
  final int day;
  final int totalLogs;

  const AdminDashboardLogPoint({
    required this.date,
    required this.day,
    required this.totalLogs,
  });

  factory AdminDashboardLogPoint.fromJson(Map<String, dynamic> json) {
    return AdminDashboardLogPoint(
      date: json['date']?.toString() ?? '',
      day: AdminDashboardSummary._parseInt(json['day']),
      totalLogs: AdminDashboardSummary._parseInt(json['total_logs']),
    );
  }
}
