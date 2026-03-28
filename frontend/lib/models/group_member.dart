class GroupMember {
  final int id;
  final String alias;
  final String role;

  GroupMember({required this.id, required this.alias, required this.role});

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as int,
      alias: json['alias'] as String,
      role: json['role'] as String? ?? 'apprentice',
    );
  }
}
