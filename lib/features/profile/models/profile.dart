class Profile {
  final String name;
  final String email;
  final String phone;
  final String username;

  Profile({
    required this.name,
    required this.email,
    required this.phone,
    required this.username,
  });

  Profile copyWith({
    String? name,
    String? email,
    String? phone,
    String? username,
  }) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
    );
  }
}
