import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('Login Form Simple Validation Test', () {
    testWidgets('form validation behavior test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find the form fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);
      final submitButton = find.byType(ElevatedButton);

      print('Initial state - checking submit button');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      print('Entering valid email and password');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      print('Checking if submit button is now enabled');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNotNull);

      print('Clearing email to test validation');
      await tester.enterText(emailField, '');
      await tester.pumpAndSettle();

      print('Submit button should be disabled again');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);

      print('Test completed successfully');
    });
  });
}
