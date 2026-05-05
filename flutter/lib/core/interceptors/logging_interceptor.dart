import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Logs HTTP request and response information for debugging
/// 
/// In development, this helps track API calls and responses.
/// In production, this would integrate with a logging service like Sentry.
class LoggingInterceptor extends QueuedInterceptor {
  static const String _tag = '[API]';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logRequest(options);
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logResponse(response);
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logError(err);
    return handler.next(err);
  }

  void _logRequest(RequestOptions options) {
    debugPrint('$_tag REQUEST');
    debugPrint('  Method: ${options.method}');
    debugPrint('  URL: ${options.uri}');
    debugPrint('  Headers: ${_formatHeaders(options.headers)}');
    if (options.data != null) {
      debugPrint('  Body: ${options.data}');
    }
  }

  void _logResponse(Response response) {
    debugPrint('$_tag RESPONSE');
    debugPrint('  Status: ${response.statusCode}');
    debugPrint('  URL: ${response.requestOptions.uri}');
    if (response.data != null) {
      debugPrint('  Data: ${response.data}');
    }
  }

  void _logError(DioException err) {
    debugPrint('$_tag ERROR');
    debugPrint('  Type: ${err.type}');
    debugPrint('  URL: ${err.requestOptions.uri}');
    if (err.response != null) {
      debugPrint('  Status: ${err.response?.statusCode}');
      debugPrint('  Data: ${err.response?.data}');
    }
    debugPrint('  Message: ${err.message}');
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    // Hide sensitive information
    final formatted = <String, dynamic>{};
    headers.forEach((key, value) {
      if (key.toLowerCase() == 'authorization' && value is String) {
        formatted[key] = '${value.substring(0, 10)}...';
      } else {
        formatted[key] = value;
      }
    });
    return formatted.toString();
  }
}
