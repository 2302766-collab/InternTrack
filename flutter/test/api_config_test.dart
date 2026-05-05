import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/config/api_config.dart';

void main() {
  group('ApiConfig.normalizeBaseUrl', () {
    test('keeps an api v1 URL unchanged', () {
      expect(
        ApiConfig.normalizeBaseUrl('http://127.0.0.1:8000/api/v1'),
        'http://127.0.0.1:8000/api/v1',
      );
    });

    test('removes trailing slashes from api v1 URL', () {
      expect(
        ApiConfig.normalizeBaseUrl('http://127.0.0.1:8000/api/v1///'),
        'http://127.0.0.1:8000/api/v1',
      );
    });

    test('adds api v1 prefix to app root URL', () {
      expect(
        ApiConfig.normalizeBaseUrl('http://127.0.0.1:8000'),
        'http://127.0.0.1:8000/api/v1',
      );
    });

    test('trims whitespace and leaves empty values empty', () {
      expect(ApiConfig.normalizeBaseUrl('   '), '');
      expect(
        ApiConfig.normalizeBaseUrl('  http://localhost:8000/api/v1  '),
        'http://localhost:8000/api/v1',
      );
    });
  });
}
