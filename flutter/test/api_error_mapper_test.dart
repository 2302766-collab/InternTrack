import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_error_mapper.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';

void main() {
  group('ApiErrorMapper', () {
    test('preserves backend 401 messages like invalid credentials', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: {
            'success': false,
            'message': 'Invalid credentials',
            'data': null,
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.fromDioException(exception);

      expect(mapped, isA<ApiException>());
      expect(mapped.errorType, ApiErrorType.unauthorized);
      expect(mapped.message, 'Invalid credentials');
    });

    test('falls back to session-expired message for generic 401 responses', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
          data: {'success': false, 'data': null},
        ),
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.fromDioException(exception);

      expect(mapped.errorType, ApiErrorType.unauthorized);
      expect(mapped.message, 'Your session has expired. Please log in again.');
    });
  });
}
