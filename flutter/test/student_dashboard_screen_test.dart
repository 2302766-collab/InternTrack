import 'dart:async';
import 'dart:collection';

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
import 'package:intern_track_app/shared/widgets/dashboard_refresh_widgets.dart';

void main() {
  testWidgets('shows a full-page loading state on first load without cached data', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final profileCompleter = Completer<InternshipProfile?>();

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([
            () => profileCompleter.future,
          ]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([() async => _sampleReport()]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([() async => _sampleLogs()]),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Next Action'), findsNothing);

    profileCompleter.complete(_sampleProfile());
    await tester.pumpAndSettle();
  });

  testWidgets('refresh keeps existing content visible and shows refreshing status', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final profileCompleter = Completer<InternshipProfile?>();
    final reportCompleter = Completer<StudentReportData>();
    final logsCompleter = Completer<List<LogEntryItem>>();
    final clock = _FakeClock(DateTime(2026, 5, 10, 9, 30));

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([
            () async => _sampleProfile(),
            () => profileCompleter.future,
          ]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([
            () async => _sampleReport(),
            () => reportCompleter.future,
          ]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([
            () async => _sampleLogs(),
            () => logsCompleter.future,
          ]),
        ),
        clock: clock.call,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Completed daily development tasks.'), findsOneWidget);
    expect(find.text('Last updated: 9:30 AM'), findsOneWidget);

    await _triggerRefresh(tester);

    expect(find.text('Refreshing student dashboard...'), findsOneWidget);
    expect(find.text('Completed daily development tasks.'), findsOneWidget);
    expect(find.text('Next Action'), findsOneWidget);

    profileCompleter.complete(_sampleProfile());
    reportCompleter.complete(_sampleReport());
    logsCompleter.complete(
      _sampleLogs(taskDescription: 'Refreshed activity log.'),
    );

    await tester.pumpAndSettle();

    expect(find.text('Refreshing student dashboard...'), findsNothing);
    expect(find.text('Refreshed activity log.'), findsOneWidget);
  });

  testWidgets('successful refresh updates the last updated timestamp', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final clock = _FakeClock(DateTime(2026, 5, 10, 9, 35));

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([
            () async => _sampleProfile(),
            () async => _sampleProfile(),
          ]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([
            () async => _sampleReport(),
            () async => _sampleReport(approvedHours: 20),
          ]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([
            () async => _sampleLogs(),
            () async => _sampleLogs(taskDescription: 'Updated after refresh.'),
          ]),
        ),
        clock: clock.call,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Last updated: 9:35 AM'), findsOneWidget);

    clock.current = DateTime(2026, 5, 10, 14, 35);
    await _triggerRefresh(tester);
    await tester.pumpAndSettle();

    expect(find.text('Last updated: 2:35 PM'), findsOneWidget);
    expect(find.text('Updated after refresh.'), findsOneWidget);
  });

  testWidgets('partial refresh failure preserves previous report data and shows inline error', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final clock = _FakeClock(DateTime(2026, 5, 10, 10, 0));

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([
            () async => _sampleProfile(),
            () async => _sampleProfile(),
          ]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([
            () async => _sampleReport(),
            () => Future<StudentReportData>.error(
              ApiException(
                message: 'Report refresh failed.',
                errorType: ApiErrorType.networkError,
              ),
            ),
          ]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([
            () async => _sampleLogs(),
            () async =>
                _sampleLogs(taskDescription: 'Logs refreshed successfully.'),
          ]),
        ),
        clock: clock.call,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Approved Hours: 15 / 486 hours'), findsOneWidget);

    clock.current = DateTime(2026, 5, 10, 11, 0);
    await _triggerRefresh(tester);
    await tester.pumpAndSettle();

    expect(find.text('Approved Hours: 15 / 486 hours'), findsOneWidget);
    expect(find.text('Report refresh failed.'), findsOneWidget);
    expect(find.text('Logs refreshed successfully.'), findsOneWidget);
    expect(find.text('Last updated: 11:00 AM'), findsOneWidget);
  });

  testWidgets('section without cached data shows skeleton while retry refresh is in progress', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final logsCompleter = Completer<List<LogEntryItem>>();
    final clock = _FakeClock(DateTime(2026, 5, 10, 8, 45));

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([
            () async => _sampleProfile(),
            () async => _sampleProfile(),
          ]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([
            () async => _sampleReport(),
            () async => _sampleReport(),
          ]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([
            () => Future<List<LogEntryItem>>.error(
              ApiException(
                message: 'Logs refresh failed.',
                errorType: ApiErrorType.networkError,
              ),
            ),
            () => logsCompleter.future,
          ]),
        ),
        clock: clock.call,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Logs refresh failed.'), findsOneWidget);
    expect(find.text('Next Action'), findsOneWidget);

    await _triggerRefresh(tester);

    expect(find.byType(DashboardSkeletonBlock), findsWidgets);
    expect(find.text('Next Action'), findsOneWidget);

    logsCompleter.complete(
      _sampleLogs(taskDescription: 'Logs loaded after retry.'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logs refresh failed.'), findsNothing);
    expect(find.text('Logs loaded after retry.'), findsOneWidget);
  });

  testWidgets('student dashboard still highlights missing today log and recent activity', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider();
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    await tester.pumpWidget(
      _buildApp(
        authProvider: authProvider,
        internshipService: _QueuedInternshipService(
          responses: Queue.of([() async => _sampleProfile()]),
        ),
        reportService: _QueuedStudentReportService(
          responses: Queue.of([() async => _sampleReport()]),
        ),
        logbookService: _QueuedLogbookService(
          responses: Queue.of([
            () async => <LogEntryItem>[
                  _buildLog(
                    id: 11,
                    date: _formatApiDate(yesterday),
                    hoursRendered: 8,
                    status: 'PENDING',
                    taskDescription: 'Completed daily development tasks.',
                  ),
                  _buildLog(
                    id: 10,
                    date: '2026-04-18',
                    hoursRendered: 7,
                    status: 'APPROVED',
                    taskDescription: 'Fixed UI issues and tested forms.',
                  ),
                ],
          ]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Next Action'), findsOneWidget);
    expect(find.text('Add today\'s log entry'), findsOneWidget);
    expect(find.text('Add Today\'s Log'), findsNWidgets(2));
    expect(find.text('Pending Hours'), findsOneWidget);
    expect(find.text('Completed daily development tasks.'), findsOneWidget);
    expect(find.text('Fixed UI issues and tested forms.'), findsOneWidget);
    expect(find.text('Edit in Logbook'), findsOneWidget);
    expect(find.text('Update Profile'), findsOneWidget);

    final newerLogY = tester
        .getTopLeft(find.text('Completed daily development tasks.'))
        .dy;
    final olderLogY = tester
        .getTopLeft(find.text('Fixed UI issues and tested forms.'))
        .dy;
    expect(newerLogY, lessThan(olderLogY));
  });

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
        reportService: _FakeStudentReportService(report: _sampleReport()),
        logbookService: _FakeLogbookService(logs: const <LogEntryItem>[]),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_sampleProfile());
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
        reportService: _FakeStudentReportService(report: _sampleReport()),
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

    retryCompleter.complete(_sampleProfile());
    await tester.pumpAndSettle();

    expect(find.text('Next Action'), findsOneWidget);
    expect(callCount, equals(2));
  });
}

Future<void> _triggerRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 320));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
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
  DateTime Function()? clock,
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
        clock: clock,
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

InternshipProfile _sampleProfile() {
  return InternshipProfile(
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
  );
}

StudentReportData _sampleReport({int approvedHours = 15}) {
  return StudentReportData(
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
    summary: StudentReportSummary(
      approvedHours: approvedHours,
      totalApprovedHours: approvedHours,
      requiredHours: 486,
      completionPercentage: approvedHours / 486 * 100,
    ),
  );
}

List<LogEntryItem> _sampleLogs({
  String taskDescription = 'Completed daily development tasks.',
}) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  return <LogEntryItem>[
    _buildLog(
      id: 11,
      date: _formatApiDate(yesterday),
      hoursRendered: 8,
      status: 'PENDING',
      taskDescription: taskDescription,
    ),
  ];
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

class _FakeClock {
  _FakeClock(this.current);

  DateTime current;

  DateTime call() => current;
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

class _QueuedInternshipService extends InternshipService {
  _QueuedInternshipService({
    required Queue<Future<InternshipProfile?> Function()> responses,
  }) : _responses = responses;

  final Queue<Future<InternshipProfile?> Function()> _responses;

  @override
  Future<InternshipProfile?> getInternshipProfile() {
    return _responses.removeFirst()();
  }
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

class _QueuedStudentReportService extends StudentReportService {
  _QueuedStudentReportService({
    required Queue<Future<StudentReportData> Function()> responses,
  }) : _responses = responses;

  final Queue<Future<StudentReportData> Function()> _responses;

  @override
  Future<StudentReportData> getReport({String? startDate, String? endDate}) {
    return _responses.removeFirst()();
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

class _QueuedLogbookService extends LogbookService {
  _QueuedLogbookService({
    required Queue<Future<List<LogEntryItem>> Function()> responses,
  }) : _responses = responses;

  final Queue<Future<List<LogEntryItem>> Function()> _responses;

  @override
  Future<List<LogEntryItem>> getLogs() {
    return _responses.removeFirst()();
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
