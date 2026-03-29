class AppNotification {
  final int id;
  final String type;
  final String message;
  final int senderId;
  final String senderAlias;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.senderId,
    required this.senderAlias,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      message: json['message'] as String,
      senderId: json['sender_id'] as int,
      senderAlias: json['sender_alias'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
