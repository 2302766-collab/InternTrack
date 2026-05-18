class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.gender,
    this.avatarBase64,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? gender;
  final String? avatarBase64;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      gender: json['gender']?.toString(),
      avatarBase64: (json['avatar_base64'] ?? json['avatarBase64'])?.toString(),
    );
  }

  AppUser copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? gender,
    String? avatarBase64,
    bool clearAvatar = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      avatarBase64: clearAvatar ? null : (avatarBase64 ?? this.avatarBase64),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'gender': gender,
      'avatar_base64': avatarBase64,
    };
  }
}
