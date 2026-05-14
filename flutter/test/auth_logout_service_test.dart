import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/auth_service.dart';

void main() {
  test('AuthService.logout posts to /auth/logout', () async {
    final adapter = _RecordingAdapter();
    final service = AuthService(
      ApiClient(dio: Dio()..httpClientAdapter = adapter),
    );

    await service.logout();

    expect(adapter.recordedPaths, ['/auth/logout']);
    expect(adapter.recordedMethods, ['POST']);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> recordedPaths = [];
  final List<String> recordedMethods = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedPaths.add(options.path);
    recordedMethods.add(options.method);

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Logged out successfully',
        'data': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
