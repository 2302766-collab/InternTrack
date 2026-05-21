class DailyTimeRecord {
  final int? id;
  final String date;
  final String status;
  final String currentStateLabel;
  final String? nextAction;
  final DateTime? timeInAt;
  final DateTime? lunchOutAt;
  final DateTime? lunchInAt;
  final DateTime? timeOutAt;
  final int firstWorkMinutes;
  final int secondWorkMinutes;
  final int totalWorkMinutes;

  const DailyTimeRecord({
    required this.id,
    required this.date,
    required this.status,
    required this.currentStateLabel,
    required this.nextAction,
    required this.timeInAt,
    required this.lunchOutAt,
    required this.lunchInAt,
    required this.timeOutAt,
    required this.firstWorkMinutes,
    required this.secondWorkMinutes,
    required this.totalWorkMinutes,
  });

  factory DailyTimeRecord.fromJson(Map<String, dynamic> json) {
    return DailyTimeRecord(
      id: _parseNullableInt(json['id']),
      date: (json['date'] ?? '').toString(),
      status: (json['status'] ?? 'NOT_STARTED').toString(),
      currentStateLabel: (json['current_state_label'] ?? 'Not Started')
          .toString(),
      nextAction: json['next_action']?.toString(),
      timeInAt: _parseDateTime(json['time_in_at']),
      lunchOutAt: _parseDateTime(json['lunch_out_at']),
      lunchInAt: _parseDateTime(json['lunch_in_at']),
      timeOutAt: _parseDateTime(json['time_out_at']),
      firstWorkMinutes: _parseInt(json['first_work_minutes']),
      secondWorkMinutes: _parseInt(json['second_work_minutes']),
      totalWorkMinutes: _parseInt(json['total_work_minutes']),
    );
  }

  static int _parseInt(Object? value) => _parseNullableInt(value) ?? 0;

  static int? _parseNullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }

  bool get isAfternoonOnlySession =>
      timeInAt != null &&
      lunchOutAt == null &&
      lunchInAt == null &&
      timeOutAt == null &&
      !_isMorningPunch(timeInAt);

  String? resolvedNextAction(DateTime now) {
    return nextAction;
  }

  static bool _isMorningPunch(DateTime? value) {
    if (value == null) return false;
    final normalized = value.toLocal();
    return normalized.hour < 12;
  }
}
