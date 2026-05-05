import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/features/logbook/presentation/log_date_policy.dart';

void main() {
  group('LogDatePolicy', () {
    test('allows today and yesterday', () {
      final today = LogDatePolicy.today();
      final yesterday = today.subtract(const Duration(days: 1));

      expect(LogDatePolicy.validate(LogDatePolicy.formatForApi(today)), isNull);
      expect(
        LogDatePolicy.validate(LogDatePolicy.formatForApi(yesterday)),
        isNull,
      );
    });

    test('rejects dates older than yesterday', () {
      final olderDate = LogDatePolicy.today().subtract(const Duration(days: 2));

      expect(
        LogDatePolicy.validate(LogDatePolicy.formatForApi(olderDate)),
        LogDatePolicy.rangeError,
      );
    });

    test('rejects future dates', () {
      final futureDate = LogDatePolicy.today().add(const Duration(days: 1));

      expect(
        LogDatePolicy.validate(LogDatePolicy.formatForApi(futureDate)),
        LogDatePolicy.futureError,
      );
    });
  });
}
