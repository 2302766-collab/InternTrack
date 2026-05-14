class StudentSupervisorAssignment {
  final int studentId;
  final String studentName;
  final int? supervisorId;
  final String? supervisorName;
  final DateTime? assignedAt;

  const StudentSupervisorAssignment({
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedAt,
  });

  factory StudentSupervisorAssignment.fromJson(Map<String, dynamic> json) {
    return StudentSupervisorAssignment(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      studentName: (json['student_name'] ?? '').toString(),
      supervisorId: (json['supervisor_id'] as num?)?.toInt(),
      supervisorName: json['supervisor_name']?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
    );
  }
}
