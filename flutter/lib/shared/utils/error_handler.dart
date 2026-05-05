import 'package:flutter/material.dart';

import '../../core/exceptions/api_exception.dart';

/// Utility for displaying API errors to users in a user-friendly way
/// 
/// Usage:
/// ```dart
/// try {
///   await someApiCall();
/// } on ApiException catch (e) {
///   if (mounted) {
///     ErrorHandler.showErrorSnackbar(context, e);
///   }
/// }
/// ```
class ErrorHandler {
  /// Shows error as a snackbar
  static void showErrorSnackbar(BuildContext context, ApiException exception) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exception.message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
        action: exception.isRecoverable
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () {
                  // This will just dismiss the snackbar
                  // The caller should implement retry logic
                },
              )
            : null,
      ),
    );
  }

  /// Shows error as an alert dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    ApiException exception, {
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exception.message),
                if (exception.details != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailsWidget(exception.details),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('DISMISS'),
            ),
            if (exception.isRecoverable && onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: const Text('RETRY'),
              ),
          ],
        );
      },
    );
  }

  /// Gets a color for the error type
  static Color getErrorColor(ApiErrorType errorType) {
    switch (errorType) {
      case ApiErrorType.timeout:
        return Colors.orange;
      case ApiErrorType.networkError:
        return Colors.orange;
      case ApiErrorType.unauthorized:
        return Colors.red;
      case ApiErrorType.forbidden:
        return Colors.red;
      case ApiErrorType.validationError:
        return Colors.amber;
      case ApiErrorType.conflict:
        return Colors.purple;
      case ApiErrorType.notFound:
        return Colors.blue;
      case ApiErrorType.clientError:
      case ApiErrorType.serverError:
      case ApiErrorType.unknown:
        return Colors.red;
    }
  }

  /// Gets a human-readable error type label
  static String getErrorTypeLabel(ApiErrorType errorType) {
    switch (errorType) {
      case ApiErrorType.timeout:
        return 'Request Timeout';
      case ApiErrorType.networkError:
        return 'Network Error';
      case ApiErrorType.unauthorized:
        return 'Authentication Error';
      case ApiErrorType.forbidden:
        return 'Permission Denied';
      case ApiErrorType.validationError:
        return 'Validation Error';
      case ApiErrorType.conflict:
        return 'Conflict';
      case ApiErrorType.notFound:
        return 'Not Found';
      case ApiErrorType.clientError:
        return 'Client Error';
      case ApiErrorType.serverError:
        return 'Server Error';
      case ApiErrorType.unknown:
        return 'Unknown Error';
    }
  }

  /// Builds widget to display error details
  static Widget _buildDetailsWidget(dynamic details) {
    if (details == null) {
      return const SizedBox.shrink();
    }

    if (details is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.entries.map((entry) {
          final value = entry.value;
          final displayValue = value is List ? value.join(', ') : value.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• ${entry.key}: $displayValue',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
      );
    }

    return Text(
      details.toString(),
      style: const TextStyle(fontSize: 12),
    );
  }
}

/// Widget that wraps an async operation and handles errors gracefully
/// 
/// Usage:
/// ```dart
/// AsyncErrorBoundary(
///   asyncOperation: () => apiService.fetchData(),
///   builder: (context, data) => DataDisplayWidget(data),
/// )
/// ```
class AsyncErrorBoundary<T> extends StatefulWidget {
  final Future<T> Function() asyncOperation;
  final Widget Function(BuildContext, T) builder;
  final Widget? loadingWidget;

  const AsyncErrorBoundary({
    super.key,
    required this.asyncOperation,
    required this.builder,
    this.loadingWidget,
  });

  @override
  State<AsyncErrorBoundary<T>> createState() => _AsyncErrorBoundaryState<T>();
}

class _AsyncErrorBoundaryState<T> extends State<AsyncErrorBoundary<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _retry();
  }

  void _retry() {
    _future = widget.asyncOperation();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is ApiException) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: ErrorHandler.getErrorColor(error.errorType),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.getErrorTypeLabel(error.errorType),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.message,
                      textAlign: TextAlign.center,
                    ),
                    if (error.isRecoverable) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _retry()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // Non-API errors
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _retry()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data'));
        }

        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
