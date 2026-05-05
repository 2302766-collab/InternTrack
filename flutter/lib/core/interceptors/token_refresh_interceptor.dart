import 'package:dio/dio.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Handles 401 token expiration errors and attempts token refresh
/// 
/// When a 401 response is received:
/// 1. Logs out the user (clears token)
/// 2. Lets the error propagate as a DioException with UNAUTHORIZED info
/// 3. UI layer should detect this and redirect to login
/// 
/// Future versions could implement actual token refresh mechanism
/// if the backend supports refresh tokens
class TokenRefreshInterceptor extends QueuedInterceptor {
  final AuthProvider _authProvider;
  bool _isRefreshing = false;

  TokenRefreshInterceptor(this._authProvider);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - token expired
    if (err.response?.statusCode == 401) {
      if (!_isRefreshing) {
        _isRefreshing = true;

        try {
          // Attempt to logout user
          await _authProvider.logout();
        } catch (_) {
          // Error during logout, continue anyway
        } finally {
          _isRefreshing = false;
        }
      }

      // Return the error for ApiErrorMapper to convert to ApiException
      return handler.next(err);
    }

    // For other errors, pass through
    return handler.next(err);
  }
}
