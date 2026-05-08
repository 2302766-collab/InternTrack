class AdminDashboardSummary {
  final int totalStudents;
  final int pendingLogs;
  final int approvedLogs;
  final int studentsWithoutProfile;
  final int studentsWithoutSupervisor;
  final int studentsWithoutAdviser;
  final int studentsRequiringAttention;
  final double averageCompletionPercentage;

  const AdminDashboardSummary({
    required this.totalStudents,
    required this.pendingLogs,
    required this.approvedLogs,
    required this.studentsWithoutProfile,
    required this.studentsWithoutSupervisor,
    required this.studentsWithoutAdviser,
    required this.studentsRequiringAttention,
    required this.averageCompletionPercentage,
  });

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      totalStudents: _parseInt(json['total_students']),
      pendingLogs: _parseInt(json['pending_logs']),
      approvedLogs: _parseInt(json['approved_logs']),
      studentsWithoutProfile: _parseInt(json['students_without_profile']),
      studentsWithoutSupervisor: _parseInt(json['students_without_supervisor']),
      studentsWithoutAdviser: _parseInt(json['students_without_adviser']),
      studentsRequiringAttention: _parseInt(json['students_requiring_attention']),
      averageCompletionPercentage: _parseDouble(
        json['average_completion_percentage'],
      ),
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
