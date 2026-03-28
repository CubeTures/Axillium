class Message {
  final int id;
  final int groupId;
  final int userId;
  final String alias;
  final String senderRole;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.alias,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['ID'] as int,
      groupId: json['group_id'] as int,
      userId: json['user_id'] as int,
      alias: json['alias'] as String,
      senderRole: json['sender_role'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }
}
