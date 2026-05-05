class AppNotification {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: _parseBool(json['is_read']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
