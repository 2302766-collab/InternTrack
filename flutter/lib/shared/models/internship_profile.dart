class InternshipProfile {
  final int id;
  final int studentId;
  final String companyName;
  final String companyAddress;
  final int requiredHours;
  final String startDate;
  final String endDate;
  final int? supervisorId;
  final int? adviserId;
  final String? supervisorName;
  final String? supervisorEmail;

  InternshipProfile({
    required this.id,
    required this.studentId,
    required this.companyName,
    required this.companyAddress,
    required this.requiredHours,
    required this.startDate,
    required this.endDate,
    this.supervisorId,
    this.adviserId,
    this.supervisorName,
    this.supervisorEmail,
  });

  factory InternshipProfile.fromJson(Map<String, dynamic> json) {
    return InternshipProfile(
      id: _parseInt(json['id']),
      studentId: _parseInt(json['student_id']),
      companyName: json['company_name']?.toString() ?? '',
      companyAddress: json['company_address']?.toString() ?? '',
      requiredHours: _parseInt(json['required_hours']),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      supervisorId: _parseNullableInt(json['supervisor_id']),
      adviserId: _parseNullableInt(json['adviser_id']),
      supervisorName: json['supervisor_name']?.toString(),
      supervisorEmail: json['supervisor_email']?.toString(),
    );
  }

  static int _parseInt(Object? value) => _parseNullableInt(value) ?? 0;

  static int? _parseNullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
