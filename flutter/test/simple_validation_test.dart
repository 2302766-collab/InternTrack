import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intern_track_app/features/auth/presentation/screens/login_screen.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/core/services/api_client.dart';

void main() {
  group('Login Form Simple Validation Test', () {
    testWidgets('form validation behavior test', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // Find the form fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);
      final submitButton = find.byType(ElevatedButton);

      debugPrint('Initial state - checking submit button');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      debugPrint('Entering valid email and password');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      debugPrint('Checking if submit button is now enabled');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNotNull);

      debugPrint('Clearing email to test validation');
      await tester.enterText(emailField, '');
      await tester.pumpAndSettle();

      debugPrint('Submit button should be disabled again');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      debugPrint('Test completed successfully');
    });
  });
}

Widget _buildTestApp() {
  final authService = MockAuthService();
  final tokenService = MockTokenService();

  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: authService),
      Provider<TokenService>.value(value: tokenService),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(tokenService, authService: authService),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

class MockAuthService extends AuthService {
  MockAuthService() : super(ApiClient());
}

class MockTokenService extends TokenService {
  MockTokenService() : super();
}
