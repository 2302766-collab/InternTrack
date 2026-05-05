import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/models/intern_list_item.dart';

void main() {
  group('InternListItem adviser alerts', () {
    test('parses backend-provided alert fields', () {
      final intern = InternListItem.fromJson({
        'id': 1,
        'student_id': 7,
        'student_name': 'Ana Cruz',
        'company_name': 'Acme Corp',
        'required_hours': 160,
        'completed_hours': 40,
        'alert_status': 'BEHIND',
        'alert_message': 'Behind expected pace.',
        'alert_severity': 'warning',
        'alert': {
          'status': 'BEHIND',
          'message': 'Behind expected pace.',
          'severity': 'warning',
          'meta': {'server_date': '2026-04-20', 'expected_hours_by_now': 88},
        },
      });

      expect(intern.alertStatus, 'BEHIND');
      expect(intern.alertMessage, 'Behind expected pace.');
      expect(intern.alertSeverity, 'warning');
      expect(intern.alertMeta['server_date'], '2026-04-20');
      expect(intern.alertMeta['expected_hours_by_now'], 88);
      expect(intern.hasActiveAlert, isTrue);
    });

    test('defaults to on track when alert fields are absent', () {
      final intern = InternListItem.fromJson({
        'id': 1,
        'student_id': 7,
        'student_name': 'Ana Cruz',
        'company_name': 'Acme Corp',
        'required_hours': 160,
      });

      expect(intern.alertStatus, 'ON_TRACK');
      expect(intern.hasActiveAlert, isFalse);
    });

    test('parses numeric fields from strings', () {
      final intern = InternListItem.fromJson({
        'id': '12',
        'student_id': '7',
        'student_name': 'Ana Cruz',
        'company_name': 'Acme Corp',
        'required_hours': '160',
        'supervisor_id': '4',
        'adviser_id': '5',
      });

      expect(intern.id, 12);
      expect(intern.studentId, 7);
      expect(intern.requiredHours, 160);
      expect(intern.supervisorId, 4);
      expect(intern.adviserId, 5);
    });
  });
}
