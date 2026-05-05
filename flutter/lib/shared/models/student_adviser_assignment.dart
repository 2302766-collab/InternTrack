import 'adviser_info.dart';

class StudentAdviserAssignment {
  final int studentId;
  final String studentName;
  final int? adviserId;
  final String? adviserName;
  final DateTime? assignedAt;

  const StudentAdviserAssignment({
    required this.studentId,
    required this.studentName,
    required this.adviserId,
    required this.adviserName,
    required this.assignedAt,
  });

  factory StudentAdviserAssignment.fromJson(Map<String, dynamic> json) {
    return StudentAdviserAssignment(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      studentName: (json['student_name'] ?? '').toString(),
      adviserId: (json['adviser_id'] as num?)?.toInt(),
      adviserName: json['adviser_name']?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
    );
  }

  @override
  String toString() =>
      'StudentAdviserAssignment(studentId: $studentId, studentName: $studentName, adviserId: $adviserId, adviserName: $adviserName, assignedAt: $assignedAt)';
}
