class LogReviewActionItem {
  final int id;
  final String action;
  final String? comment;
  final String? actedAt;
  final int? supervisorId;
  final String? supervisorName;
  final String? supervisorEmail;

  const LogReviewActionItem({
    required this.id,
    required this.action,
    this.comment,
    this.actedAt,
    this.supervisorId,
    this.supervisorName,
    this.supervisorEmail,
  });

  bool get hasComment => (comment ?? '').trim().isNotEmpty;

  factory LogReviewActionItem.fromJson(Map<String, dynamic> json) {
    final supervisor = json['supervisor'];

    return LogReviewActionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      action: (json['action'] ?? '').toString(),
      comment: json['comment']?.toString(),
      actedAt: json['acted_at']?.toString(),
      supervisorId: supervisor is Map<String, dynamic>
          ? (supervisor['id'] as num?)?.toInt()
          : null,
      supervisorName: supervisor is Map<String, dynamic>
          ? supervisor['name']?.toString()
          : null,
      supervisorEmail: supervisor is Map<String, dynamic>
          ? supervisor['email']?.toString()
          : null,
    );
  }
}
