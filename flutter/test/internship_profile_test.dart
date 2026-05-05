import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/models/internship_profile.dart';

void main() {
  group('InternshipProfile', () {
    test('parses numeric fields from strings', () {
      final profile = InternshipProfile.fromJson({
        'id': '9',
        'student_id': '14',
        'company_name': 'Acme Corp',
        'company_address': 'Makati',
        'required_hours': '486',
        'start_date': '2026-04-01',
        'end_date': '2026-06-30',
        'supervisor_id': '3',
        'adviser_id': '8',
        'supervisor_name': 'Sam Reyes',
        'supervisor_email': 'sam@example.com',
      });

      expect(profile.id, 9);
      expect(profile.studentId, 14);
      expect(profile.requiredHours, 486);
      expect(profile.supervisorId, 3);
      expect(profile.adviserId, 8);
    });

    test('uses safe defaults for missing optional values', () {
      final profile = InternshipProfile.fromJson({});

      expect(profile.id, 0);
      expect(profile.studentId, 0);
      expect(profile.companyName, '');
      expect(profile.companyAddress, '');
      expect(profile.requiredHours, 0);
      expect(profile.startDate, '');
      expect(profile.endDate, '');
      expect(profile.supervisorId, isNull);
      expect(profile.adviserId, isNull);
    });
  });
}
