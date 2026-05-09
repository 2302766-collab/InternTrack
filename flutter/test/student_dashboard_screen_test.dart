import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/internship_service.dart';
import 'package:intern_track_app/core/services/logbook_service.dart';
import 'package:intern_track_app/core/services/notification_service.dart';
import 'package:intern_track_app/core/services/student_report_service.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/features/student/presentation/screens/student_dashboard_screen.dart';
import 'package:intern_track_app/shared/models/app_notification.dart';
import 'package:intern_track_app/shared/models/app_user.dart';
import 'package:intern_track_app/shared/models/internship_profile.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/notification_page.dart';
import 'package:intern_track_app/shared/models/student_report.dart';

void main() {
  testWidgets(
    'student dashboard highlights missing today log and recent activity',
    (tester) async {
      final authProvider = await _buildAuthProvider();
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      await tester.pumpWidget(
        _buildApp(
          authProvider: authProvider,
          internshipService: _FakeInternshipService(
            profile: InternshipProfile(
              id: 1,
              studentId: 2,
              companyName: 'Acme Innovations',
              companyAddress: '123 Main Street',
              requiredHours: 486,
              startDate: '2026-04-09',
              endDate: '2026-07-19',
              supervisorId: 3,
              adviserId: 4,
              supervisorName: 'Sample Supervisor',
            ),
          ),
          reportService: _FakeStudentReportService(
            report: StudentReportData(
              student: const StudentReportPerson(
                id: 2,
                name: 'Sample Student',
                email: 'student@example.com',
              ),
              supervisor: const StudentReportPerson(
                id: 3,
                name: 'Sample Supervisor',
                email: 'supervisor@example.com',
              ),
              dateRange: const StudentReportDateRange(),
              logs: const <LogEntryItem>[],
              summary: const StudentReportSummary(
                approvedHours: 15,
                totalApprovedHours: 15,
                requiredHours: 486,
                completionPercentage: 3,
              ),
            ),
          ),
          logbookService: _FakeLogbookService(
            logs: <LogEntryItem>[
              _buildLog(
                id: 10,
                date: '2026-04-18',
                hoursRendered: 7,
                status: 'APPROVED',
                taskDescription: 'Fixed UI issues and tested forms.',
              ),
              _buildLog(
                id: 11,
                date: _formatApiDate(yesterday),
                hoursRendered: 8,
                status: 'PENDING',
                taskDescription: 'Completed daily development tasks.',
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Next Action'), findsOneWidget);
      expect(find.text('Add today\'s log entry'), findsOneWidget);
      expect(find.text('Add Today\'s Log'), findsNWidgets(2));
      expect(find.text('Internship Status'), findsOneWidget);
      expect(find.text('Pending Hours'), findsOneWidget);
      expect(find.text('8 h'), findsWidgets);
      expect(find.text('Pace After Pending'), findsOneWidget);
      expect(find.text('Recent Logs'), findsOneWidget);
      expect(find.text('Completed daily development tasks.'), findsOneWidget);
      expect(find.text('Fixed UI issues and tested forms.'), findsOneWidget);
      expect(find.text('Edit in Logbook'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.text('Update Profile'), findsNothing);

      final newerLogY = tester
          .getTopLeft(find.text('Completed daily development tasks.'))
          .dy;
      final olderLogY = tester
          .getTopLeft(find.text('Fixed UI issues and tested forms.'))
          .dy;
      expect(newerLogY, lessThan(olderLogY));
    },
  );

  testWidgets(
    'student dashboard pushes profile completion when profile is missing',
    (tester) async {
      final authProvider = await _buildAuthProvider();

      await tester.pumpWidget(
        _buildApp(
          authProvider: authProvider,
          internshipService: _FakeInternshipService(profile: null),
          reportService: _FakeStudentReportService(report: null),
          logbookService: _FakeLogbookService(logs: const <LogEntryItem>[]),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Complete your internship profile'), findsOneWidget);
      expect(find.text('Complete Internship Profile'), findsOneWidget);
      expect(
        find.textContaining('No internship profile is active yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets('student dashboard shows loading state during API calls', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final completer = Completer<InternshipProfile?>();

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _FakeInternshipService(completer: completer),
        reportService: _FakeStudentReportService(
          report: StudentReportData(
            student: const StudentReportPerson(
              id: 2,
              name: 'Sample Student',
              email: 'student@example.com',
            ),
            supervisor: const StudentReportPerson(
              id: 3,
              name: 'Sample Supervisor',
              email: 'supervisor@example.com',
            ),
            dateRange: const StudentReportDateRange(),
            logs: const <LogEntryItem>[],
            summary: const StudentReportSummary(
              approvedHours: 15,
              totalApprovedHours: 15,
              requiredHours: 486,
              completionPercentage: 3,
            ),
          ),
        ),
        logbookService: _FakeLogbookService(logs: const <LogEntryItem>[]),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(
      InternshipProfile(
        id: 1,
        studentId: 2,
        companyName: 'Acme Innovations',
        companyAddress: '123 Main Street',
        requiredHours: 486,
        startDate: '2026-04-09',
        endDate: '2026-07-19',
        supervisorId: 3,
        adviserId: 4,
        supervisorName: 'Sample Supervisor',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Next Action'), findsOneWidget);
  });

  testWidgets('student dashboard shows specific timeout error with retry', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _FakeInternshipService(
          error: ApiException(
            message: 'Network timeout. Please try again.',
            errorType: ApiErrorType.timeout,
          ),
        ),
        reportService: _FakeStudentReportService(report: null),
        logbookService: _FakeLogbookService(logs: const <LogEntryItem>[]),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unable to load student dashboard'), findsOneWidget);
    expect(find.text('Network timeout. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('student dashboard retry button reloads data after failure', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    var callCount = 0;
    final retryCompleter = Completer<InternshipProfile?>();

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _FakeInternshipService(
          onCall: () => callCount++,
          handler: () async {
            if (callCount == 1) {
              throw ApiException(
                message: 'Server unavailable. Please try again later.',
                errorType: ApiErrorType.serverError,
              );
            }

            return retryCompleter.future;
          },
        ),
        reportService: _FakeStudentReportService(
          report: StudentReportData(
            student: const StudentReportPerson(
              id: 2,
              name: 'Sample Student',
              email: 'student@example.com',
            ),
            supervisor: const StudentReportPerson(
              id: 3,
              name: 'Sample Supervisor',
              email: 'supervisor@example.com',
            ),
            dateRange: const StudentReportDateRange(),
            logs: const <LogEntryItem>[],
            summary: const StudentReportSummary(
              approvedHours: 15,
              totalApprovedHours: 15,
              requiredHours: 486,
              completionPercentage: 3,
            ),
          ),
        ),
        logbookService: _FakeLogbookService(logs: const <LogEntryItem>[]),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Server unavailable. Please try again later.'),
      findsOneWidget,
    );
    expect(callCount, equals(1));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    retryCompleter.complete(
      InternshipProfile(
        id: 1,
        studentId: 2,
        companyName: 'Acme Innovations',
        companyAddress: '123 Main Street',
        requiredHours: 486,
        startDate: '2026-04-09',
        endDate: '2026-07-19',
        supervisorId: 3,
        adviserId: 4,
        supervisorName: 'Sample Supervisor',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Next Action'), findsOneWidget);
    expect(callCount, equals(2));
  });
}

Future<AuthProvider> _buildAuthProvider() async {
  final provider = AuthProvider(
    _FakeTokenService(),
    authService: _FakeAuthService(),
  );

  await provider.setToken(
    'token',
    user: const AppUser(
      id: 2,
      name: 'Sample Student',
      email: 'student@example.com',
      role: 'student',
    ),
  );

  return provider;
}

Widget _buildApp({
  required AuthProvider authProvider,
  required InternshipService internshipService,
  required StudentReportService reportService,
  required LogbookService logbookService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      Provider<NotificationService>.value(value: _FakeNotificationService()),
    ],
    child: MaterialApp(
      home: StudentDashboardScreen(
        userName: 'Sample Student',
        internshipService: internshipService,
        reportService: reportService,
        logbookService: logbookService,
      ),
    ),
  );
}

String _formatApiDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

LogEntryItem _buildLog({
  required int id,
  required String date,
  required int hoursRendered,
  required String status,
  required String taskDescription,
}) {
  return LogEntryItem(
    id: id,
    internshipProfileId: 1,
    date: date,
    hoursRendered: hoursRendered,
    taskDescription: taskDescription,
    status: status,
    attachments: const [],
    attachmentsCount: 0,
    reviewHistory: const [],
  );
}

class _FakeTokenService extends TokenService {
  _FakeTokenService() : super();

  String? _storedToken;

  @override
  Future<void> saveToken(String token) async {
    _storedToken = token;
  }

  @override
  Future<String?> getToken() async => _storedToken;

  @override
  Future<void> clearToken() async {
    _storedToken = null;
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ApiClient(dio: Dio()));
}

class _FakeInternshipService extends InternshipService {
  _FakeInternshipService({
    this.profile,
    this.error,
    this.completer,
    this.onCall,
    this.handler,
  });

  final InternshipProfile? profile;
  final Object? error;
  final Completer<InternshipProfile?>? completer;
  final VoidCallback? onCall;
  final Future<InternshipProfile?> Function()? handler;

  @override
  Future<InternshipProfile?> getInternshipProfile() async {
    onCall?.call();

    if (handler != null) {
      return handler!();
    }

    if (error != null) {
      throw error!;
    }

    if (completer != null) {
      return completer!.future;
    }

    return profile;
  }
}

class _FakeStudentReportService extends StudentReportService {
  _FakeStudentReportService({required this.report});

  final StudentReportData? report;

  @override
  Future<StudentReportData> getReport({
    String? startDate,
    String? endDate,
  }) async {
    return report!;
  }
}

class _FakeLogbookService extends LogbookService {
  _FakeLogbookService({required this.logs});

  final List<LogEntryItem> logs;

  @override
  Future<List<LogEntryItem>> getLogs() async => logs;
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<NotificationPage> fetchNotifications() async {
    return const NotificationPage(
      notifications: <AppNotification>[],
      unreadCount: 0,
      hasMorePages: false,
    );
  }
}
