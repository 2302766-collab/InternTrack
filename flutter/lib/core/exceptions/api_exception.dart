/// Unified exception for all API-related errors.
/// 
/// This exception wraps different error types (network, server, auth, validation)
/// into a single standardized format for easier handling throughout the app.
class ApiException implements Exception {
  /// The error message to display to users
  final String message;

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// The original error object for debugging
  final dynamic originalError;

  /// The type of error for specific handling
  final ApiErrorType errorType;

  /// Whether this is a recoverable error
  final bool isRecoverable;

  /// Additional error details (e.g., validation errors per field)
  final Map<String, dynamic>? details;

  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
    this.errorType = ApiErrorType.unknown,
    this.isRecoverable = true,
    this.details,
  });

  @override
  String toString() =>
      'ApiException(message: $message, statusCode: $statusCode, type: $errorType)';
}

/// Categorizes different types of API errors for specific handling
enum ApiErrorType {
  /// Network is unreachable
  networkError,

  /// Request timed out
  timeout,

  /// Invalid request (4xx, excluding 401/403)
  clientError,

  /// Server error (5xx)
  serverError,

  /// Authentication failed (401)
  unauthorized,

  /// Permission denied (403)
  forbidden,

  /// Resource not found (404)
  notFound,

  /// Conflict (409) - e.g., duplicate entry
  conflict,

  /// Validation failed (422) - has field-level errors
  validationError,

  /// Unknown error
  unknown,
}
