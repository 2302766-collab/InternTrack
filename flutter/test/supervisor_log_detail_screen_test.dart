import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/supervisor_log_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/supervisor_log_detail_screen.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';
import 'package:intern_track_app/shared/models/supervisor_log_item.dart';

void main() {
  group('SupervisorLogDetailScreen', () {
    testWidgets('renders review details and attachments', (tester) async {
      await _openReviewScreen(
        tester,
        service: _FakeSupervisorLogService(
          log: _buildLog(
            attachments: [
              _attachment(id: 1, path: 'proofs/proof1.pdf', type: 'pdf'),
              _attachment(id: 2, path: 'photos/photo1.png', type: 'png'),
            ],
          ),
        ),
      );

      expect(find.text('Review Log'), findsOneWidget);
      expect(find.text('Student: John Doe'), findsOneWidget);
      expect(find.text('Date: Jan 12'), findsOneWidget);
      expect(find.text('Hours: 8 hrs'), findsOneWidget);
      expect(find.text('Task Description:'), findsOneWidget);
      expect(find.text('Worked on backend endpoints.'), findsOneWidget);
      expect(find.text('Attachments:'), findsOneWidget);
      expect(find.text('proof1.pdf'), findsOneWidget);
      expect(find.text('photo1.png'), findsOneWidget);
      expect(
        find.text('Rejection Comment (required if reject)'),
        findsOneWidget,
      );
      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
    });

    testWidgets('reject without comment shows inline error', (tester) async {
      final service = _FakeSupervisorLogService(log: _buildLog());

      await _openReviewScreen(tester, service: service);

      await tester.ensureVisible(find.text('REJECT'));
      await tester.tap(find.text('REJECT'));
      await tester.pump();

      expect(find.text('Comment is required for rejection.'), findsOneWidget);
      expect(service.rejectCalls, 0);
    });

    testWidgets('reject with comment succeeds and returns', (tester) async {
      final service = _FakeSupervisorLogService(log: _buildLog());

      await _openReviewScreen(tester, service: service);

      await tester.enterText(
        find.byType(TextField),
        'Please add more implementation notes.',
      );
      await tester.ensureVisible(find.text('REJECT'));
      await tester.tap(find.text('REJECT'));
      await tester.pumpAndSettle();

      expect(service.rejectCalls, 1);
      expect(
        service.lastRejectComment,
        'Please add more implementation notes.',
      );
      expect(find.text('Open Review'), findsOneWidget);
    });

    testWidgets('network failure shows retry', (tester) async {
      final service = _FakeSupervisorLogService(
        log: _buildLog(),
        loadError: ApiException(
          message: 'Failed to fetch log details.',
          errorType: ApiErrorType.networkError,
        ),
      );

      await _openReviewScreen(tester, service: service);

      expect(find.text('Failed to fetch log details.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      service.loadError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Student: John Doe'), findsOneWidget);
    });

    testWidgets('non-pending logs disable review buttons', (tester) async {
      final service = _FakeSupervisorLogService(
        log: _buildLog(status: 'APPROVED'),
      );

      await _openReviewScreen(tester, service: service);

      await tester.ensureVisible(find.text('APPROVE'));

      await tester.tap(find.text('APPROVE'), warnIfMissed: false);
      await tester.tap(find.text('REJECT'), warnIfMissed: false);
      await tester.pump();

      expect(service.approveCalls, 0);
      expect(service.rejectCalls, 0);
      expect(find.text('This log has already been reviewed.'), findsOneWidget);
    });

    testWidgets('read-only mode hides supervisor review controls', (
      tester,
    ) async {
      await _openReviewScreen(
        tester,
        service: _FakeSupervisorLogService(log: _buildLog()),
        readOnly: true,
      );

      expect(find.text('Log Details'), findsOneWidget);
      expect(
        find.text(
          'Read-only view. Approval controls remain with the assigned supervisor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Student: John Doe'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
    });

    testWidgets('approve disables buttons and prevents double submit', (
      tester,
    ) async {
      final completer = Completer<SupervisorLogItem>();
      final service = _FakeSupervisorLogService(
        log: _buildLog(),
        approveCompleter: completer,
      );

      await _openReviewScreen(tester, service: service);

      await tester.ensureVisible(find.text('APPROVE'));
      await tester.tap(find.text('APPROVE'));
      await tester.pump();

      expect(service.approveCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.tap(find.text('APPROVE'), warnIfMissed: false);
      await tester.pump();

      expect(service.approveCalls, 1);

      completer.complete(_replaceStatus(_buildLog(), 'APPROVED'));
      await tester.pumpAndSettle();

      expect(find.text('Open Review'), findsOneWidget);
    });
  });
}

Future<void> _openReviewScreen(
  WidgetTester tester, {
  required _FakeSupervisorLogService service,
  bool readOnly = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupervisorLogDetailScreen(
                        logId: 1,
                        service: service,
                        readOnly: readOnly,
                      ),
                    ),
                  );
                },
                child: const Text('Open Review'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open Review'));
  await tester.pumpAndSettle();
}

SupervisorLogItem _buildLog({
  String status = 'PENDING',
  List<LogAttachment> attachments = const <LogAttachment>[],
}) {
  return SupervisorLogItem(
    id: 1,
    internshipProfileId: 1,
    studentName: 'John Doe',
    date: '2026-01-12',
    hoursRendered: 8,
    taskDescription: 'Worked on backend endpoints.',
    status: status,
    attachments: attachments,
    attachmentsCount: attachments.length,
    reviewHistory: const <LogReviewActionItem>[],
  );
}

LogAttachment _attachment({
  required int id,
  required String path,
  required String type,
}) {
  return LogAttachment(id: id, filePath: path, fileType: type, fileSize: 1024);
}

class _FakeSupervisorLogService extends SupervisorLogService {
  _FakeSupervisorLogService({
    required this.log,
    this.loadError,
    this.approveCompleter,
  }) : super(ApiClient(dio: Dio()));

  SupervisorLogItem log;
  Exception? loadError;
  Completer<SupervisorLogItem>? approveCompleter;
  int getLogCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  String? lastRejectComment;

  @override
  Future<SupervisorLogItem> getLog(int id) async {
    getLogCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    return log;
  }

  @override
  Future<SupervisorLogItem> approveLog({
    required int id,
    String? comment,
  }) async {
    approveCalls += 1;

    if (approveCompleter != null) {
      return approveCompleter!.future;
    }

    log = _replaceStatus(log, 'APPROVED');
    return log;
  }

  @override
  Future<SupervisorLogItem> rejectLog({
    required int id,
    required String comment,
  }) async {
    rejectCalls += 1;
    lastRejectComment = comment;
    log = _replaceStatus(log, 'REJECTED');
    return log;
  }

  @override
  Future<SupervisorLogAttachmentFile> downloadAttachment({
    required int logId,
    required int attachmentId,
  }) async {
    return SupervisorLogAttachmentFile(
      bytes: _transparentPngBytes,
      filename: 'attachment_$attachmentId.png',
      mimeType: 'image/png',
    );
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

const List<int> _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
