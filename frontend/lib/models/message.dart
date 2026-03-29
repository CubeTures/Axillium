class Message {
  final int id;
  final int groupId;
  final int userId;
  final String alias;
  final String senderRole;
  final String content;
  final DateTime createdAt;
  final String? senderProfilePicture;

  Message({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.alias,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.senderProfilePicture,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final pic = json['sender_profile_picture'] as String?;
    return Message(
      id: json['ID'] as int,
      groupId: json['group_id'] as int,
      userId: json['user_id'] as int,
      alias: json['alias'] as String,
      senderRole: json['sender_role'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
      senderProfilePicture: (pic != null && pic.isNotEmpty) ? pic : null,
    );
  }
}
