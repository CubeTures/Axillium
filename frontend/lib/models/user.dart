class User {
  final int id;
  final String alias;
  final int groupId;
  final String role;
  final int sponsorId;
  final String? addictionType;
  final String? profilePicture;

  User({
    required this.id,
    required this.alias,
    required this.groupId,
    required this.role,
    required this.sponsorId,
    this.addictionType,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final pic = json['profile_picture'] as String?;
    return User(
      id: json['id'] as int,
      alias: json['alias'] as String,
      groupId: json['group_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'apprentice',
      sponsorId: json['sponsor_id'] as int? ?? 0,
      addictionType: json['addiction_type'] as String?,
      profilePicture: (pic != null && pic.isNotEmpty) ? pic : null,
    );
  }
}
