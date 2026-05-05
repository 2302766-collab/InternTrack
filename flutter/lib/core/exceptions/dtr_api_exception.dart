/// Exception for DTR (Daily Time Record) API operations.
/// 
/// Used when DTR-specific operations fail with validation or business logic errors.
class DtrApiException implements Exception {
  /// The error message to display to users
  final String message;

  /// Field-level validation errors (e.g., {"punch_time": ["Invalid time format"]})
  final Map<String, List<String>>? fieldErrors;

  DtrApiException({
    required this.message,
    this.fieldErrors,
  });

  @override
  String toString() => message;
}
