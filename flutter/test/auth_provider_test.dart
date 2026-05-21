import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:intern_track_app/core/constants/app_routes.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/auth_service.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/token_service.dart';
import 'package:intern_track_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intern_track_app/shared/models/app_user.dart';

void main() {
  group('AuthProvider', () {
    test('loads a valid stored token and authenticated user', () async {
      final tokenService = _FakeTokenService('stored-token');
      final authService = _FakeAuthService(user: _student);
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.initialize();

      expect(provider.isReady, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.token, 'stored-token');
      expect(provider.user, _student);
      expect(tokenService.cleared, isFalse);
    });

    test('resets debug browser session before bootstrap', () async {
      final tokenService = _FakeTokenService('stored-token', _student);
      final authService = _FakeAuthService(user: _student);
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.initialize();

      expect(tokenService.resetDebugSessionCalled, isTrue);
    });

    test(
      'keeps cached user session when bootstrap sync fails due to network error',
      () async {
        final tokenService = _FakeTokenService('stored-token', _student);
        final authService = _FakeAuthService(
          error: ApiException(
            message: 'Unable to reach the server.',
            errorType: ApiErrorType.networkError,
          ),
        );
        final provider = AuthProvider(tokenService, authService: authService);

        await provider.initialize();

        expect(provider.isReady, isTrue);
        expect(provider.isAuthenticated, isTrue);
        expect(provider.token, 'stored-token');
        expect(provider.user, _student);
        expect(tokenService.cleared, isFalse);
      },
    );

    test('clears an invalid stored token during initialization', () async {
      final tokenService = _FakeTokenService('stale-token');
      final authService = _FakeAuthService(
        error: ApiException(
          message: 'Unauthenticated.',
          errorType: ApiErrorType.unauthorized,
        ),
      );
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.initialize();

      expect(provider.isReady, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.token, isNull);
      expect(provider.user, isNull);
      expect(tokenService.storedToken, isNull);
      expect(tokenService.cleared, isTrue);
    });

    test('clears token when setToken cannot sync the user', () async {
      final tokenService = _FakeTokenService();
      final authService = _FakeAuthService(
        error: ApiException(
          message: 'Unauthenticated.',
          errorType: ApiErrorType.unauthorized,
        ),
      );
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.setToken('bad-token');

      expect(provider.isAuthenticated, isFalse);
      expect(provider.token, isNull);
      expect(provider.user, isNull);
      expect(tokenService.storedToken, isNull);
      expect(tokenService.cleared, isTrue);
    });

    test(
      'persists provided login user without a follow-up auth sync',
      () async {
        final tokenService = _FakeTokenService();
        final authService = _FakeAuthService();
        final provider = AuthProvider(tokenService, authService: authService);

        await provider.setToken('good-token', user: _student);

        expect(provider.isAuthenticated, isTrue);
        expect(provider.token, 'good-token');
        expect(provider.user, _student);
        expect(tokenService.storedToken, 'good-token');
        expect(tokenService.storedUser, _student);
      },
    );

    test(
      'initialization falls back to logged out state when token restore throws',
      () async {
        final tokenService = _ThrowingTokenService(
          Exception('storage unavailable'),
        );
        final authService = _FakeAuthService(user: _student);
        final provider = AuthProvider(tokenService, authService: authService);

        await provider.initialize();

        expect(provider.isReady, isTrue);
        expect(provider.isAuthenticated, isFalse);
        expect(provider.token, isNull);
        expect(provider.user, isNull);
        expect(provider.lastError, isNotNull);
        expect(
          provider.lastError?.message,
          'Failed to restore your saved session.',
        );
        expect(tokenService.cleared, isTrue);
      },
    );

    test(
      'refreshAuthState clears session when synced token is unauthorized',
      () async {
        final tokenService = _FakeTokenService('stored-token', _student);
        final authService = _FakeAuthService(
          error: ApiException(
            message: 'Unauthenticated.',
            errorType: ApiErrorType.unauthorized,
          ),
        );
        final provider = AuthProvider(tokenService, authService: authService);

        await provider.initialize();
        await provider.refreshAuthState();

        expect(provider.isAuthenticated, isFalse);
        expect(provider.token, isNull);
        expect(provider.user, isNull);
        expect(tokenService.cleared, isTrue);
      },
    );

    test('logout clears local session even when server logout fails', () async {
      final tokenService = _FakeTokenService('stored-token', _student);
      final authService = _FakeAuthService(
        user: _student,
        logoutError: ApiException(
          message: 'Token already expired.',
          errorType: ApiErrorType.unauthorized,
        ),
      );
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.initialize();
      await provider.logout();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.token, isNull);
      expect(provider.user, isNull);
      expect(tokenService.cleared, isTrue);
    });

    test('dashboardRoute matches each supported role', () async {
      final adminProvider = AuthProvider(
        _FakeTokenService(),
        authService: _FakeAuthService(),
      );
      await adminProvider.setToken(
        'admin-token',
        user: const AppUser(
          id: 10,
          name: 'Admin',
          email: 'admin@test',
          role: 'Admin',
        ),
      );

      final supervisorProvider = AuthProvider(
        _FakeTokenService(),
        authService: _FakeAuthService(),
      );
      await supervisorProvider.setToken(
        'supervisor-token',
        user: const AppUser(
          id: 11,
          name: 'Supervisor',
          email: 'supervisor@test',
          role: 'Supervisor',
        ),
      );

      final adviserProvider = AuthProvider(
        _FakeTokenService(),
        authService: _FakeAuthService(),
      );
      await adviserProvider.setToken(
        'adviser-token',
        user: const AppUser(
          id: 12,
          name: 'Adviser',
          email: 'adviser@test',
          role: 'Adviser',
        ),
      );

      expect(adminProvider.dashboardRoute, AppRoutes.adminDashboard);
      expect(supervisorProvider.dashboardRoute, AppRoutes.supervisorDashboard);
      expect(adviserProvider.dashboardRoute, AppRoutes.adviserDashboard);
      expect(
        AuthProvider(
          _FakeTokenService(),
          authService: _FakeAuthService(),
        ).dashboardRoute,
        AppRoutes.studentDashboard,
      );
    });

    test('updateAvatarBytes clears avatar when bytes are empty', () async {
      final tokenService = _FakeTokenService('stored-token', _student);
      final authService = _FakeAuthService(
        user: _student,
        updateAvatarHandler: (_) async => const AppUser(
          id: 1,
          name: 'Student User',
          email: 'student@example.test',
          role: 'Student',
        ),
      );
      final provider = AuthProvider(tokenService, authService: authService);

      await provider.initialize();
      await provider.updateAvatarBytes(Uint8List(0));

      expect(provider.user?.avatarBase64, isNull);
      expect(tokenService.storedUser?.avatarBase64, isNull);
      expect(authService.lastAvatarBase64, isNull);
    });
  });
}

