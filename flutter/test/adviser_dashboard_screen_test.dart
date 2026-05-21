import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/notification_service.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/adviser/presentation/screens/adviser_dashboard_screen.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/shared/models/app_notification.dart';
import 'package:intern_track_app/shared/models/app_user.dart';
import 'package:intern_track_app/shared/models/notification_page.dart';

void main() {
  testWidgets('adviser dashboard renders new workflow sections', (
    tester,
  ) async {
    _setLargeSurfaceSize(tester);

    final authProvider = await _buildAuthProvider();
    final apiClient = ApiClient(
      dio: Dio()..httpClientAdapter = _FakeAdapter(_dashboardPayload()),
    );

    await tester.pumpWidget(
      _buildApp(authProvider: authProvider, apiClient: apiClient),
    );

    await _pumpDashboardReady(tester);

    expect(find.text('Monitoring Pulse'), findsOneWidget);
    expect(find.text('Pending Supervisor Approval'), findsOneWidget);
    expect(find.text('Upcoming Deadlines'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('At-Risk Spotlight'), findsOneWidget);
    expect(find.text('Weekly Activity'), findsOneWidget);
    expect(find.text('Company Snapshot'), findsOneWidget);
    expect(find.text('Completion Forecast'), findsOneWidget);
    expect(find.text('Mia Cummerata'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Send Reminder'), findsWidgets);

    await _disposeRenderedTree(tester);
  });

  testWidgets('adviser dashboard search updates visible count', (tester) async {
    _setLargeSurfaceSize(tester);

    final authProvider = await _buildAuthProvider();
    final apiClient = ApiClient(
      dio: Dio()..httpClientAdapter = _FakeAdapter(_dashboardPayload()),
    );

    await tester.pumpWidget(
      _buildApp(authProvider: authProvider, apiClient: apiClient),
    );

    await _pumpDashboardReady(tester);

    expect(find.text('Showing 3 of 3 interns'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Northstar');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Showing 2 of 3 interns'), findsOneWidget);

    await _disposeRenderedTree(tester);
  });

  testWidgets(
    'adviser dashboard uses injected clock when server date metadata is missing',
    (tester) async {
      _setLargeSurfaceSize(tester);

      final authProvider = await _buildAuthProvider();
      final apiClient = ApiClient(
        dio: Dio()
          ..httpClientAdapter = _FakeAdapter(_payloadWithoutServerDate()),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            Provider<ApiClient>.value(value: apiClient),
            Provider<NotificationService>.value(
              value: _FakeNotificationService(),
            ),
          ],
          child: MaterialApp(
            home: AdviserDashboardScreen(
              userName: 'Sample Adviser',
              clock: () => DateTime(2026, 5, 11, 9),
            ),
          ),
        ),
      );

      await _pumpDashboardReady(tester);

      expect(find.text('No log for 5 days'), findsWidgets);

      await _disposeRenderedTree(tester);
    },
  );
}

Future<void> _pumpDashboardReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _disposeRenderedTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<AuthProvider> _buildAuthProvider() async {
  final provider = AuthProvider(
    _FakeTokenService(),
    authService: _FakeAuthService(),
  );

  await provider.setToken(
    'token',
    user: const AppUser(
      id: 7,
      name: 'Sample Adviser',
      email: 'adviser@example.com',
      role: 'adviser',
    ),
  );

  return provider;
}

Widget _buildApp({
  required AuthProvider authProvider,
  required ApiClient apiClient,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      Provider<ApiClient>.value(value: apiClient),
      Provider<NotificationService>.value(value: _FakeNotificationService()),
    ],
    child: const MaterialApp(
      home: AdviserDashboardScreen(userName: 'Sample Adviser'),
    ),
  );
}

Map<String, dynamic> _dashboardPayload() {
  return {
    'data': [
      _intern(
        id: 1,
        studentId: 1,
        studentName: 'Sample Student',
        companyName: 'Acme Innovations',
        requiredHours: 486,
        completedHours: 20,
        pendingLogs: 2,
        approvedLogs: 3,
        totalLogs: 5,
        lastLogDate: '2026-05-10',
        endDate: '2026-07-30',
        alertStatus: 'BEHIND',
        alertMessage:
            'Behind expected pace. Completed 20 of 73 hours expected by today.',
        alertMeta: {'server_date': '2026-05-11', 'expected_hours_by_now': 73},
      ),
      _intern(
        id: 2,
        studentId: 2,
        studentName: 'Kayleigh Crooks',
        companyName: 'Northstar Labs',
        requiredHours: 240,
        completedHours: 154,
        pendingLogs: 1,
        approvedLogs: 10,
        totalLogs: 11,
        lastLogDate: '2026-05-08',
        endDate: '2026-06-12',
        alertStatus: 'ON_TRACK',
        alertMessage: 'Progress is aligned with the internship timeline.',
        alertMeta: {'server_date': '2026-05-11', 'expected_hours_by_now': 150},
      ),
      _intern(
        id: 3,
        studentId: 3,
        studentName: 'Mia Cummerata',
        companyName: 'Northstar Labs',
        requiredHours: 420,
        completedHours: 420,
        pendingLogs: 0,
        approvedLogs: 16,
        totalLogs: 16,
        lastLogDate: '2026-04-22',
        endDate: '2026-05-25',
        alertStatus: 'INACTIVE',
        alertMessage: 'No log submitted for 19 working days.',
        alertMeta: {'server_date': '2026-05-11', 'expected_hours_by_now': 420},
      ),
    ],
    'meta': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': 3,
      'has_more_pages': false,
    },
  };
}

Map<String, dynamic> _payloadWithoutServerDate() {
  return {
    'data': [
      _intern(
        id: 10,
        studentId: 10,
        studentName: 'Clock Bound',
        companyName: 'Timebox Labs',
        requiredHours: 486,
        completedHours: 60,
        pendingLogs: 0,
        approvedLogs: 4,
        totalLogs: 4,
        lastLogDate: '2026-05-06',
        endDate: '2026-06-30',
        alertStatus: 'INACTIVE',
        alertMessage: 'No log submitted recently.',
        alertMeta: {'expected_hours_by_now': 72},
      ),
    ],
    'meta': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': 1,
      'has_more_pages': false,
    },
  };
}

Map<String, dynamic> _intern({
  required int id,
  required int studentId,
  required String studentName,
  required String companyName,
  required int requiredHours,
  required int completedHours,
  required int pendingLogs,
  required int approvedLogs,
  required int totalLogs,
  required String lastLogDate,
  required String endDate,
  required String alertStatus,
  required String alertMessage,
  required Map<String, dynamic> alertMeta,
}) {
  return {
    'id': id,
    'student_id': studentId,
    'student_name': studentName,
    'company_name': companyName,
    'required_hours': requiredHours,
    'completed_hours': completedHours,
    'pending_logs': pendingLogs,
    'approved_logs': approvedLogs,
    'total_logs': totalLogs,
    'last_log_date': lastLogDate,
    'end_date': endDate,
    'alert_status': alertStatus,
    'alert_message': alertMessage,
    'alert_severity': alertStatus == 'ON_TRACK' ? 'success' : 'warning',
    'alert': {
      'status': alertStatus,
      'message': alertMessage,
      'severity': alertStatus == 'ON_TRACK' ? 'success' : 'warning',
      'meta': alertMeta,
    },
  };
}

void _setLargeSurfaceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._payload);

  final Map<String, dynamic> _payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/adviser/interns') {
      return ResponseBody.fromString(
        jsonEncode(_payload),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'success': false, 'message': 'Not found', 'data': null}),
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
