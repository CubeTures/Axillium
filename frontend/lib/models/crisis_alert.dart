class CrisisAlert {
  final int id;
  final int userId;
  final String userAlias;
  final int groupId;
  final int stage;
  final bool resolved;
  final int resolvedById;
  final String resolvedByAlias;
  final DateTime createdAt;

  CrisisAlert({
    required this.id,
    required this.userId,
    required this.userAlias,
    required this.groupId,
    required this.stage,
    required this.resolved,
    required this.resolvedById,
    required this.resolvedByAlias,
    required this.createdAt,
  });

  factory CrisisAlert.fromJson(Map<String, dynamic> json) {
    return CrisisAlert(
      id: json['ID'] as int,
      userId: json['user_id'] as int,
      userAlias: json['user_alias'] as String,
      groupId: json['group_id'] as int,
      stage: json['stage'] as int,
      resolved: json['resolved'] as bool? ?? false,
      resolvedById: json['resolved_by_id'] as int? ?? 0,
      resolvedByAlias: json['resolved_by_alias'] as String? ?? '',
      createdAt: DateTime.parse(json['CreatedAt'] as String).toLocal(),
    );
  }
}
