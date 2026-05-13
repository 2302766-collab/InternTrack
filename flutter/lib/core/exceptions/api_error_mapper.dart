import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

/// Maps different error sources to standardized ApiException instances.
///
/// This utility handles:
/// - DioException (network, timeout, response errors)
/// - Generic exceptions
/// - Server error responses with custom messages
class ApiErrorMapper {
  /// Maps DioException to ApiException
  static ApiException fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException(
          message: 'Network timeout. Please try again.',
          errorType: ApiErrorType.timeout,
          originalError: exception,
          isRecoverable: true,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: _unreachableApiMessage(),
          errorType: ApiErrorType.networkError,
          originalError: exception,
          isRecoverable: true,
        );

      case DioExceptionType.badResponse:
        return _mapStatusCodeError(exception.response, exception);

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled.',
          errorType: ApiErrorType.unknown,
          originalError: exception,
          isRecoverable: true,
        );

      case DioExceptionType.unknown:
        return ApiException(
          message: kIsWeb
              ? '${_unreachableApiMessage()} This can also happen when the browser blocks the API request.'
              : 'An unexpected error occurred. Please try again.',
          errorType: ApiErrorType.unknown,
          originalError: exception,
          isRecoverable: true,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'Security certificate error. Contact support.',
          errorType: ApiErrorType.unknown,
          originalError: exception,
          isRecoverable: false,
        );
    }
  }

  /// Maps HTTP status codes to ApiException
  static ApiException _mapStatusCodeError(
    Response? response,
    DioException originalException,
  ) {
    final statusCode = response?.statusCode ?? 0;
    final responseData = response?.data;
    final requestPath = originalException.requestOptions.path;

    // Extract server message if available
    String? serverMessage;
    if (responseData is Map<String, dynamic>) {
      serverMessage = responseData['message'] as String?;
    }

    switch (statusCode) {
      case 400:
        return ApiException(
          message: serverMessage ?? 'Invalid request. Please check your input.',
          statusCode: statusCode,
          errorType: ApiErrorType.clientError,
          originalError: originalException,
          details: (responseData is Map) ? Map.from(responseData) : null,
          isRecoverable: true,
        );

      case 401:
        final isAuthRequest = requestPath.startsWith('/auth/');
        return ApiException(
          message:
              serverMessage ??
              (isAuthRequest
                  ? 'Invalid email or password.'
                  : 'Your session has expired. Please log in again.'),
          statusCode: statusCode,
          errorType: ApiErrorType.unauthorized,
          originalError: originalException,
          isRecoverable: true,
        );

      case 403:
        return ApiException(
          message: 'You do not have permission to perform this action.',
          statusCode: statusCode,
          errorType: ApiErrorType.forbidden,
          originalError: originalException,
          isRecoverable: false,
        );

      case 404:
        return ApiException(
          message: serverMessage ?? 'Resource not found.',
          statusCode: statusCode,
          errorType: ApiErrorType.notFound,
          originalError: originalException,
          isRecoverable: true,
        );

      case 409:
        return ApiException(
          message:
              serverMessage ??
              'This resource already exists or there is a conflict.',
          statusCode: statusCode,
          errorType: ApiErrorType.conflict,
          originalError: originalException,
          details: (responseData is Map) ? Map.from(responseData) : null,
          isRecoverable: true,
        );

      case 422:
        // Validation errors - extract field-level errors
        final Map<String, dynamic> errors = {};
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('errors')) {
            errors.addAll(responseData['errors']);
          }
          final nestedData = responseData['data'];
          if (nestedData is Map<String, dynamic> &&
              nestedData['errors'] is Map<String, dynamic>) {
            errors.addAll(nestedData['errors'] as Map<String, dynamic>);
          }
        }

        return ApiException(
          message: serverMessage ?? 'Please check your input and try again.',
          statusCode: statusCode,
          errorType: ApiErrorType.validationError,
          originalError: originalException,
          details: errors.isNotEmpty ? errors : null,
          isRecoverable: true,
        );

      case >= 500:
        return ApiException(
          message:
              serverMessage ??
              ((statusCode == 502 || statusCode == 503 || statusCode == 504)
                  ? 'Server unavailable. Please try again later.'
                  : 'Server error. Please try again later.'),
          statusCode: statusCode,
          errorType: ApiErrorType.serverError,
          originalError: originalException,
          isRecoverable: true,
        );

      default:
        return ApiException(
          message:
              serverMessage ??
              'An unexpected error occurred. Please try again.',
          statusCode: statusCode,
          errorType: ApiErrorType.unknown,
          originalError: originalException,
          isRecoverable: true,
        );
    }
  }

  /// Maps generic exceptions to ApiException
  static ApiException fromException(dynamic exception) {
    if (exception is ApiException) {
      return exception;
    }

    if (exception is DioException) {
      return fromDioException(exception);
    }

    return ApiException(
      message: 'An unexpected error occurred. Please try again.',
      errorType: ApiErrorType.unknown,
      originalError: exception,
      isRecoverable: true,
    );
  }

  static String _unreachableApiMessage() {
    return 'Unable to reach the API at ${ApiConfig.baseUrl}. '
        'Start the Laravel server, confirm the API host/port, or set API_BASE_URL.';
  }
}
