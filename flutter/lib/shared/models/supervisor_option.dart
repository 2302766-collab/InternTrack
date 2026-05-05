class SupervisorOption {
  final int id;
  final String name;
  final String email;

  const SupervisorOption({
    required this.id,
    required this.name,
    required this.email,
  });

  String get displayLabel => email.isEmpty ? name : '$name ($email)';

  factory SupervisorOption.fromJson(Map<String, dynamic> json) {
    return SupervisorOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}
