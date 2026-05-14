import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../../shared/models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  static const String _logTag = '[AuthProvider]';

  AuthProvider(this._tokenService, {required AuthService authService})
    : _authService = authService;

  final TokenService _tokenService;
  final AuthService _authService;

  String? _token;
  AppUser? _user;
  bool _isReady = false;
  ApiException? _lastError;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isReady => _isReady;
  bool get isAuthenticated {
    final hasToken = (_token ?? '').isNotEmpty;
    if (!_isReady) {
      return hasToken;
    }

    return hasToken && _user != null;
  }

  String get role => _user?.role ?? '';
  ApiException? get lastError => _lastError;

  String get dashboardRoute {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppRoutes.adminDashboard;
      case 'supervisor':
        return AppRoutes.supervisorDashboard;
      case 'adviser':
        return AppRoutes.adviserDashboard;
      case 'student':
      default:
        return AppRoutes.studentDashboard;
    }
  }

  Future<void> initialize() async {
    _log('initialize() start');

    try {
      await _tokenService.resetDebugBrowserSession();
      _token = await _tokenService.getToken();
      _user = await _tokenService.getUser();
      _log(
        'initialize() restored token=${(_token ?? '').isNotEmpty} user=${_user != null}',
      );

      if ((_token ?? '').isNotEmpty) {
        final synced = await _syncUserFromServer(silentOnError: true);
        if (!synced && _shouldClearSessionOnSyncFailure()) {
          _log('initialize() could not sync user; clearing session');
          await _clearSession();
        }
      }
    } catch (error) {
      _log('initialize() failed: $error');
      _lastError = _toApiException(
        error,
        fallbackMessage: 'Failed to restore your saved session.',
      );
      _token = null;
      _user = null;

      try {
        await _tokenService.clearToken();
      } catch (_) {
        // Startup should still recover to the login screen even if storage cleanup fails.
      }
    } finally {
      _isReady = true;
      _log(
        'initialize() complete isAuthenticated=$isAuthenticated role=${role.isEmpty ? 'unknown' : role}',
      );
      notifyListeners();
    }
  }

  Future<void> setToken(String token, {AppUser? user}) async {
    _log(
      'setToken() start tokenLength=${token.length} userProvided=${user != null}',
    );
    _token = token;
    _user = user;
    await _tokenService.saveToken(token);
    _log('setToken() token saved to secure storage');
    if (user != null) {
      await _tokenService.saveUser(user);
    }
    _lastError = null;

    if (_user == null) {
      _log('setToken() missing user payload; syncing from server');
      final synced = await _syncUserFromServer(silentOnError: true);
      if (!synced && _shouldClearSessionOnSyncFailure()) {
        _log('setToken() failed to sync user; clearing session');
        await _clearSession();
      }
    } else {
      _log('setToken() user role resolved as ${_user?.role}');
    }

    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if ((_token ?? '').isNotEmpty) {
        await _authService.logout();
      }
    } on ApiException {
      // Always clear the local session, even if the server token is already
      // invalid or the network is unavailable.
    }

    _token = null;
    _user = null;
    _lastError = null;
    await _tokenService.clearSession();
    notifyListeners();
  }

  Future<void> refreshAuthState() async {
    _log('refreshAuthState() start');
    _token = await _tokenService.getToken();
    _user = await _tokenService.getUser();
    if ((_token ?? '').isNotEmpty) {
      final synced = await _syncUserFromServer(silentOnError: true);
      if (!synced && _shouldClearSessionOnSyncFailure()) {
        _log('refreshAuthState() sync failed; clearing session');
        await _clearSession();
      }
    } else {
      _user = null;
    }
    _log(
      'refreshAuthState() complete isAuthenticated=$isAuthenticated role=${role.isEmpty ? 'unknown' : role}',
    );
    notifyListeners();
  }

  Future<bool> _syncUserFromServer({required bool silentOnError}) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) {
      _user = null;
      return false;
    }

    final previousUser = _user;

    try {
      _log('_syncUserFromServer() requesting /auth/me');
      _user = await _authService.getAuthenticatedUser();
      _log('_syncUserFromServer() resolved role=${_user?.role}');
      if (_user != null) {
        await _tokenService.saveUser(_user!);
      }
      _lastError = null;
      return true;
    } on ApiException catch (e) {
      _log(
        '_syncUserFromServer() failed status=${e.statusCode} type=${e.errorType} message=${e.message}',
      );
      if (!silentOnError) {
        _lastError = e;
        rethrow;
      }

      if (e.errorType == ApiErrorType.unauthorized) {
        _user = null;
      } else {
        _user = previousUser;
      }

      _lastError = e;
      return false;
    }
  }

  Future<void> _clearSession() async {
    _log('_clearSession() removing local session');
    _token = null;
    _user = null;
    _lastError = null;
    await _tokenService.clearSession();
  }

  bool _shouldClearSessionOnSyncFailure() {
    if (_lastError?.errorType == ApiErrorType.unauthorized) {
      return true;
    }

    return _user == null;
  }

  ApiException _toApiException(
    Object error, {
    required String fallbackMessage,
  }) {
    if (error is ApiException) {
      return error;
    }

    return ApiException(
      message: fallbackMessage,
      errorType: ApiErrorType.unknown,
      originalError: error,
    );
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }
}
