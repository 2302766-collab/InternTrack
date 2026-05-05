/// Exception for Supervisor Log API operations.
/// 
/// Used when supervisor log-specific operations fail with validation or business logic errors.
class SupervisorLogApiException implements Exception {
  /// The error message to display to users
  final String message;

  /// Field-level validation errors (e.g., {"remarks": ["Required field"]})
  final Map<String, List<String>>? fieldErrors;

  SupervisorLogApiException({
    required this.message,
    this.fieldErrors,
  });

  @override
  String toString() => message;
}
