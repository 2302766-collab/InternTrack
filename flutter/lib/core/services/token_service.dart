import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../../shared/models/app_user.dart';

import 'token_service_browser.dart'
    if (dart.library.html) 'token_service_browser_web.dart'
    as browser_storage;

class TokenService {
  TokenService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static String? _cachedToken;
  static AppUser? _cachedUser;
  static bool _hasLoadedToken = false;
  static bool _hasLoadedUser = false;

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _hasLoadedToken = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.saveValue(_tokenKey, token);
      return;
    }

    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    if (_hasLoadedToken) {
      return _cachedToken;
    }

    final token = browser_storage.usesBrowserStorage
        ? await browser_storage.readValue(_tokenKey)
        : await _storage.read(key: _tokenKey);

    _cachedToken = token;
    _hasLoadedToken = true;
    return token;
  }

  Future<void> saveUser(AppUser user) async {
    final encodedUser = jsonEncode(user.toJson());
    _cachedUser = user;
    _hasLoadedUser = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.saveValue(_userKey, encodedUser);
      return;
    }

    await _storage.write(key: _userKey, value: encodedUser);
  }

  Future<AppUser?> getUser() async {
    if (_hasLoadedUser) {
      return _cachedUser;
    }

    final encodedUser = browser_storage.usesBrowserStorage
        ? await browser_storage.readValue(_userKey)
        : await _storage.read(key: _userKey);

    if (encodedUser == null || encodedUser.isEmpty) {
      _cachedUser = null;
      _hasLoadedUser = true;
      return null;
    }

    try {
      final decoded = jsonDecode(encodedUser);
      if (decoded is Map<String, dynamic>) {
        _cachedUser = AppUser.fromJson(decoded);
      } else {
        _cachedUser = null;
      }
    } catch (_) {
      _cachedUser = null;
    }

    _hasLoadedUser = true;
    return _cachedUser;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _hasLoadedToken = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.clearValue(_tokenKey);
      return;
    }

    await _storage.delete(key: _tokenKey);
  }

  Future<void> clearUser() async {
    _cachedUser = null;
    _hasLoadedUser = true;

    if (browser_storage.usesBrowserStorage) {
      await browser_storage.clearValue(_userKey);
      return;
    }

    await _storage.delete(key: _userKey);
  }

  Future<void> clearSession() async {
    await clearToken();
    await clearUser();
  }
}
