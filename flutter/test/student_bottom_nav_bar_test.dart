import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intern_track_app/core/constants/app_routes.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/dtr_service.dart';
import 'package:intern_track_app/core/services/internship_service.dart';
import 'package:intern_track_app/core/services/logbook_service.dart';
import 'package:intern_track_app/core/services/notification_service.dart';
import 'package:intern_track_app/core/services/student_report_service.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/features/internship/presentation/screens/internship_profile_screen.dart';
import 'package:intern_track_app/features/logbook/presentation/screens/logbook_screen.dart';
import 'package:intern_track_app/features/student/presentation/screens/student_dashboard_screen.dart';
import 'package:intern_track_app/features/student/presentation/screens/student_dtr_screen.dart';
import 'package:intern_track_app/features/student/presentation/screens/student_report_screen.dart';
import 'package:intern_track_app/features/student/presentation/widgets/student_bottom_nav_bar.dart';
import 'package:intern_track_app/shared/models/app_notification.dart';
import 'package:intern_track_app/shared/models/app_user.dart';
import 'package:intern_track_app/shared/models/daily_time_record.dart';
import 'package:intern_track_app/shared/models/internship_profile.dart';
import 'package:intern_track_app/shared/models/log_attachment.dart';
import 'package:intern_track_app/shared/models/log_entry.dart';
import 'package:intern_track_app/shared/models/log_review_action.dart';
import 'package:intern_track_app/shared/models/notification_page.dart';
import 'package:intern_track_app/shared/models/student_report.dart';

void main() {
  group('StudentBottomNavBar', () {
    testWidgets(
      'renders on every core student screen and highlights the active route',
      (tester) async {
        final expectedIndices = <String, int>{
          AppRoutes.studentDashboard: 0,
          AppRoutes.logbook: 1,
          AppRoutes.studentDtr: 2,
          AppRoutes.studentReport: 3,
          AppRoutes.internshipProfile: 4,
        };

        for (final entry in expectedIndices.entries) {
          final authProvider = await _buildAuthProvider();

          await tester.pumpWidget(
            _buildApp(
              authProvider: authProvider,
              initialRoute: entry.key,
              routeBuildCounts: <String, int>{},
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(StudentBottomNavBar), findsOneWidget);

          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          expect(
            navBar.currentIndex,
            entry.value,
            reason: 'Expected ${entry.key} to highlight tab ${entry.value}',
          );
        }
      },
    );

    testWidgets('switches between the existing student routes', (tester) async {
      final authProvider = await _buildAuthProvider();
      final routeBuildCounts = <String, int>{};

      await tester.pumpWidget(
        _buildApp(
          authProvider: authProvider,
          initialRoute: AppRoutes.studentDashboard,
          routeBuildCounts: routeBuildCounts,
        ),
      );
      await tester.pumpAndSettle();

      expect(routeBuildCounts[AppRoutes.studentDashboard], 1);

      await _tapNavDestination(tester, AppRoutes.logbook);
      expect(routeBuildCounts[AppRoutes.logbook], 1);
      expect(_currentNavIndex(tester), 1);

      await _tapNavDestination(tester, AppRoutes.studentDtr);
      expect(routeBuildCounts[AppRoutes.studentDtr], 1);
      expect(_currentNavIndex(tester), 2);

      await _tapNavDestination(tester, AppRoutes.studentReport);
      expect(routeBuildCounts[AppRoutes.studentReport], 1);
      expect(_currentNavIndex(tester), 3);

      await _tapNavDestination(tester, AppRoutes.internshipProfile);
      expect(routeBuildCounts[AppRoutes.internshipProfile], 1);
      expect(_currentNavIndex(tester), 4);

      await _tapNavDestination(tester, AppRoutes.studentDashboard);
      expect(routeBuildCounts[AppRoutes.studentDashboard], 2);
      expect(_currentNavIndex(tester), 0);
    });

    testWidgets('tapping the current tab does not duplicate the route', (
      tester,
    ) async {
      final authProvider = await _buildAuthProvider();
      final routeBuildCounts = <String, int>{};

      await tester.pumpWidget(
        _buildApp(
          authProvider: authProvider,
          initialRoute: AppRoutes.logbook,
          routeBuildCounts: routeBuildCounts,
        ),
      );
      await tester.pumpAndSettle();

      expect(routeBuildCounts[AppRoutes.logbook], 1);
      expect(_currentNavIndex(tester), 1);

      await _tapNavDestination(tester, AppRoutes.logbook);

      expect(routeBuildCounts[AppRoutes.logbook], 1);
      expect(_currentNavIndex(tester), 1);
    });
  });
}

Future<void> _tapNavDestination(WidgetTester tester, String route) async {
  await tester.tap(find.byKey(ValueKey<String>('student-nav-$route')));
  await tester.pumpAndSettle();
}

int _currentNavIndex(WidgetTester tester) {
  final navBar = tester.widget<BottomNavigationBar>(
    find.byType(BottomNavigationBar),
  );
  return navBar.currentIndex;
}

Future<AuthProvider> _buildAuthProvider() async {
  final provider = AuthProvider(
    _FakeTokenService(),
    authService: _FakeAuthService(),
  );

  await provider.setToken(
    'token',
    user: const AppUser(
      id: 17,
      name: 'Student Tester',
      email: 'student@example.com',
      role: 'student',
    ),
  );

  return provider;
}

Widget _buildApp({
  required AuthProvider authProvider,
  required String initialRoute,
  required Map<String, int> routeBuildCounts,
}) {
  final internshipService = _StaticInternshipService();
  final logbookService = _StaticLogbookService();
  final reportService = _StaticStudentReportService();
  final dtrService = _StaticDtrService();
  final notificationService = _StaticNotificationService();

  Route<dynamic> buildRoute(RouteSettings settings) {
    final routeName = settings.name ?? initialRoute;
    routeBuildCounts.update(routeName, (count) => count + 1, ifAbsent: () => 1);

    final screen = switch (routeName) {
      AppRoutes.studentDashboard => StudentDashboardScreen(
        userName: 'Student Tester',
        internshipService: internshipService,
        logbookService: logbookService,
        reportService: reportService,
      ),
      AppRoutes.logbook => const LogbookScreen(),
      AppRoutes.studentDtr => StudentDtrScreen(dtrService: dtrService),
      AppRoutes.studentReport => const StudentReportScreen(token: 'token'),
      AppRoutes.internshipProfile => const InternshipProfileScreen(
        token: 'token',
      ),
      _ => throw StateError(
        'Unexpected route requested during test: $routeName',
      ),
    };

    return MaterialPageRoute<void>(
      builder: (_) => screen,
      settings: RouteSettings(name: routeName),
    );
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      Provider<InternshipService>.value(value: internshipService),
      Provider<LogbookService>.value(value: logbookService),
      Provider<StudentReportService>.value(value: reportService),
      Provider<NotificationService>.value(value: notificationService),
    ],
    child: MaterialApp(
      key: ValueKey<String>('student-app-$initialRoute'),
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (routeName) => <Route<dynamic>>[
        buildRoute(RouteSettings(name: routeName)),
      ],
      onGenerateRoute: buildRoute,
    ),
  );
}

