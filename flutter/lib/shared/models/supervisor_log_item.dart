import 'log_attachment.dart';
import 'log_review_action.dart';

class SupervisorLogItem {
  final int id;
  final int internshipProfileId;
  final String studentName;
  final String? studentEmail;
  final String? companyName;
  final String date;
  final int hoursRendered;
  final String taskDescription;
  final String status;
  final String? submittedAt;
  final List<LogAttachment> attachments;
  final int attachmentsCount;
  final List<LogReviewActionItem> reviewHistory;

  const SupervisorLogItem({
    required this.id,
    required this.internshipProfileId,
    required this.studentName,
    required this.date,
    required this.hoursRendered,
    required this.taskDescription,
    required this.status,
    required this.attachments,
    required this.attachmentsCount,
    required this.reviewHistory,
    this.studentEmail,
    this.companyName,
    this.submittedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get hasAttachments => attachmentsCount > 0 || attachments.isNotEmpty;

  factory SupervisorLogItem.fromJson(Map<String, dynamic> json) {
    final attachmentsJson = json['attachments'];
    final reviewHistoryJson = json['review_history'];
    final student = json['student'];

    final attachments = attachmentsJson is List
        ? attachmentsJson
            .whereType<Map<String, dynamic>>()
            .map(LogAttachment.fromJson)
            .toList()
        : <LogAttachment>[];

    final reviewHistory = reviewHistoryJson is List
        ? reviewHistoryJson
            .whereType<Map<String, dynamic>>()
            .map(LogReviewActionItem.fromJson)
            .toList()
        : <LogReviewActionItem>[];

    return SupervisorLogItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      internshipProfileId: (json['internship_profile_id'] as num?)?.toInt() ?? 0,
      studentName: (json['student_name'] ??
              (student is Map<String, dynamic> ? student['name'] : null) ??
              'Unknown Student')
          .toString(),
      studentEmail: student is Map<String, dynamic>
          ? student['email']?.toString()
          : null,
      companyName: json['company_name']?.toString(),
      date: (json['date'] ?? '').toString(),
      hoursRendered: (json['hours_rendered'] as num?)?.toInt() ?? 0,
      taskDescription: (json['task_description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      submittedAt: json['submitted_at']?.toString(),
      attachments: attachments,
      attachmentsCount:
          (json['attachments_count'] as num?)?.toInt() ?? attachments.length,
      reviewHistory: reviewHistory,
    );
  }
}
