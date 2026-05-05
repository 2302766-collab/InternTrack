class AdviserInfo {
  final int? id;
  final String? name;
  final String? email;

  const AdviserInfo({
    required this.id,
    required this.name,
    required this.email,
  });

  factory AdviserInfo.fromJson(Map<String, dynamic> json) {
    return AdviserInfo(
      id: (json['id'] as num?)?.toInt(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }

  @override
  String toString() => 'AdviserInfo(id: $id, name: $name, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdviserInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}
