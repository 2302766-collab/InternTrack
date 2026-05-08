import 'dart:math' as math;

class InternListItem {
  final int id;
  final int studentId;
  final String studentName;
  final String companyName;
  final int requiredHours;
  final int completedHours;
  final int totalLogs;
  final int pendingLogs;
  final int approvedLogs;
  final int rejectedLogs;
  final int? supervisorId;
  final int? adviserId;
  final String? startDate;
  final String? endDate;
  final String? lastLogDate;
  final String alertStatus;
  final String alertMessage;
  final String alertSeverity;
  final Map<String, dynamic> alertMeta;

  InternListItem({
    required this.id,
    this.studentId = 0,
    required this.studentName,
    required this.companyName,
    required this.requiredHours,
    this.completedHours = 0,
    this.totalLogs = 0,
    this.pendingLogs = 0,
    this.approvedLogs = 0,
    this.rejectedLogs = 0,
    this.supervisorId,
    this.adviserId,
    this.startDate,
    this.endDate,
    this.lastLogDate,
    this.alertStatus = 'ON_TRACK',
    this.alertMessage = 'Progress is aligned with the internship timeline.',
    this.alertSeverity = 'success',
    this.alertMeta = const <String, dynamic>{},
  });

  bool get hasActiveAlert => alertStatus.toUpperCase() != 'ON_TRACK';

  double get progressFraction {
    if (requiredHours <= 0) {
      return 0;
    }

    return (completedHours / requiredHours).clamp(0, 1).toDouble();
  }

  int get progressPercentage => (progressFraction * 100).round();

  int get remainingHours => math.max(0, requiredHours - completedHours);

  factory InternListItem.fromJson(Map<String, dynamic> json) {
    final alert = json['alert'] is Map
        ? Map<String, dynamic>.from(json['alert'] as Map)
        : const <String, dynamic>{};
    final alertMeta = alert['meta'] is Map
        ? Map<String, dynamic>.from(alert['meta'] as Map)
        : const <String, dynamic>{};

    return InternListItem(
      id: _parseInt(json['id']),
      studentId: _parseInt(json['student_id']),
      studentName: json['student_name']?.toString() ?? 'Unknown Student',
      companyName: json['company_name']?.toString() ?? 'Unknown Company',
      requiredHours: _parseInt(json['required_hours']),
      completedHours: _parseInt(json['completed_hours']),
      totalLogs: _parseInt(json['total_logs']),
      pendingLogs: _parseInt(json['pending_logs']),
      approvedLogs: _parseInt(json['approved_logs']),
      rejectedLogs: _parseInt(json['rejected_logs']),
      supervisorId: _parseNullableInt(json['supervisor_id']),
      adviserId: _parseNullableInt(json['adviser_id']),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      lastLogDate: json['last_log_date']?.toString(),
      alertStatus: (json['alert_status'] ?? alert['status'] ?? 'ON_TRACK')
          .toString(),
      alertMessage:
          (json['alert_message'] ??
                  alert['message'] ??
                  'Progress is aligned with the internship timeline.')
              .toString(),
      alertSeverity: (json['alert_severity'] ?? alert['severity'] ?? 'success')
          .toString(),
      alertMeta: alertMeta,
    );
  }

  static int _parseInt(Object? value) => _parseNullableInt(value) ?? 0;

  static int? _parseNullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
