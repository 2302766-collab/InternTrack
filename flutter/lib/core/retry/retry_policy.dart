import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:math' show pow;

import 'package:dio/dio.dart';

/// Configuration for retry strategy
class RetryPolicy {
  /// Maximum number of retries (default: 3)
  final int maxRetries;

  /// Initial backoff duration (default: 1 second)
  final Duration initialBackoff;

  /// Multiplier for exponential backoff (default: 2)
  /// Next backoff = current backoff * multiplier
  final double backoffMultiplier;

  /// Maximum backoff duration (default: 32 seconds)
  /// Prevents backoff from growing too large
  final Duration maxBackoff;

  /// Whether to retry on timeout errors (default: true)
  final bool retryOnTimeout;

  /// Whether to retry on network/connection errors (default: true)
  final bool retryOnNetworkError;

  /// Whether to retry on 5xx server errors (default: true)
  final bool retryOn5xx;

  /// Status codes that should NOT be retried
  /// By default includes: 400, 401, 403, 404, 409, 422
  final Set<int> nonRetryableStatusCodes;

  RetryPolicy({
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxBackoff = const Duration(seconds: 32),
    this.retryOnTimeout = true,
    this.retryOnNetworkError = true,
    this.retryOn5xx = true,
    Set<int>? nonRetryableStatusCodes,
  }) : nonRetryableStatusCodes =
           nonRetryableStatusCodes ??
           {
             400, // Bad Request
             401, // Unauthorized
             403, // Forbidden
             404, // Not Found
             409, // Conflict
             422, // Unprocessable Entity (Validation)
           };

  /// Determines if a request should be retried based on the error
  bool shouldRetry(DioException exception, int attemptNumber) {
    // Don't retry if we've exhausted max attempts
    if (attemptNumber > maxRetries) {
      return false;
    }

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return retryOnTimeout;

      case DioExceptionType.connectionError:
        return retryOnNetworkError;

      case DioExceptionType.badResponse:
        // Check status code
        final statusCode = exception.response?.statusCode;
        if (statusCode == null) return false;

        // Don't retry non-retryable status codes
        if (nonRetryableStatusCodes.contains(statusCode)) {
          return false;
        }

        // Retry on 5xx errors if enabled
        if (statusCode >= 500 && statusCode < 600) {
          return retryOn5xx;
        }

        return false;

      case DioExceptionType.cancel:
        // Never retry cancelled requests
        return false;

      case DioExceptionType.badCertificate:
        // Never retry certificate errors
        return false;

      case DioExceptionType.unknown:
        // Only retry unknown errors if network-related
        if (exception.error is SocketException) return true;
        if (exception.error is TimeoutException) return true;
        return false;
    }
  }

  /// Calculates backoff duration for the given attempt number
  Duration calculateBackoff(int attemptNumber) {
    // Exponential backoff: initial * (multiplier ^ (attempt - 1))
    final exponent = (attemptNumber - 1).toDouble();
    final backoffMs = (initialBackoff.inMilliseconds *
            pow(backoffMultiplier, exponent))
        .toInt();

    final calculatedBackoff = Duration(milliseconds: backoffMs);

    // Cap at max backoff
    return calculatedBackoff.compareTo(maxBackoff) > 0
        ? maxBackoff
        : calculatedBackoff;
  }

  /// Creates a copy of this policy with updated values
  RetryPolicy copyWith({
    int? maxRetries,
    Duration? initialBackoff,
    double? backoffMultiplier,
    Duration? maxBackoff,
    bool? retryOnTimeout,
    bool? retryOnNetworkError,
    bool? retryOn5xx,
    Set<int>? nonRetryableStatusCodes,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      initialBackoff: initialBackoff ?? this.initialBackoff,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      maxBackoff: maxBackoff ?? this.maxBackoff,
      retryOnTimeout: retryOnTimeout ?? this.retryOnTimeout,
      retryOnNetworkError: retryOnNetworkError ?? this.retryOnNetworkError,
      retryOn5xx: retryOn5xx ?? this.retryOn5xx,
      nonRetryableStatusCodes:
          nonRetryableStatusCodes ?? this.nonRetryableStatusCodes,
    );
  }
}

// Pre-configured retry policies for common scenarios
class RetryPolicies {
  /// Conservative retry policy - 2 retries, long backoff
  static final conservative = RetryPolicy(
    maxRetries: 2,
    initialBackoff: const Duration(seconds: 2),
    backoffMultiplier: 3.0,
    maxBackoff: const Duration(seconds: 60),
  );

  /// Standard retry policy - 3 retries (default)
  static final standard = RetryPolicy();

  /// Aggressive retry policy - 5 retries, short backoff
  static final aggressive = RetryPolicy(
    maxRetries: 5,
    initialBackoff: const Duration(milliseconds: 500),
    backoffMultiplier: 1.5,
    maxBackoff: const Duration(seconds: 16),
  );

  /// No retry policy
  static final noRetry = RetryPolicy(maxRetries: 0);

  /// Quick timeout retry only - for timeout-sensitive operations
  static final timeoutOnly = RetryPolicy(
    maxRetries: 3,
    retryOnNetworkError: false,
    retryOn5xx: false,
  );
}
