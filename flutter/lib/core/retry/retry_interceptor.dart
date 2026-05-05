import 'dart:async';

import 'package:dio/dio.dart';

import 'retry_policy.dart';

/// Interceptor that implements intelligent retry logic with exponential backoff
///
/// Automatically retries failed requests based on configurable retry policy.
/// Handles:
/// - Network timeouts and connection errors
/// - Server errors (5xx)
/// - Exponential backoff between retries
/// - Logging of retry attempts
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// final retryInterceptor = RetryInterceptor(dio, RetryPolicies.standard);
/// dio.interceptors.add(retryInterceptor);
/// ```
class RetryInterceptor extends QueuedInterceptor {
  final Dio dio;
  final RetryPolicy policy;

  RetryInterceptor(this.dio, this.policy);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Get attempt count from request options
    int attemptNumber = (err.requestOptions.extra['retry_attempt'] ?? 0) as int;
    attemptNumber++;

    // Check if we should retry
    if (policy.shouldRetry(err, attemptNumber)) {
      try {
        // Calculate backoff duration
        final backoff = policy.calculateBackoff(attemptNumber);

        _logRetryAttempt(
          err.requestOptions.path,
          attemptNumber,
          backoff,
          err,
        );

        // Wait for backoff period
        await Future.delayed(backoff);

        // Update attempt count and retry
        final options = err.requestOptions;
        options.extra['retry_attempt'] = attemptNumber;

        // Retry the request using the stored Dio instance
        final response = await dio.request<dynamic>(
          options.path,
          data: options.data,
          queryParameters: options.queryParameters,
          options: Options(
            method: options.method,
            sendTimeout: options.sendTimeout,
            receiveTimeout: options.receiveTimeout,
            extra: options.extra,
            headers: options.headers,
            contentType: options.contentType,
            responseType: options.responseType,
            validateStatus: options.validateStatus,
          ),
        );

        return handler.resolve(response);
      } catch (e) {
        // If retry fails, pass the error through
        if (e is DioException) {
          return handler.next(e);
        }
        rethrow;
      }
    }

    // Don't retry - pass error through
    return handler.next(err);
  }

  void _logRetryAttempt(
    String path,
    int attemptNumber,
    Duration backoff,
    DioException error,
  ) {
    final errorType = error.type.toString().split('.').last;
    final statusCode = error.response?.statusCode ?? 'N/A';

    // Log retry attempt for debugging
    // Use print for now - can be replaced with proper logging framework
    // ignore: avoid_print
    print(
      '[RetryInterceptor] Attempt $attemptNumber: $path '
      '($errorType, status: $statusCode) '
      'backing off for ${backoff.inSeconds}s',
    );
  }
}
