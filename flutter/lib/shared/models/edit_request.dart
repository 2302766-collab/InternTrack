class EditRequestUserSummary {
  final int id;
  final String name;
  final String email;

  const EditRequestUserSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  factory EditRequestUserSummary.fromJson(Map<String, dynamic> json) {
    return EditRequestUserSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}

class EditRequestItem {
  final int id;
  final String resourceType;
  final int resourceId;
  final String status;
  final String reason;
  final String? reviewComment;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final EditRequestUserSummary? requester;
  final EditRequestUserSummary? student;
  final Map<String, dynamic> currentValues;
  final Map<String, dynamic> requestedChanges;

  const EditRequestItem({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.status,
    required this.reason,
    required this.reviewComment,
    required this.reviewedAt,
    required this.createdAt,
    required this.requester,
    required this.student,
    required this.currentValues,
    required this.requestedChanges,
  });

  bool get isLog => resourceType.toUpperCase() == 'LOG';
  bool get isDtr => resourceType.toUpperCase() == 'DTR';

  factory EditRequestItem.fromJson(Map<String, dynamic> json) {
    return EditRequestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      resourceType: (json['resource_type'] ?? '').toString(),
      resourceId: (json['resource_id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      reviewComment: json['review_comment']?.toString(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      requester: _parseUser(json['requester']),
      student: _parseUser(json['student']),
      currentValues: _parseMap(json['current_values']),
      requestedChanges: _parseMap(json['requested_changes']),
    );
  }

  static EditRequestUserSummary? _parseUser(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    return EditRequestUserSummary.fromJson(value);
  }

  static Map<String, dynamic> _parseMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }
}
