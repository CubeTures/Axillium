class DirectMessage {
  final int id;
  final int senderId;
  final int recipientId;
  final String senderAlias;
  final String senderRole;
  final String content;
  final DateTime createdAt;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.senderAlias,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['ID'] as int,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      senderAlias: json['sender_alias'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }
}
