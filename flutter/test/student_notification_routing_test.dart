import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/features/student/navigation/student_notification_routing.dart';
import 'package:intern_track_app/shared/models/app_notification.dart';

AppNotification _n({
  String? type,
  Map<String, dynamic>? meta,
  String title = 'Notice',
}) {
  return AppNotification(
    id: 1,
    title: title,
    message: 'Body',
    isRead: false,
    createdAt: DateTime(2026, 5, 1),
    type: type,
    meta: meta,
  );
}

void main() {
  group('StudentNotificationRoute.resolve', () {
    test('log_approved with log_id maps to logbook with id', () {
      final r = StudentNotificationRoute.resolve(
        _n(type: 'log_approved', meta: {'log_id': 42}),
      );
      expect(r?.kind, StudentNotificationRouteKind.logbook);
      expect(r?.logId, 42);
    });

    test('log-rejected normalizes hyphen to underscore', () {
      final r = StudentNotificationRoute.resolve(
        _n(type: 'log-rejected', meta: {'logId': 7}),
      );
      expect(r?.kind, StudentNotificationRouteKind.logbook);
      expect(r?.logId, 7);
    });

    test('report types map to report screen', () {
      for (final t in ['report', 'student_report', 'report_ready', 'internship_report']) {
        final r = StudentNotificationRoute.resolve(_n(type: t));
        expect(r?.kind, StudentNotificationRouteKind.report, reason: t);
        expect(r?.logId, isNull);
      }
    });

    test('missing log id still maps to logbook list', () {
      final r = StudentNotificationRoute.resolve(_n(type: 'log_approved'));
      expect(r?.kind, StudentNotificationRouteKind.logbook);
      expect(r?.logId, isNull);
    });

    test('unknown explicit type returns null', () {
      expect(
        StudentNotificationRoute.resolve(_n(type: 'billing_invoice')),
        isNull,
      );
    });

    test('malformed meta log_id does not throw and yields null log id', () {
      final r = StudentNotificationRoute.resolve(
        _n(type: 'log_approved', meta: {'log_id': 'not-a-number'}),
      );
      expect(r?.kind, StudentNotificationRouteKind.logbook);
      expect(r?.logId, isNull);
    });

    test('legacy title log approved maps to logbook without id', () {
      final r = StudentNotificationRoute.resolve(
        _n(title: 'Log approved', type: null),
      );
      expect(r?.kind, StudentNotificationRouteKind.logbook);
      expect(r?.logId, isNull);
    });

    test('meta accepts non-string keys from json-like map', () {
      final r = StudentNotificationRoute.resolve(
        AppNotification.fromJson({
          'id': 1,
          'title': 'x',
          'message': 'y',
          'is_read': false,
          'created_at': '2026-01-01T00:00:00Z',
          'type': 'log_approved',
          'meta': {'log_id': 99},
        }),
      );
      expect(r?.logId, 99);
    });
  });
}
