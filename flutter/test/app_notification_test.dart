import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/models/app_notification.dart';

void main() {
  group('AppNotification', () {
    test('parses numeric id and boolean read status from strings', () {
      final notification = AppNotification.fromJson({
        'id': '42',
        'title': 'Log approved',
        'message': 'Your daily log was approved.',
        'is_read': '1',
        'created_at': '2026-04-20T12:30:00Z',
      });

      expect(notification.id, 42);
      expect(notification.title, 'Log approved');
      expect(notification.message, 'Your daily log was approved.');
      expect(notification.isRead, isTrue);
      expect(notification.createdAt, isNotNull);
    });

    test('parses numeric read status and falls back safely for bad id', () {
      final notification = AppNotification.fromJson({
        'id': null,
        'is_read': 0,
      });

      expect(notification.id, 0);
      expect(notification.isRead, isFalse);
      expect(notification.title, '');
      expect(notification.message, '');
      expect(notification.createdAt, isNull);
    });
  });
}
