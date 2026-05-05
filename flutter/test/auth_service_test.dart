import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/shared/models/app_user.dart';

void main() {
  group('AuthService.getAuthenticatedUser', () {
    test('parses nested user payload from /auth/me', () async {
      final service = AuthService(
        ApiClient(
          dio: Dio()..httpClientAdapter = _FakeAdapter({
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
          dio: Dio()..httpClientAdapter = _FakeAdapter({
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
        jsonEncode({
          'success': false,
          'message': 'Not found',
          'data': null,
        }),
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
