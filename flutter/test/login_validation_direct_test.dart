import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Login Form Validation Direct Test', () {
    testWidgets('email regex validation test', (tester) async {
      // Test the email regex pattern directly
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      
      // Valid emails
      expect(emailRegex.hasMatch('test@example.com'), isTrue);
      expect(emailRegex.hasMatch('user@domain.org'), isTrue);
      expect(emailRegex.hasMatch('email@sub.domain.com'), isTrue);
      
      // Invalid emails
      expect(emailRegex.hasMatch(''), isFalse);
      expect(emailRegex.hasMatch('invalid'), isFalse);
      expect(emailRegex.hasMatch('test@'), isFalse);
      expect(emailRegex.hasMatch('@example.com'), isFalse);
      expect(emailRegex.hasMatch('test.example.com'), isFalse);
    });

    testWidgets('form validation logic test', (tester) async {
      // Test the form validation logic directly
      bool isFormValid(String email, String password) {
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
        return email.isNotEmpty &&
            emailRegex.hasMatch(email) &&
            password.isNotEmpty &&
            password.length >= 8;
      }

      // Valid combinations
      expect(isFormValid('test@example.com', 'password123'), isTrue);
      expect(isFormValid('user@domain.org', 'validpass123'), isTrue);

      // Invalid combinations
      expect(isFormValid('', 'password123'), isFalse); // Empty email
      expect(isFormValid('invalid-email', 'password123'), isFalse); // Invalid email
      expect(isFormValid('test@example.com', ''), isFalse); // Empty password
      expect(isFormValid('test@example.com', '123'), isFalse); // Short password
      expect(isFormValid('', ''), isFalse); // Both empty
    });

    testWidgets('form UI validation test', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  TextFormField(
                    key: Key('email_field'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

                      if (text.isEmpty) {
                        return 'Email is required';
                      }

                      if (!emailRegex.hasMatch(text)) {
                        return 'Enter a valid email address';
                      }

                      return null;
                    },
                  ),
                  TextFormField(
                    key: Key('password_field'),
                    validator: (value) {
                      final text = value ?? '';

                      if (text.isEmpty) {
                        return 'Password is required';
                      }

                      if (text.length < 8) {
                        return 'Password must be at least 8 characters';
                      }

                      return null;
                    },
                  ),
                  ElevatedButton(
                    key: Key('submit_button'),
                    onPressed: () {
                      formKey.currentState!.validate();
                    },
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final emailField = find.byKey(Key('email_field'));
      final passwordField = find.byKey(Key('password_field'));
      final submitButton = find.byKey(Key('submit_button'));

      // Test empty email validation
      await tester.enterText(emailField, 'temp@example.com');
      await tester.pumpAndSettle();
      await tester.enterText(emailField, '');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Email is required'), findsOneWidget);

      // Test invalid email validation
      await tester.enterText(emailField, 'invalid-email');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Test empty password validation
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();
      await tester.enterText(passwordField, '');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Password is required'), findsOneWidget);

      // Test short password validation
      await tester.enterText(passwordField, '123');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // Test valid inputs
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      
      // Should not show any error messages
      expect(find.text('Email is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Password is required'), findsNothing);
      expect(find.text('Password must be at least 8 characters'), findsNothing);
    });
  });
}
