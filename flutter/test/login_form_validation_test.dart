import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/features/auth/presentation/screens/login_screen.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:provider/provider.dart';

void main() {
  group('Login Form Validation Tests', () {
    late AuthService mockAuthService;
    late TokenService mockTokenService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockTokenService = MockTokenService();
    });

    testWidgets('shows email required error when email is empty', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      // Find email field and submit button
      final emailField = find.byType(TextFormField).first;
      final submitButton = find.byType(ElevatedButton);

      // Submit button should be disabled initially
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      // Interact with the field and clear it so autovalidation can surface the error.
      await tester.enterText(emailField, 'temp@example.com');
      await tester.pumpAndSettle();
      await tester.enterText(emailField, '');
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('shows invalid email error for malformed email', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      final emailField = find.byType(TextFormField).first;
      
      // Enter invalid email
      await tester.enterText(emailField, 'invalid-email');
      await tester.pumpAndSettle();

      // Should show invalid email error
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows password required error when password is empty', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      // Enter valid email but empty password
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();
      await tester.enterText(passwordField, '');
      await tester.pumpAndSettle();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows password length error for short password', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter valid email and short password
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, '123');
      await tester.pumpAndSettle();

      // Should show password length error
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('submit button is disabled when form is invalid', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      final submitButton = find.byType(ElevatedButton);

      // Initially should be disabled
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      // Enter valid email and password
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Now should be enabled
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNotNull);
    });

    testWidgets('valid inputs pass validation and enable submission', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);
      // Enter valid credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Should not show any error messages
      expect(find.text('Email is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Password is required'), findsNothing);
      expect(find.text('Password must be at least 8 characters'), findsNothing);

      // Submit button should be enabled
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    });

    testWidgets('real-time validation triggers on user interaction', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(mockAuthService, mockTokenService),
      );

      final emailField = find.byType(TextFormField).first;

      // Initially no errors
      expect(find.text('Enter a valid email address'), findsNothing);

      // Type invalid email
      await tester.enterText(emailField, 'invalid');
      await tester.pumpAndSettle();

      // Should show error immediately
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Fix email
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      // Error should disappear
      expect(find.text('Enter a valid email address'), findsNothing);
    });

    testWidgets('shows a friendly invalid credentials error on failed login', (
      tester,
    ) async {
      final authService = MockAuthService(
        loginError: ApiException(
          message: 'Invalid credentials',
          statusCode: 401,
          errorType: ApiErrorType.unauthorized,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(authService, mockTokenService),
      );

      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'adviser@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(find.textContaining('ApiException('), findsNothing);
    });
  });
}

Widget _buildTestApp(AuthService authService, TokenService tokenService) {
  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: authService),
      Provider<TokenService>.value(value: tokenService),
      ChangeNotifierProvider(create: (_) => AuthProvider(tokenService, authService: authService)),
    ],
    child: MaterialApp(
      home: LoginScreen(),
    ),
  );
}

class MockAuthService extends AuthService {
  MockAuthService({this.loginError}) : super(ApiClient());

  final Object? loginError;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final loginError = this.loginError;
    if (loginError != null) {
      throw loginError;
    }

    return {
      'token': 'token',
      'user': {
        'id': 1,
        'name': 'Test User',
        'email': email,
        'role': 'Student',
      },
    };
  }
}

class MockTokenService extends TokenService {
  MockTokenService() : super();
}
