class AdminStudentSummary {
  final int studentId;
  final String name;
  final String? company;
  final int approvedHours;
  final int requiredHours;
  final double completionPercentage;
  final bool hasInternshipProfile;
  final bool hasSupervisor;
  final bool hasAdviser;

  const AdminStudentSummary({
    required this.studentId,
    required this.name,
    required this.company,
    required this.approvedHours,
    required this.requiredHours,
    required this.completionPercentage,
    required this.hasInternshipProfile,
    required this.hasSupervisor,
    required this.hasAdviser,
  });

  factory AdminStudentSummary.fromJson(Map<String, dynamic> json) {
    return AdminStudentSummary(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      company: json['company']?.toString(),
      approvedHours: (json['approved_hours'] as num?)?.toInt() ?? 0,
      requiredHours: (json['required_hours'] as num?)?.toInt() ?? 0,
      completionPercentage:
          (json['completion_percentage'] as num?)?.toDouble() ?? 0,
      hasInternshipProfile: json['has_internship_profile'] == true,
      hasSupervisor: json['has_supervisor'] == true,
      hasAdviser: json['has_adviser'] == true,
    );
  }
}
