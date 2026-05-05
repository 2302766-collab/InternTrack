import 'log_entry.dart';

class InternDetailItem {
  final int id;
  final int studentId;
  final String studentName;
  final String studentEmail;
  final String companyName;
  final String companyAddress;
  final int requiredHours;
  final int completedHours;
  final int totalLogs;
  final int pendingLogs;
  final int approvedLogs;
  final int rejectedLogs;
  final int? supervisorId;
  final int? adviserId;
  final String? supervisorName;
  final String? adviserName;
  final String? startDate;
  final String? endDate;
  final List<LogEntryItem> recentLogs;

  InternDetailItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.companyName,
    required this.companyAddress,
    required this.requiredHours,
    required this.completedHours,
    required this.totalLogs,
    required this.pendingLogs,
    required this.approvedLogs,
    required this.rejectedLogs,
    required this.recentLogs,
    this.supervisorId,
    this.adviserId,
    this.supervisorName,
    this.adviserName,
    this.startDate,
    this.endDate,
  });

  factory InternDetailItem.fromJson(Map<String, dynamic> json) {
    final progress = Map<String, dynamic>.from(
      json['progress'] as Map? ?? const {},
    );
    final recentLogs = (json['recent_logs'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              InternDetailItem._logFromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    return InternDetailItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      studentName: (json['student_name'] ?? '').toString(),
      studentEmail: (json['student_email'] ?? '').toString(),
      companyName: (json['company_name'] ?? '').toString(),
      companyAddress: (json['company_address'] ?? '').toString(),
      requiredHours: (json['required_hours'] as num?)?.toInt() ?? 0,
      completedHours: (progress['completed_hours'] as num?)?.toInt() ?? 0,
      totalLogs: (progress['total_logs'] as num?)?.toInt() ?? 0,
      pendingLogs: (progress['pending_logs'] as num?)?.toInt() ?? 0,
      approvedLogs: (progress['approved_logs'] as num?)?.toInt() ?? 0,
      rejectedLogs: (progress['rejected_logs'] as num?)?.toInt() ?? 0,
      supervisorId: (json['supervisor_id'] as num?)?.toInt(),
      adviserId: (json['adviser_id'] as num?)?.toInt(),
      supervisorName: json['supervisor_name']?.toString(),
      adviserName: json['adviser_name']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      recentLogs: recentLogs,
    );
  }

  static LogEntryItem _logFromJson(Map<String, dynamic> json) {
    return LogEntryItem.fromJson({
      ...json,
      'attachments': const [],
      'review_history': const [],
    });
  }
}
