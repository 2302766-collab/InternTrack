import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_error_mapper.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';

void main() {
  group('ApiErrorMapper', () {
<<<<<<< HEAD
    test('preserves backend 401 messages when present', () {
      final requestOptions = RequestOptions(path: '/auth/login');
      final response = Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 401,
        data: const {
          'success': false,
          'message': 'Invalid credentials',
          'data': null,
        },
      );

      final exception = DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.fromDioException(exception);
=======
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

      final mapped = ApiErrorMapper.fromException(exception);
>>>>>>> 6fbbe9d (Login issue)

      expect(mapped, isA<ApiException>());
      expect(mapped.errorType, ApiErrorType.unauthorized);
      expect(mapped.message, 'Invalid credentials');
    });
<<<<<<< HEAD
=======

    test('falls back to session-expired message for generic 401 responses', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
          data: {
            'success': false,
            'data': null,
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.fromException(exception);

      expect(mapped.errorType, ApiErrorType.unauthorized);
      expect(mapped.message, 'Your session has expired. Please log in again.');
    });
>>>>>>> 6fbbe9d (Login issue)
  });
}
