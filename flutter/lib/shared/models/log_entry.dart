import 'log_attachment.dart';
import 'log_review_action.dart';

class LogEntryItem {
  final int id;
  final int internshipProfileId;
  final String date;
  final int hoursRendered;
  final String taskDescription;
  final String status;
  final String? submittedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<LogAttachment> attachments;
  final int attachmentsCount;
  final List<LogReviewActionItem> reviewHistory;

  LogEntryItem({
    required this.id,
    required this.internshipProfileId,
    required this.date,
    required this.hoursRendered,
    required this.taskDescription,
    required this.status,
    required this.attachments,
    required this.attachmentsCount,
    required this.reviewHistory,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory LogEntryItem.fromJson(Map<String, dynamic> json) {
    final attachmentList = json['attachments'];
    final reviewHistoryList = json['review_history'];
    final attachments = attachmentList is List
        ? attachmentList
            .whereType<Map<String, dynamic>>()
            .map(LogAttachment.fromJson)
            .toList()
        : <LogAttachment>[];
    final reviewHistory = reviewHistoryList is List
        ? reviewHistoryList
            .whereType<Map<String, dynamic>>()
            .map(LogReviewActionItem.fromJson)
            .toList()
        : <LogReviewActionItem>[];
    final attachmentsCount = (json['attachments_count'] as num?)?.toInt();

    return LogEntryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      internshipProfileId: (json['internship_profile_id'] as num?)?.toInt() ?? 0,
      date: (json['date'] ?? '').toString(),
      hoursRendered: (json['hours_rendered'] as num?)?.toInt() ?? 0,
      taskDescription: (json['task_description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      submittedAt: json['submitted_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      attachments: attachments,
      attachmentsCount: attachmentsCount ?? attachments.length,
      reviewHistory: reviewHistory,
    );
  }
}
