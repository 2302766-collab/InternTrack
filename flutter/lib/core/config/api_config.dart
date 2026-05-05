import 'package:flutter/foundation.dart';

/// API host selection with sane defaults and override support.
///
/// - Prefer `API_BASE_URL` via `--dart-define` when running on a real device
///   (e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.0.5:8000/api/v1`).
/// - Falls back to emulator/localhost addresses for dev.
class ApiConfig {
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    final configuredBaseUrl = normalizeBaseUrl(_envBaseUrl);
    if (configuredBaseUrl.isNotEmpty) return configuredBaseUrl;

    if (kIsWeb) return 'http://localhost:8000/api/v1';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator loopback to host machine
        return 'http://10.0.2.2:8000/api/v1';
      default:
        // iOS simulator/desktop
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  @visibleForTesting
  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final withoutTrailingSlash = trimmed.replaceFirst(RegExp(r'/+$'), '');
    if (withoutTrailingSlash.endsWith('/api/v1')) {
      return withoutTrailingSlash;
    }

    return '$withoutTrailingSlash/api/v1';
  }
}
