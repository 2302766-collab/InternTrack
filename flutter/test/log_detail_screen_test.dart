import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/logbook_service.dart';
import 'package:intern_track_app/features/logbook/presentation/screens/log_detail_screen.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';

void main() {
  group('LogDetailScreen attachments', () {
    testWidgets('marks missing image attachments as unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogDetailScreen(
            logId: 28876,
            service: _FakeLogbookService(
              log: _buildLog(
                attachments: [
                  LogAttachment(
                    id: 10,
                    filePath: 'log_attachments/125/proof.jpg',
                    fileType: 'jpg',
                    fileSize: 1024,
                  ),
                ],
              ),
              downloadError: ApiException(
                message: 'Resource not found.',
                statusCode: 404,
                errorType: ApiErrorType.notFound,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text('This attachment is no longer available on the server.'),
        findsOneWidget,
      );
      expect(find.text('Preview ready'), findsNothing);

      final previewButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Preview'),
      );
      final downloadButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Download'),
      );

      expect(previewButton.onPressed, isNull);
      expect(downloadButton.onPressed, isNull);
    });

    testWidgets('shows retry state for transient attachment failures', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogDetailScreen(
            logId: 28876,
            service: _FakeLogbookService(
              log: _buildLog(
                attachments: [
                  LogAttachment(
                    id: 11,
                    filePath: 'log_attachments/125/proof.jpg',
                    fileType: 'jpg',
                    fileSize: 1024,
                  ),
                ],
              ),
              downloadError: ApiException(
                message: 'Connection timed out.',
                statusCode: 408,
                errorType: ApiErrorType.timeout,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text(
          'Could not load this attachment right now. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

      final previewButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Preview'),
      );

      expect(previewButton.onPressed, isNotNull);
    });
  });
}

LogEntryItem _buildLog({required List<LogAttachment> attachments}) {
  return LogEntryItem(
    id: 28876,
    internshipProfileId: 1,
    date: '2026-05-11',
    hoursRendered: 8,
    taskDescription: 'Completed daily tasks.',
    status: 'REJECTED',
    attachments: attachments,
    attachmentsCount: attachments.length,
    reviewHistory: const <LogReviewActionItem>[],
    submittedAt: '2026-05-11T15:22:00Z',
  );
}

class _FakeLogbookService extends LogbookService {
  _FakeLogbookService({required this.log, this.downloadError});

  final LogEntryItem log;
  final ApiException? downloadError;

  @override
  Future<LogEntryItem> getLog(int id) async {
    return log;
  }

  @override
  Future<LogbookAttachmentFile> downloadAttachment({
    required int logId,
    required int attachmentId,
  }) async {
    if (downloadError != null) {
      throw downloadError!;
    }

    return const LogbookAttachmentFile(
      bytes: <int>[1, 2, 3],
      filename: 'proof.jpg',
      mimeType: 'image/jpeg',
    );
  }
}
