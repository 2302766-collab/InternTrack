import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  const TokenService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
