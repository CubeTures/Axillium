class DirectMessage {
  final int id;
  final int senderId;
  final int recipientId;
  final String senderAlias;
  final String senderRole;
  final String content;
  final DateTime createdAt;
  final String? senderProfilePicture;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.senderAlias,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.senderProfilePicture,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final pic = json['sender_profile_picture'] as String?;
    return DirectMessage(
      id: json['ID'] as int,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      senderAlias: json['sender_alias'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
      senderProfilePicture: (pic != null && pic.isNotEmpty) ? pic : null,
    );
  }
}
