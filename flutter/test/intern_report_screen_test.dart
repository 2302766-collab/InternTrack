import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/intern_reporting_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/intern_report_screen.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';
import 'package:intern_track_app/shared/models/student_report.dart';

void main() {
  group('InternReportScreen', () {
    testWidgets('renders approved logs progressively in batches', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        InternReportScreen(
          role: 'supervisor',
          studentId: 1,
          studentName: 'Sample Student',
          service: _FakeInternReportingService([
            _buildReport(logCount: 45, prefix: 'Task'),
          ]),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Showing 20 of 45 logs'), findsOneWidget);
      expect(find.text('25 remaining'), findsOneWidget);
      expect(find.text('Task 20'), findsOneWidget);
      expect(find.text('Task 21'), findsNothing);
      expect(find.text('225 hrs'), findsOneWidget);

      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 40 of 45 logs'), findsOneWidget);
      expect(find.text('5 remaining'), findsOneWidget);
      expect(find.text('Task 40'), findsOneWidget);
      expect(find.text('Task 41'), findsNothing);

      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 45 of 45 logs'), findsOneWidget);
      expect(find.text('Task 45'), findsOneWidget);
      expect(find.text('Show More'), findsNothing);
      expect(find.textContaining('remaining'), findsNothing);
    });

    testWidgets('resets visible count when the report reloads', (tester) async {
      final service = _FakeInternReportingService([
        _buildReport(logCount: 45, prefix: 'Initial'),
        _buildReport(logCount: 30, prefix: 'Reloaded'),
      ]);

      await _pumpScreen(
        tester,
        InternReportScreen(
          role: 'supervisor',
          studentId: 1,
          studentName: 'Sample Student',
          service: service,
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 40 of 45 logs'), findsOneWidget);
      expect(find.text('Initial 40'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(service.getReportCalls, 2);
      expect(find.text('Showing 20 of 30 logs'), findsOneWidget);
      expect(find.text('10 remaining'), findsOneWidget);
      expect(find.text('Reloaded 20'), findsOneWidget);
      expect(find.text('Reloaded 21'), findsNothing);
      expect(find.text('Show More'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: child));
}

StudentReportData _buildReport({
  required int logCount,
  required String prefix,
}) {
  return StudentReportData(
    student: const StudentReportPerson(
      id: 1,
      name: 'Sample Student',
      email: 'student@example.com',
    ),
    supervisor: const StudentReportPerson(
      id: 2,
      name: 'Supervisor',
      email: 'supervisor@example.com',
    ),
    dateRange: const StudentReportDateRange(),
    logs: List<LogEntryItem>.generate(
      logCount,
      (index) => _buildLogEntry(
        id: index + 1,
        date: '2026-01-${((index % 28) + 1).toString().padLeft(2, '0')}',
        taskDescription: '$prefix ${index + 1}',
        hoursRendered: 5,
      ),
    ),
    summary: StudentReportSummary(
      approvedHours: logCount * 5,
      totalApprovedHours: logCount * 5,
      requiredHours: 600,
      completionPercentage: 37.5,
    ),
  );
}

LogEntryItem _buildLogEntry({
  required int id,
  required String date,
  required String taskDescription,
  required int hoursRendered,
}) {
  return LogEntryItem(
    id: id,
    internshipProfileId: 1,
    date: date,
    hoursRendered: hoursRendered,
    taskDescription: taskDescription,
    status: 'APPROVED',
    attachments: const <LogAttachment>[],
    attachmentsCount: 0,
    reviewHistory: const <LogReviewActionItem>[],
  );
}

class _FakeInternReportingService extends InternReportingService {
  _FakeInternReportingService(this._reports);

  final List<StudentReportData> _reports;
  int _index = 0;
  int getReportCalls = 0;

  @override
  Future<StudentReportData> getReport({
    required String role,
    required int studentId,
    String? startDate,
    String? endDate,
  }) async {
    getReportCalls += 1;
    final report =
        _reports[_index < _reports.length ? _index : _reports.length - 1];
    if (_index < _reports.length - 1) {
      _index += 1;
    }
    return report;
  }
}
