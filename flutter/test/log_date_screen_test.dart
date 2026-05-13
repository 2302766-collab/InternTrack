import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/logbook_service.dart';
import 'package:intern_track_app/features/logbook/presentation/log_date_policy.dart';
import 'package:intern_track_app/features/logbook/presentation/screens/log_edit_screen.dart';
import 'package:intern_track_app/features/logbook/presentation/screens/log_submission_screen.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';

void main() {
  group('Student log date screens', () {
    testWidgets('add log submits a selected yesterday date', (tester) async {
      final service = _FakeLogbookService();
      final yesterday = LogDatePolicy.today().subtract(const Duration(days: 1));
      final yesterdayText = LogDatePolicy.formatForApi(yesterday);

      await tester.pumpWidget(
        _buildTestApp(LogSubmissionScreen(token: 'token', service: service)),
      );

      expect(find.text(LogDatePolicy.helperText), findsOneWidget);

      await _chooseYesterday(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Task Description'),
        'Completed assigned work.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Log'));
      await tester.pumpAndSettle();

      expect(service.createdDate, yesterdayText);
    });

    testWidgets('edit log saves a selected yesterday date', (tester) async {
      final service = _FakeLogbookService();
      final todayText = LogDatePolicy.formatForApi(LogDatePolicy.today());
      final yesterday = LogDatePolicy.today().subtract(const Duration(days: 1));
      final yesterdayText = LogDatePolicy.formatForApi(yesterday);

      await tester.pumpWidget(
        _buildTestApp(
          LogEditScreen(
            log: _buildLog(date: todayText),
            service: service,
          ),
        ),
      );

      expect(find.text(LogDatePolicy.helperText), findsOneWidget);

      await _chooseYesterday(tester);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(service.updatedDate, yesterdayText);
    });
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: child);
}

Future<void> _chooseYesterday(WidgetTester tester) async {
  final yesterday = LogDatePolicy.today().subtract(const Duration(days: 1));

  await tester.tap(find.byIcon(Icons.calendar_today));
  await tester.pumpAndSettle();
  await tester.tap(find.text('${yesterday.day}').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

LogEntryItem _buildLog({
  String? date,
  int hoursRendered = 8,
  String taskDescription = 'Completed assigned work.',
  String status = 'PENDING',
}) {
  return LogEntryItem(
    id: 1,
    internshipProfileId: 1,
    date: date ?? LogDatePolicy.formatForApi(LogDatePolicy.today()),
    hoursRendered: hoursRendered,
    taskDescription: taskDescription,
    status: status,
    attachments: const <LogAttachment>[],
    attachmentsCount: 0,
    reviewHistory: const <LogReviewActionItem>[],
  );
}

class _FakeLogbookService extends LogbookService {
  String? createdDate;
  String? updatedDate;

  @override
  Future<LogEntryItem> createLog({
    required String date,
    required int hoursRendered,
    required String taskDescription,
  }) async {
    createdDate = date;

    return _buildLog(
      date: date,
      hoursRendered: hoursRendered,
      taskDescription: taskDescription,
    );
  }

  @override
  Future<LogEntryItem> updateLog({
    required int id,
    required String date,
    required int hoursRendered,
    required String taskDescription,
  }) async {
    updatedDate = date;

    return _buildLog(
      date: date,
      hoursRendered: hoursRendered,
      taskDescription: taskDescription,
    );
  }
}
