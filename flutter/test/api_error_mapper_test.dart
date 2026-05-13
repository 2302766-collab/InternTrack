import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_error_mapper.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';

void main() {
  group('ApiErrorMapper', () {
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

      expect(mapped, isA<ApiException>());
      expect(mapped.errorType, ApiErrorType.unauthorized);
      expect(mapped.message, 'Invalid credentials');
    });
  });
}
