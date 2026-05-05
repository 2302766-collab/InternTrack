import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/student_report_service.dart';
import 'package:intern_track_app/shared/models/student_report.dart';
import 'package:intern_track_app/shared/widgets/progress_widget.dart';

void main() {
  group('ProgressWidget', () {
    testWidgets('renders 0 percent progress correctly', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              report: _report(
                approvedHours: 0,
                requiredHours: 200,
                completionPercentage: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Approved Hours: 0 / 200 hours'), findsOneWidget);
      expect(find.text('Remaining: 200 hours'), findsOneWidget);
    });

    testWidgets('renders 100 percent progress correctly', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              report: _report(
                approvedHours: 200,
                requiredHours: 200,
                completionPercentage: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Approved Hours: 200 / 200 hours'), findsOneWidget);
      expect(find.text('Remaining: 0 hours'), findsOneWidget);
    });

    testWidgets('caps percentage above 100 percent', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              report: _report(
                approvedHours: 240,
                requiredHours: 200,
                completionPercentage: 120,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Approved Hours: 240 / 200 hours'), findsOneWidget);
      expect(find.text('Remaining: 0 hours'), findsOneWidget);
    });

    testWidgets('shows loading state while fetching', (tester) async {
      final completer = Completer<StudentReportData>();

      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(completer: completer),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        _report(
          approvedHours: 80,
          requiredHours: 200,
          completionPercentage: 40,
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows retry state on network error', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              error: ApiException(
                message: 'Request failed.',
                errorType: ApiErrorType.networkError,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to load progress.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows retry state on network timeout', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              error: ApiException(
                message: 'Request timeout. Please check your connection.',
                errorType: ApiErrorType.timeout,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to load progress.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows retry state on server error', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              error: ApiException(
                message: 'Server error. Please try again later.',
                errorType: ApiErrorType.serverError,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to load progress.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button works after network error', (tester) async {
      var callCount = 0;
      
      await tester.pumpWidget(
        _buildApp(
          ProgressWidget.dynamic(
            token: 'token',
            reportService: _FakeStudentReportService(
              error: ApiException(
                message: 'Request failed.',
                errorType: ApiErrorType.networkError,
              ),
              onCall: () => callCount++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Unable to load progress.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(callCount, equals(1));

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Verify service was called again
      expect(callCount, equals(2));
    });
  });
}

Widget _buildApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

StudentReportData _report({
  required int approvedHours,
  required int requiredHours,
  required double completionPercentage,
}) {
  return StudentReportData(
    student: const StudentReportPerson(id: 1, name: 'Student', email: ''),
    supervisor: const StudentReportPerson(id: 2, name: 'Supervisor', email: ''),
    dateRange: const StudentReportDateRange(),
    logs: const [],
    summary: StudentReportSummary(
      approvedHours: approvedHours,
      totalApprovedHours: approvedHours,
      requiredHours: requiredHours,
      completionPercentage: completionPercentage,
    ),
  );
}

class _FakeStudentReportService extends StudentReportService {
  final StudentReportData? report;
  final Object? error;
  final Completer<StudentReportData>? completer;
  final VoidCallback? onCall;

  _FakeStudentReportService({this.report, this.error, this.completer, this.onCall});

  @override
  Future<StudentReportData> getReport(
    {
    String? startDate,
    String? endDate,
  }) async {
    onCall?.call();
    
    if (error != null) {
      throw error!;
    }

    if (completer != null) {
      return completer!.future;
    }

    return report!;
  }
}
