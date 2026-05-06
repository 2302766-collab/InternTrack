import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_service_browser.dart'
    if (dart.library.html) 'token_service_browser_web.dart' as browser_storage;

class TokenService {
  const TokenService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static String? _cachedToken;
  static bool _hasLoadedToken = false;

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _hasLoadedToken = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.saveToken(_tokenKey, token);
      return;
    }

    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    if (_hasLoadedToken) {
      return _cachedToken;
    }

    final token = browser_storage.usesBrowserStorage
        ? await browser_storage.readToken(_tokenKey)
        : await _storage.read(key: _tokenKey);

    _cachedToken = token;
    _hasLoadedToken = true;
    return token;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _hasLoadedToken = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.clearToken(_tokenKey);
      return;
    }

    await _storage.delete(key: _tokenKey);
  }
}
