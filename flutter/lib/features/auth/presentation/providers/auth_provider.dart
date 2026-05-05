import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../../shared/models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._tokenService, {
    required AuthService authService,
  }) : _authService = authService;

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
    _token = await _tokenService.getToken();

    if ((_token ?? '').isNotEmpty) {
      final synced = await _syncUserFromServer(silentOnError: true);
      if (!synced) {
        await _clearSession();
      }
    }

    _isReady = true;
    notifyListeners();
  }

  Future<void> setToken(String token, {AppUser? user}) async {
    _token = token;
    _user = user;
    await _tokenService.saveToken(token);
    _lastError = null;

    if (_user == null) {
      final synced = await _syncUserFromServer(silentOnError: true);
      if (!synced) {
        await _clearSession();
      }
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _lastError = null;
    await _tokenService.clearToken();
    notifyListeners();
  }

  Future<void> refreshAuthState() async {
    _token = await _tokenService.getToken();
    if ((_token ?? '').isNotEmpty) {
      final synced = await _syncUserFromServer(silentOnError: true);
      if (!synced) {
        await _clearSession();
      }
    } else {
      _user = null;
    }
    notifyListeners();
  }

  Future<bool> _syncUserFromServer({required bool silentOnError}) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) {
      _user = null;
      return false;
    }

    try {
      _user = await _authService.getAuthenticatedUser();
      _lastError = null;
      return true;
    } on ApiException catch (e) {
      if (!silentOnError) {
        _lastError = e;
        rethrow;
      }
      _user = null;
      _lastError = e;
      return false;
    }
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _lastError = null;
    await _tokenService.clearToken();
  }
}
