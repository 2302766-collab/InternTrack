import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/interceptors/auth_interceptor.dart';
import 'package:intern_track_app/core/services/token_service.dart';

void main() {
  group('AuthInterceptor', () {
    test('does not attach bearer token to login requests', () async {
      final interceptor = AuthInterceptor(_FakeTokenService('stale-token'));
      final options = RequestOptions(path: '/auth/login');

      await interceptor.onRequest(options, _NoopRequestInterceptorHandler());

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('attaches bearer token to protected requests', () async {
      final interceptor = AuthInterceptor(_FakeTokenService('fresh-token'));
      final options = RequestOptions(path: '/auth/me');

      await interceptor.onRequest(options, _NoopRequestInterceptorHandler());

      expect(options.headers['Authorization'], 'Bearer fresh-token');
    });
  });
}

class _FakeTokenService extends TokenService {
  _FakeTokenService(this._storedToken) : super();

  final String? _storedToken;

  @override
  Future<String?> getToken() async => _storedToken;
}

class _NoopRequestInterceptorHandler extends RequestInterceptorHandler {}
