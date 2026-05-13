import 'package:intern_track_app/shared/models/app_notification.dart';

/// Route arguments for [AppRoutes.logbook] when opening from a notification.
class LogbookNavArgs {
  const LogbookNavArgs({this.logId});

  /// When set, logbook opens this log’s detail after the list loads (if found).
  final int? logId;
}

enum StudentNotificationRouteKind { logbook, report }

/// Resolved in-app navigation for a student notification tap.
class StudentNotificationRoute {
  const StudentNotificationRoute._({
    required this.kind,
    this.logId,
  });

  final StudentNotificationRouteKind kind;

  /// Log id when [kind] is [StudentNotificationRouteKind.logbook] and payload
  /// includes a target; otherwise null (open logbook list only).
  final int? logId;

  const StudentNotificationRoute.logbook({int? logId})
      : this._(kind: StudentNotificationRouteKind.logbook, logId: logId);

  const StudentNotificationRoute.report()
      : this._(kind: StudentNotificationRouteKind.report);

  /// Maps API `type` + `meta` to a student navigation target.
  /// Returns null when no safe route is inferred (caller shows a short fallback).
  static StudentNotificationRoute? resolve(AppNotification notification) {
    final rawType = (notification.type ?? '').trim();
    final normalized = rawType.toLowerCase().replaceAll('-', '_');
    final meta = notification.meta;

    int? logIdFromMeta;
    if (meta != null) {
      logIdFromMeta = _readPositiveInt(
        meta['log_id'] ?? meta['logId'] ?? meta['target_id'] ?? meta['targetId'],
      );
    }

    if (normalized.isNotEmpty) {
      if (_isLogType(normalized)) {
        return StudentNotificationRoute.logbook(logId: logIdFromMeta);
      }
      if (_isReportType(normalized)) {
        return StudentNotificationRoute.report();
      }
      return null;
    }

    // Legacy rows (no `type`): infer from title only — conservative.
    final title = notification.title.toLowerCase();
    if (title.contains('log') &&
        (title.contains('approv') ||
            title.contains('reject') ||
            title.contains('pending'))) {
      return StudentNotificationRoute.logbook(logId: logIdFromMeta);
    }
    if (title.contains('report')) {
      return StudentNotificationRoute.report();
    }

    return null;
  }

  static bool _isLogType(String normalized) {
    if (normalized.startsWith('log_')) return true;
    if (normalized.startsWith('daily_log')) return true;
    if (normalized.startsWith('logbook')) return true;
    if (normalized.startsWith('log_entry')) return true;
    return normalized == 'log';
  }

  static bool _isReportType(String normalized) {
    const keys = <String>[
      'report',
      'student_report',
      'internship_report',
      'report_ready',
      'report_summary',
    ];
    for (final k in keys) {
      if (normalized == k || normalized.startsWith(k)) return true;
    }
    return normalized.contains('report');
  }

  static int? _readPositiveInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final i = value.toInt();
      return i > 0 ? i : null;
    }
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}
