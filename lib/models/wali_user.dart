class WaliUser {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool mustChangePassword;

  WaliUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    required this.mustChangePassword,
  });

  factory WaliUser.fromJson(Map<String, dynamic> json) {
    return WaliUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }
}
