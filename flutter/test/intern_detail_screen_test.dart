import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/intern_list_service.dart';
import 'package:intern_track_app/core/services/supervisor_log_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/intern_detail_screen.dart';
import 'package:intern_track_app/shared/models/intern_detail.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';
import 'package:intern_track_app/shared/models/supervisor_log_item.dart';

void main() {
  group('InternDetailScreen recent logs', () {
    testWidgets('opens a recent log review screen and refreshes after update', (
      tester,
    ) async {
      _setLargeTestSurface(tester);
      final service = _FakeInternDetailService([
        _internDetail(
          status: 'PENDING',
          completedHours: 0,
          pendingLogs: 1,
          approvedLogs: 0,
        ),
        _internDetail(
          status: 'APPROVED',
          completedHours: 8,
          pendingLogs: 0,
          approvedLogs: 1,
        ),
      ]);
      final openedLogIds = <int>[];

      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          reviewScreenBuilder: (context, log, service, token, intern) {
            openedLogIds.add(log.id);

            return Scaffold(
              appBar: AppBar(title: const Text('Review Log')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Complete Review'),
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Review Log'), 300);

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Pending: 1'), findsOneWidget);
      expect(find.text('Approved: 0'), findsOneWidget);

      await tester.tap(find.text('Review Log'));
      await tester.pumpAndSettle();

      expect(openedLogIds, [42]);
      expect(find.text('Complete Review'), findsOneWidget);

      await tester.tap(find.text('Complete Review'));
      await tester.pumpAndSettle();

      expect(service.detailRequests, 2);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('Pending: 0'), findsOneWidget);
      expect(find.text('Approved: 1'), findsOneWidget);
      expect(find.text('Approved Hours: 8 / 486 hours'), findsOneWidget);
    });

    testWidgets('shows disabled fallback when a supervisor log id is missing', (
      tester,
    ) async {
      _setLargeTestSurface(tester);
      final service = _FakeInternDetailService([_internDetail(logId: 0)]);
      final openedLogIds = <int>[];

      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          reviewScreenBuilder: (context, log, service, token, intern) {
            openedLogIds.add(log.id);
            return const Scaffold(body: Text('Unexpected review screen'));
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Log unavailable'), 300);

      expect(find.text('Review Log'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await tester.tap(find.text('Log unavailable'));
      await tester.pumpAndSettle();

      expect(openedLogIds, isEmpty);
      expect(find.text('Unexpected review screen'), findsNothing);
    });

    testWidgets('adviser recent logs open read-only log detail screen', (
      tester,
    ) async {
      _setLargeTestSurface(tester);
      final service = _FakeInternDetailService([
        _internDetail(status: 'APPROVED', approvedLogs: 1, pendingLogs: 0),
      ]);
      final logService = _FakeLogService(
        _supervisorLog(
          status: 'APPROVED',
          attachments: [
            LogAttachment(
              id: 5,
              filePath: 'log_attachments/proof.pdf',
              fileType: 'pdf',
              fileSize: 4096,
            ),
          ],
          reviewHistory: [
            LogReviewActionItem(
              id: 9,
              action: 'APPROVED',
              comment: 'Work summary is complete.',
              actedAt: '2026-04-17T10:00:00Z',
              supervisorId: 3,
              supervisorName: 'Sam Supervisor',
              supervisorEmail: 'sam@example.com',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          role: 'adviser',
          logService: logService,
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('View Log'), 300);

      await tester.tap(find.text('View Log'));
      await tester.pumpAndSettle();

      expect(logService.requestedLogIds, [42]);
      expect(find.text('Log Details'), findsOneWidget);
      expect(
        find.text(
          'Read-only adviser view. Approval controls remain with the assigned supervisor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Student: Ana Cruz'), findsOneWidget);
      expect(find.text('Implemented dashboard improvements.'), findsOneWidget);
      expect(find.text('proof.pdf'), findsOneWidget);
      expect(find.text('By: Sam Supervisor'), findsOneWidget);
      expect(find.text('Work summary is complete.'), findsOneWidget);
      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });
}

Widget _buildTestApp({
  required InternListService service,
  String role = 'supervisor',
  SupervisorLogService? logService,
  RecentLogReviewScreenBuilder? reviewScreenBuilder,
}) {
  return MaterialApp(
    home: InternDetailScreen(
      token: 'token',
      role: role,
      profileId: 7,
      service: service,
      logService: logService ?? _fakeLogService(),
      reviewScreenBuilder: reviewScreenBuilder,
    ),
  );
}

void _setLargeTestSurface(WidgetTester tester) {
  final view = tester.view;
  view.physicalSize = const Size(1200, 1400);
  view.devicePixelRatio = 1;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}

SupervisorLogService _fakeLogService() {
  final dio = Dio();
  dio.httpClientAdapter = HttpClientAdapter();
  final apiClient = ApiClient(dio: dio);
  return SupervisorLogService(apiClient);
}

SupervisorLogItem _supervisorLog({
  String status = 'PENDING',
  List<LogAttachment> attachments = const <LogAttachment>[],
  List<LogReviewActionItem> reviewHistory = const <LogReviewActionItem>[],
}) {
  return SupervisorLogItem(
    id: 42,
    internshipProfileId: 7,
    studentName: 'Ana Cruz',
    studentEmail: 'ana@example.com',
    companyName: 'Acme Corp',
    date: '2026-04-17',
    hoursRendered: 8,
    taskDescription: 'Implemented dashboard improvements.',
    status: status,
    submittedAt: '2026-04-17T09:00:00Z',
    attachments: attachments,
    attachmentsCount: attachments.length,
    reviewHistory: reviewHistory,
  );
}

InternDetailItem _internDetail({
  int logId = 42,
  String status = 'PENDING',
  int completedHours = 0,
  int pendingLogs = 1,
  int approvedLogs = 0,
}) {
  return InternDetailItem(
    id: 7,
    studentId: 17,
    studentName: 'Ana Cruz',
    studentEmail: 'ana@example.com',
    companyName: 'Acme Corp',
    companyAddress: '123 Main St',
    requiredHours: 486,
    completedHours: completedHours,
    totalLogs: 1,
    pendingLogs: pendingLogs,
    approvedLogs: approvedLogs,
    rejectedLogs: 0,
    supervisorId: 3,
    supervisorName: 'Sam Supervisor',
    adviserId: 4,
    adviserName: 'Ada Adviser',
    startDate: '2026-03-01',
    endDate: '2026-06-30',
    recentLogs: [
      LogEntryItem(
        id: logId,
        internshipProfileId: 7,
        date: '2026-04-17',
        hoursRendered: 8,
        taskDescription: 'Implemented dashboard improvements.',
        status: status,
        submittedAt: '2026-04-17T09:00:00Z',
        attachments: const [],
        attachmentsCount: 1,
        reviewHistory: const [],
      ),
    ],
  );
}

class _FakeInternDetailService extends InternListService {
  _FakeInternDetailService(this.responses)
      : super(
          ApiClient(
            dio: Dio(),
          ),
        );

  final List<InternDetailItem> responses;
  int detailRequests = 0;

  @override
  Future<InternDetailItem> getInternDetail({
    required String role,
    required int profileId,
  }) async {
    final index = detailRequests < responses.length
        ? detailRequests
        : responses.length - 1;
    detailRequests += 1;
    return responses[index];
  }
}

class _FakeLogService extends SupervisorLogService {
  _FakeLogService(this.log)
      : super(
          ApiClient(
            dio: Dio(),
          ),
          role: 'adviser',
        );

  final SupervisorLogItem log;
  final List<int> requestedLogIds = <int>[];

  @override
  Future<SupervisorLogItem> getLog(int id) async {
    requestedLogIds.add(id);
    return log;
  }

  @override
  Future<SupervisorLogAttachmentFile> downloadAttachment({
    required int logId,
    required int attachmentId,
  }) async {
    return const SupervisorLogAttachmentFile(
      bytes: <int>[],
      filename: 'proof.pdf',
      mimeType: 'application/pdf',
    );
  }
}