InternshipProfile _sampleProfile() {
  return InternshipProfile(
    id: 1,
    studentId: 17,
    companyName: 'InternTrack Labs',
    companyAddress: 'Quezon City',
    requiredHours: 486,
    startDate: '2026-04-01',
    endDate: '2026-07-31',
    supervisorId: 9,
    adviserId: 11,
    supervisorName: 'Supervisor Smith',
    supervisorEmail: 'supervisor@example.com',
  );
}

List<LogEntryItem> _sampleLogs() {
  return <LogEntryItem>[
    LogEntryItem(
      id: 41,
      internshipProfileId: 1,
      date: '2026-05-13',
      hoursRendered: 8,
      taskDescription: 'Completed student dashboard updates.',
      status: 'PENDING',
      attachments: const <LogAttachment>[],
      attachmentsCount: 0,
      reviewHistory: const <LogReviewActionItem>[],
    ),
  ];
}

StudentReportData _sampleReport() {
  return StudentReportData(
    student: const StudentReportPerson(
      id: 17,
      name: 'Student Tester',
      email: 'student@example.com',
    ),
    supervisor: const StudentReportPerson(
      id: 9,
      name: 'Supervisor Smith',
      email: 'supervisor@example.com',
    ),
    dateRange: const StudentReportDateRange(),
    logs: const <LogEntryItem>[],
    summary: const StudentReportSummary(
      approvedHours: 24,
      totalApprovedHours: 24,
      requiredHours: 486,
      completionPercentage: 4.9,
    ),
  );
}

DailyTimeRecord _sampleDtr() {
  return DailyTimeRecord(
    id: 77,
    date: '2026-05-13',
    status: 'WORKING',
    currentStateLabel: 'Working',
    nextAction: 'LUNCH_OUT',
    timeInAt: DateTime(2026, 5, 13, 8, 0),
    lunchOutAt: null,
    lunchInAt: null,
    timeOutAt: null,
    firstWorkMinutes: 120,
    secondWorkMinutes: 0,
    totalWorkMinutes: 120,
  );
}

class _FakeTokenService extends TokenService {
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

class _StaticInternshipService extends InternshipService {
  @override
  Future<InternshipProfile?> getInternshipProfile() async => _sampleProfile();
}

class _StaticLogbookService extends LogbookService {
  @override
  Future<List<LogEntryItem>> getLogs() async => _sampleLogs();
}

class _StaticStudentReportService extends StudentReportService {
  @override
  Future<StudentReportData> getReport({
    String? startDate,
    String? endDate,
  }) async {
    return _sampleReport();
  }
}

class _StaticDtrService extends DtrService {
  _StaticDtrService() : super(ApiClient(dio: Dio()));

  @override
  Future<DailyTimeRecord> getTodayRecord() async => _sampleDtr();
}

class _StaticNotificationService extends NotificationService {
  @override
  Future<NotificationPage> fetchNotifications() async {
    return const NotificationPage(
      notifications: <AppNotification>[],
      unreadCount: 0,
      hasMorePages: false,
    );
  }
}
