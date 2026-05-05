import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/models/student_report.dart';
import 'package:intern_track_app/shared/models/supervisor_dashboard_summary.dart';

void main() {
  group('StudentReport models', () {
    test('parse numeric summary fields from strings', () {
      final summary = StudentReportSummary.fromJson({
        'approved_hours': '8',
        'total_approved_hours': '120',
        'required_hours': '486',
        'completion_percentage': '24.69',
      });

      expect(summary.approvedHours, 8);
      expect(summary.totalApprovedHours, 120);
      expect(summary.requiredHours, 486);
      expect(summary.completionPercentage, 24.69);
    });

    test('parse person id from string and default missing values', () {
      final person = StudentReportPerson.fromJson({'id': '5'});

      expect(person.id, 5);
      expect(person.name, '');
      expect(person.email, '');
    });
  });

  group('SupervisorDashboardSummary', () {
    test('parses numeric fields from strings', () {
      final summary = SupervisorDashboardSummary.fromJson({
        'pending_review': '3',
        'approved_today': '2',
        'total_students': '12',
      });

      expect(summary.pendingReview, 3);
      expect(summary.approvedToday, 2);
      expect(summary.totalStudents, 12);
    });

    test('uses safe defaults for missing values', () {
      final summary = SupervisorDashboardSummary.fromJson({});

      expect(summary.pendingReview, 0);
      expect(summary.approvedToday, 0);
      expect(summary.totalStudents, 0);
    });
  });
}
