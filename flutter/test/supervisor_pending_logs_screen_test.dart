import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/supervisor_log_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/supervisor_log_queue_screen.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';
import 'package:intern_track_app/shared/models/supervisor_log_item.dart';

void main() {
  group('SupervisorPendingLogsScreen', () {
    testWidgets('loads pending logs sorted oldest first', (tester) async {
      final service = _FakeSupervisorLogService(
        pendingLogs: [
          _buildLog(
            id: 2,
            studentName: 'Ana Cruz',
            date: '2026-01-13',
            hoursRendered: 6,
          ),
          _buildLog(
            id: 1,
            studentName: 'Juan Dela Cruz',
            date: '2026-01-12',
            hoursRendered: 8,
          ),
          _buildLog(
            id: 3,
            studentName: 'Reviewed Student',
            date: '2026-01-11',
            hoursRendered: 5,
            status: 'APPROVED',
          ),
        ],
      );

      await _pumpScreen(tester, SupervisorPendingLogsScreen(service: service));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Pending Logs'), findsOneWidget);
      expect(find.text('Student: Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Student: Ana Cruz'), findsOneWidget);
      expect(find.text('Student: Reviewed Student'), findsNothing);
      expect(find.text('Jan 12 (8 hrs)'), findsOneWidget);
      expect(find.text('Status: PENDING'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Student: Juan Dela Cruz')).dy,
        lessThan(tester.getTopLeft(find.text('Student: Ana Cruz')).dy),
      );
    });

    testWidgets('shows empty state when there are no pending logs', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(pendingLogs: const []),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No pending logs to review.'), findsOneWidget);
    });

    testWidgets('shows error state when the network request fails', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: const [],
            pendingLogsError: ApiException(
              message: 'Failed to fetch pending logs.',
              errorType: ApiErrorType.networkError,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch pending logs.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('reloads pending logs when retry is tapped', (tester) async {
      final service = _FakeSupervisorLogService(
        pendingLogs: [
          _buildLog(
            id: 7,
            studentName: 'Ana Cruz',
            date: '2026-01-12',
            hoursRendered: 6,
          ),
        ],
        failuresBeforeSuccess: 1,
      );

      await _pumpScreen(tester, SupervisorPendingLogsScreen(service: service));

      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch pending logs.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch pending logs.'), findsNothing);
      expect(find.text('Student: Ana Cruz'), findsOneWidget);
      expect(service.pendingLogsCalls, 2);
    });

    testWidgets('navigates to review screen and passes log id on tap', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: [
              _buildLog(
                id: 42,
                studentName: 'Juan Dela Cruz',
                date: '2026-01-12',
                hoursRendered: 8,
              ),
            ],
          ),
          reviewScreenBuilder: (context, log, service) {
            return Scaffold(
              appBar: AppBar(title: const Text('Review Screen')),
              body: Text('Log ID: ${log.id}'),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Student: Juan Dela Cruz'));
      await tester.pumpAndSettle();

      expect(find.text('Review Screen'), findsOneWidget);
      expect(find.text('Log ID: 42'), findsOneWidget);
    });

    testWidgets('approved review is removed from pending list', (tester) async {
      final service = _FakeSupervisorLogService(
        pendingLogs: [
          _buildLog(
            id: 42,
            studentName: 'Juan Dela Cruz',
            date: '2026-01-12',
            hoursRendered: 8,
          ),
        ],
      );

      await _pumpScreen(tester, SupervisorPendingLogsScreen(service: service));

      await tester.pumpAndSettle();
      await tester.tap(find.text('Student: Juan Dela Cruz'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('APPROVE'));
      await tester.tap(find.text('APPROVE'));
      await tester.pumpAndSettle();

      expect(service.approveCalls, 1);
      expect(find.text('Student: Juan Dela Cruz'), findsNothing);
      expect(find.text('No pending logs to review.'), findsOneWidget);
    });

    testWidgets('applies search proof filter sort and hours range together', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: [
              _buildLog(
                id: 1,
                studentName: 'Alyssa',
                date: '2026-01-10',
                hoursRendered: 4,
                attachmentsCount: 1,
              ),
              _buildLog(
                id: 2,
                studentName: 'Brenda',
                date: '2026-01-13',
                hoursRendered: 8,
              ),
              _buildLog(
                id: 3,
                studentName: 'Cara',
                date: '2026-01-12',
                hoursRendered: 6,
                attachmentsCount: 2,
              ),
              _buildLog(
                id: 4,
                studentName: 'Dara',
                date: '2026-01-11',
                hoursRendered: 5,
                attachmentsCount: 1,
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(_findSearchField(), 'a');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'With Proof'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Most Hours').last);
      await tester.pumpAndSettle();
      await tester.enterText(_findHoursField('Min hours'), '4.5');
      await tester.pump();
      await tester.enterText(_findHoursField('Max hours'), '6.5');
      await tester.pumpAndSettle();

      expect(find.text('Student: Alyssa'), findsNothing);
      expect(find.text('Student: Brenda'), findsNothing);
      expect(find.text('Student: Cara'), findsOneWidget);
      expect(find.text('Student: Dara'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Student: Cara')).dy,
        lessThan(tester.getTopLeft(find.text('Student: Dara')).dy),
      );
    });

    testWidgets('reset filters restores the original queue state', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: [
              _buildLog(
                id: 2,
                studentName: 'Bella',
                date: '2026-01-12',
                hoursRendered: 6,
              ),
              _buildLog(
                id: 1,
                studentName: 'Ana',
                date: '2026-01-10',
                hoursRendered: 4,
                attachmentsCount: 1,
              ),
              _buildLog(
                id: 3,
                studentName: 'Cara',
                date: '2026-01-14',
                hoursRendered: 8,
                attachmentsCount: 2,
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(_findSearchField(), 'Ana');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'With Proof'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest Pending').last);
      await tester.pumpAndSettle();
      await tester.enterText(_findHoursField('Min hours'), '3');
      await tester.pumpAndSettle();

      expect(find.text('Student: Ana'), findsOneWidget);
      expect(find.text('Student: Bella'), findsNothing);

      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Student: Ana'), findsOneWidget);
      expect(find.text('Student: Bella'), findsOneWidget);
      expect(find.text('Student: Cara'), findsOneWidget);
      expect(_textFieldValue(tester, _findSearchField()), isEmpty);
      expect(_textFieldValue(tester, _findHoursField('Min hours')), isEmpty);
      expect(_textFieldValue(tester, _findHoursField('Max hours')), isEmpty);
      expect(
        tester.getTopLeft(find.text('Student: Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Student: Bella')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Student: Bella')).dy,
        lessThan(tester.getTopLeft(find.text('Student: Cara')).dy),
      );
    });

    testWidgets('ignores invalid hour ranges without crashing', (tester) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: [
              _buildLog(
                id: 1,
                studentName: 'Ana',
                date: '2026-01-10',
                hoursRendered: 4,
              ),
              _buildLog(
                id: 2,
                studentName: 'Ben',
                date: '2026-01-11',
                hoursRendered: 7,
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(_findHoursField('Min hours'), '9');
      await tester.pump();
      await tester.enterText(_findHoursField('Max hours'), '3');
      await tester.pumpAndSettle();

      expect(find.text('Student: Ana'), findsOneWidget);
      expect(find.text('Student: Ben'), findsOneWidget);
      expect(
        find.text(
          'Min hours is greater than max hours, so the hour range is being ignored.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('updates empty state messaging when filters remove all logs', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        SupervisorPendingLogsScreen(
          service: _FakeSupervisorLogService(
            pendingLogs: [
              _buildLog(
                id: 1,
                studentName: 'Ana',
                date: '2026-01-10',
                hoursRendered: 4,
                attachmentsCount: 1,
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Without Proof'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pending logs match the current filters.'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: child);
}

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(_buildTestApp(child));
}

SupervisorLogItem _buildLog({
  required int id,
  required String studentName,
  required String date,
  required int hoursRendered,
  String status = 'PENDING',
  int attachmentsCount = 0,
}) {
  return SupervisorLogItem(
    id: id,
    internshipProfileId: 1,
    studentName: studentName,
    date: date,
    hoursRendered: hoursRendered,
    taskDescription: 'Completed assigned tasks',
    status: status,
    attachments: const <LogAttachment>[],
    attachmentsCount: attachmentsCount,
    reviewHistory: const <LogReviewActionItem>[],
  );
}

Finder _findSearchField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Search by student or date',
  );
}

Finder _findHoursField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

String _textFieldValue(WidgetTester tester, Finder finder) {
  return tester.widget<TextField>(finder).controller?.text ?? '';
}

class _FakeSupervisorLogService extends SupervisorLogService {
  _FakeSupervisorLogService({
    required this.pendingLogs,
    this.pendingLogsError,
    this.failuresBeforeSuccess = 0,
  }) : super(ApiClient(dio: Dio()));

  final List<SupervisorLogItem> pendingLogs;
  final Exception? pendingLogsError;
  final int failuresBeforeSuccess;
  int pendingLogsCalls = 0;
  int approveCalls = 0;

  @override
  Future<List<SupervisorLogItem>> getPendingLogs() async {
    pendingLogsCalls += 1;

    if (pendingLogsCalls <= failuresBeforeSuccess) {
      throw ApiException(
        message: 'Failed to fetch pending logs.',
        errorType: ApiErrorType.networkError,
      );
    }

    if (pendingLogsError != null) {
      throw pendingLogsError!;
    }

    return pendingLogs;
  }

  @override
  Future<SupervisorLogItem> getLog(int id) async {
    return pendingLogs.firstWhere((log) => log.id == id);
  }

  @override
  Future<SupervisorLogItem> approveLog({
    required int id,
    String? comment,
  }) async {
    approveCalls += 1;
    final index = pendingLogs.indexWhere((log) => log.id == id);
    final updated = _replaceStatus(pendingLogs[index], 'APPROVED');
    pendingLogs[index] = updated;
    return updated;
  }
}

SupervisorLogItem _replaceStatus(SupervisorLogItem log, String status) {
  return SupervisorLogItem(
    id: log.id,
    internshipProfileId: log.internshipProfileId,
    studentName: log.studentName,
    studentEmail: log.studentEmail,
    companyName: log.companyName,
    date: log.date,
    hoursRendered: log.hoursRendered,
    taskDescription: log.taskDescription,
    status: status,
    submittedAt: log.submittedAt,
    attachments: log.attachments,
    attachmentsCount: log.attachmentsCount,
    reviewHistory: log.reviewHistory,
  );
}
