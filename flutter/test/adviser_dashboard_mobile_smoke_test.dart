import 'package:dio/dio.dart';
import 'dart:convert';

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
  testWidgets('adviser dashboard builds on a phone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(354, 754);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider(
      _FakeTokenService(),
      authService: _FakeAuthService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          Provider<ApiClient>.value(value: ApiClient(dio: Dio())),
          Provider<NotificationService>.value(value: _FakeNotificationService()),
        ],
        child: const MaterialApp(
          home: AdviserDashboardScreen(userName: 'Sample Adviser'),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Academic Adviser Dashboard'), findsOneWidget);
  });

  testWidgets('adviser dashboard renders loaded mobile data without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(354, 754);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider(
      _FakeTokenService(),
      authService: _FakeAuthService(),
    );
    await authProvider.setToken(
      'token',
      user: const AppUser(
        id: 7,
        name: 'Sample Adviser',
        email: 'adviser@example.com',
        role: 'adviser',
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          Provider<ApiClient>.value(
            value: ApiClient(
              dio: Dio()..httpClientAdapter = _FakeAdapter(_dashboardPayload()),
            ),
          ),
          Provider<NotificationService>.value(value: _FakeNotificationService()),
        ],
        child: const MaterialApp(
          home: AdviserDashboardScreen(userName: 'Sample Adviser'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Monitoring Pulse'), findsOneWidget);
  });

  testWidgets(
    'adviser dashboard handles a single at-risk intern on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(354, 754);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authProvider = AuthProvider(
        _FakeTokenService(),
        authService: _FakeAuthService(),
      );
      await authProvider.setToken(
        'token',
        user: const AppUser(
          id: 7,
          name: 'Sample Adviser',
          email: 'adviser@example.com',
          role: 'adviser',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            Provider<ApiClient>.value(
              value: ApiClient(
                dio: Dio()
                  ..httpClientAdapter = _FakeAdapter(_singleAtRiskPayload()),
              ),
            ),
            Provider<NotificationService>.value(
              value: _FakeNotificationService(),
            ),
          ],
          child: const MaterialApp(
            home: AdviserDashboardScreen(userName: 'Sample Adviser'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('At-Risk Spotlight'), findsOneWidget);
      expect(find.text('Solo Student'), findsOneWidget);
    },
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

Map<String, dynamic> _singleAtRiskPayload() {
  return {
    'data': [
      _intern(
        id: 4,
        studentId: 4,
        studentName: 'Solo Student',
        companyName: 'Lone Wolf Labs',
        requiredHours: 486,
        completedHours: 12,
        pendingLogs: 0,
        approvedLogs: 1,
        totalLogs: 1,
        lastLogDate: '2026-05-01',
        endDate: '2026-07-30',
        alertStatus: 'BEHIND',
        alertMessage:
            'Behind expected pace. Completed 12 of 73 hours expected by today.',
        alertMeta: {'server_date': '2026-05-11', 'expected_hours_by_now': 73},
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

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/notifications')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': <Map<String, dynamic>>[],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 10,
            'total': 0,
            'unread_count': 0,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
