class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}
