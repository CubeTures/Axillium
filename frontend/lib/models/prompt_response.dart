class PromptResponse {
  final int id;
  final int promptId;
  final int userId;
  final String userAlias;
  final String userRole;
  final String content;
  final DateTime createdAt;

  PromptResponse({
    required this.id,
    required this.promptId,
    required this.userId,
    required this.userAlias,
    required this.userRole,
    required this.content,
    required this.createdAt,
  });

  factory PromptResponse.fromJson(Map<String, dynamic> json) {
    return PromptResponse(
      id: json['ID'] as int,
      promptId: (json['prompt_id'] as int?) ?? 0,
      userId: (json['user_id'] as int?) ?? 0,
      userAlias: (json['user_alias'] as String?) ?? '',
      userRole: (json['user_role'] as String?) ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }
}
