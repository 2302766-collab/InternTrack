import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
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

<<<<<<< HEAD
    test('initialization falls back to logged out state when token restore throws', () async {
      final tokenService = _ThrowingTokenService(Exception('storage unavailable'));
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
    });
=======
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
>>>>>>> 6fbbe9d (Login issue)
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
  _FakeAuthService({this.user, this.error}) : super(ApiClient(dio: Dio()));

  final AppUser? user;
  final Object? error;

  @override
  Future<AppUser> getAuthenticatedUser() async {
    final error = this.error;
    if (error != null) {
      throw error;
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