const _student = AppUser(
  id: 1,
  name: 'Student User',
  email: 'student@example.test',
  role: 'Student',
);

class _FakeTokenService extends TokenService {
  _FakeTokenService([this.storedToken, this.storedUser]) : super();

  String? storedToken;
  AppUser? storedUser;
  bool cleared = false;
  bool resetDebugSessionCalled = false;

  @override
  Future<void> saveToken(String token) async {
    storedToken = token;
    cleared = false;
  }

  @override
  Future<String?> getToken() async {
    return storedToken;
  }

  @override
  Future<void> saveUser(AppUser user) async {
    storedUser = user;
  }

  @override
  Future<AppUser?> getUser() async {
    return storedUser;
  }

  @override
  Future<void> clearToken() async {
    storedToken = null;
    cleared = true;
  }

  @override
  Future<void> clearUser() async {
    storedUser = null;
    cleared = true;
  }

  @override
  Future<void> clearSession() async {
    storedToken = null;
    storedUser = null;
    cleared = true;
  }

  @override
  Future<void> resetDebugBrowserSession() async {
    resetDebugSessionCalled = true;
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.user,
    this.error,
    this.logoutError,
    this.updateAvatarHandler,
  }) : super(ApiClient(dio: Dio()));

  final AppUser? user;
  final Object? error;
  final Object? logoutError;
  final Future<AppUser> Function(String? avatarBase64)? updateAvatarHandler;
  String? lastAvatarBase64;

  @override
  Future<AppUser> getAuthenticatedUser() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }

    return user!;
  }

  @override
  Future<void> logout() async {
    final logoutError = this.logoutError;
    if (logoutError != null) {
      throw logoutError;
    }
  }

  @override
  Future<AppUser> updateAvatarBase64(String? avatarBase64) async {
    lastAvatarBase64 = avatarBase64;
    final handler = updateAvatarHandler;
    if (handler != null) {
      return handler(avatarBase64);
    }

    return user!;
  }
}

class _ThrowingTokenService extends TokenService {
  _ThrowingTokenService(this.error) : super();

  final Object error;
  bool cleared = false;

  @override
  Future<String?> getToken() async {
    throw error;
  }

  @override
  Future<void> clearToken() async {
    cleared = true;
  }
}
