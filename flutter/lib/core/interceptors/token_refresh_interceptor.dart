import 'package:dio/dio.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Surfaces 401 responses without force-logging out the user mid-request.
///
/// The app already validates stored tokens during bootstrap in [AuthProvider].
/// Clearing the session inside a global interceptor can bounce the user back to
/// the login screen if an early dashboard request races with token persistence
/// on web. Individual screens can still decide to redirect on 401 when needed.
class TokenRefreshInterceptor extends QueuedInterceptor {
  final AuthProvider _authProvider;

  TokenRefreshInterceptor(this._authProvider);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestPath = err.requestOptions.path;

    if (err.response?.statusCode == 401) {
      final hasSessionToken = (_authProvider.token ?? '').isNotEmpty;

      // Let callers decide whether to show an error, retry, or redirect.
      if (hasSessionToken && !requestPath.startsWith('/auth/')) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
