import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/shared/models/app_user.dart';

void main() {
  group('AuthService.getAuthenticatedUser', () {
    test('parses nested user payload from /auth/me', () async {
      final service = AuthService(
        ApiClient(
          dio: Dio()
            ..httpClientAdapter = _FakeAdapter({
              '/auth/me': {
                'success': true,
                'message': 'Authenticated user',
                'data': {
                  'user': {
                    'id': 2,
                    'name': 'Sample Student',
                    'email': 'student@example.com',
                    'role': 'Student',
                  },
                },
              },
            }),
        ),
      );

      final user = await service.getAuthenticatedUser();

      expect(
        user,
        isA<AppUser>()
            .having((u) => u.id, 'id', 2)
            .having((u) => u.name, 'name', 'Sample Student')
            .having((u) => u.email, 'email', 'student@example.com')
            .having((u) => u.role, 'role', 'Student'),
      );
    });

    test('keeps compatibility with direct user payloads', () async {
      final service = AuthService(
        ApiClient(
          dio: Dio()
            ..httpClientAdapter = _FakeAdapter({
              '/auth/me': {
                'success': true,
                'message': 'Authenticated user',
                'data': {
                  'id': 3,
                  'name': 'Legacy User',
                  'email': 'legacy@example.com',
                  'role': 'Supervisor',
                },
              },
            }),
        ),
      );

      final user = await service.getAuthenticatedUser();

      expect(user.id, 3);
      expect(user.name, 'Legacy User');
      expect(user.email, 'legacy@example.com');
      expect(user.role, 'Supervisor');
    });

    test('throws ApiException when user data is missing', () async {
      final service = AuthService(
        ApiClient(
          dio: Dio()
            ..httpClientAdapter = _FakeAdapter({
              '/auth/me': {
                'success': true,
                'message': 'Authenticated user',
                'data': null,
              },
            }),
        ),
      );

      await expectLater(
        service.getAuthenticatedUser(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'No user data in response',
          ),
        ),
      );
    });
  });

  group('AuthService.login', () {
    test('returns token and user from login response', () async {
      final service = AuthService(
        ApiClient(
          dio: Dio()
            ..httpClientAdapter = _FakeAdapter({
              '/auth/login': {
                'success': true,
                'message': 'Login successful',
                'data': {
                  'access_token': 'token-123',
                  'user': {
                    'id': 7,
                    'name': 'Student User',
                    'email': 'student@example.com',
                    'role': 'Student',
                  },
                },
              },
            }),
        ),
      );

      final result = await service.login(
        email: 'student@example.com',
        password: 'password',
      );

      expect(result['token'], 'token-123');
      expect(result['user'], isA<Map<String, dynamic>>());
    });

    test(
      'throws ApiException when token is missing from login response',
      () async {
        final service = AuthService(
          ApiClient(
            dio: Dio()
              ..httpClientAdapter = _FakeAdapter({
                '/auth/login': {
                  'success': true,
                  'message': 'Login successful',
                  'data': {
                    'user': {
                      'id': 7,
                      'name': 'Student User',
                      'email': 'student@example.com',
                      'role': 'Student',
                    },
                  },
                },
              }),
          ),
        );

        await expectLater(
          service.login(email: 'student@example.com', password: 'password'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'No access token in login response',
            ),
          ),
        );
      },
    );
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._responses);

  final Map<String, Map<String, dynamic>> _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = _responses[options.path];
    if (payload == null) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'message': 'Not found', 'data': null}),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
