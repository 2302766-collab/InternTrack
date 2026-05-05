class SupervisorDashboardSummary {
  final int pendingReview;
  final int approvedToday;
  final int totalStudents;

  const SupervisorDashboardSummary({
    required this.pendingReview,
    required this.approvedToday,
    required this.totalStudents,
  });

  factory SupervisorDashboardSummary.fromJson(Map<String, dynamic> json) {
    return SupervisorDashboardSummary(
      pendingReview: _parseInt(json['pending_review']),
      approvedToday: _parseInt(json['approved_today']),
      totalStudents: _parseInt(json['total_students']),
    );
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
