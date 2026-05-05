import 'package:flutter/foundation.dart';

import '../exceptions/api_exception.dart';

/// Base class for all API services
/// 
/// Provides common functionality like:
/// - Error handling conventions
/// - Header management
/// - Token injection
/// - Request/response logging (for debugging)
abstract class BaseService {
  /// Handles API exceptions and provides user-friendly error messages
  /// 
  /// This is called whenever an ApiException is caught
  /// Can be overridden in subclasses for service-specific behavior
  void handleApiError(ApiException exception) {
    // Log the error for debugging
    _logError(exception);
  }

  /// Logs errors for debugging (can be extended with external logging)
  void _logError(ApiException exception) {
    // In production, you'd send this to Sentry, Firebase, etc.
    debugPrint('[ApiError] ${exception.errorType}: ${exception.message}');
    if (exception.originalError != null) {
      debugPrint('[ApiError] Original: ${exception.originalError}');
    }
  }

  /// Helper to check if error is recoverable (for retry logic)
  bool canRetry(ApiException exception) {
    return exception.isRecoverable &&
        exception.errorType != ApiErrorType.unauthorized &&
        exception.errorType != ApiErrorType.forbidden;
  }
}
