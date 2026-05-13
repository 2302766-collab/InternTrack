class AppNotification {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? type;
  final Map<String, dynamic>? meta;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.type,
    this.meta,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: _parseBool(json['is_read']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      type: () {
        final raw = json['type']?.toString().trim();
        if (raw == null || raw.isEmpty) return null;
        return raw;
      }(),
      meta: _parseMeta(json['meta']),
    );
  }

  static Map<String, dynamic>? _parseMeta(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      try {
        return value.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {
        return null;
      }
    }
    return null;
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
    String? type,
    Map<String, dynamic>? meta,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      meta: meta ?? this.meta,
    );
  }
}
