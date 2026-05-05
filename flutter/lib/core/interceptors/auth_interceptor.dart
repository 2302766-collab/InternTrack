import 'package:dio/dio.dart';

import '../services/token_service.dart';

/// Automatically injects authorization token into all requests
/// 
/// This interceptor ensures that every API request includes the current
/// bearer token without having to pass it manually to each service method
class AuthInterceptor extends QueuedInterceptor {
  final TokenService _tokenService;

  AuthInterceptor(this._tokenService);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get current token from secure storage
    final token = await _tokenService.getToken();

    // If token exists, add it to headers
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Continue with request
    return handler.next(options);
  }
}
