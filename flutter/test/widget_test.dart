import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders required fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: ApiClient(dio: Dio())),
          ProxyProvider<ApiClient, AuthService>(
            update: (context, apiClient, previous) => AuthService(apiClient),
          ),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create one'), findsOneWidget);
  });
}
