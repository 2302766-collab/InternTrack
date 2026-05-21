import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/models/daily_time_record.dart';

void main() {
  group('DailyTimeRecord', () {
    test('parses numeric fields from strings', () {
      final record = DailyTimeRecord.fromJson({
        'id': '11',
        'date': '2026-04-20',
        'status': 'WORKING',
        'current_state_label': 'Working',
        'next_action': 'lunch-out',
        'time_in_at': '2026-04-20T08:00:00Z',
        'first_work_minutes': '120',
        'second_work_minutes': '180',
        'total_work_minutes': '300',
      });

      expect(record.id, 11);
      expect(record.firstWorkMinutes, 120);
      expect(record.secondWorkMinutes, 180);
      expect(record.totalWorkMinutes, 300);
      expect(record.timeInAt, isNotNull);
    });

    test('uses safe defaults for missing numeric fields', () {
      final record = DailyTimeRecord.fromJson({});

      expect(record.id, isNull);
      expect(record.date, '');
      expect(record.status, 'NOT_STARTED');
      expect(record.currentStateLabel, 'Not Started');
      expect(record.firstWorkMinutes, 0);
      expect(record.secondWorkMinutes, 0);
      expect(record.totalWorkMinutes, 0);
    });

    test('preserves the server next action for afternoon-only sessions', () {
      final record = DailyTimeRecord.fromJson({
        'status': 'WORKING',
        'next_action': 'LUNCH_OUT',
        'time_in_at': '2026-04-20T13:00:00',
      });

      expect(record.isAfternoonOnlySession, isTrue);
      expect(record.resolvedNextAction(DateTime(2026, 4, 20, 13)), 'LUNCH_OUT');
    });
  });
}
