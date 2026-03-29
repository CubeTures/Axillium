class Meeting {
  final int id;
  final int groupId;
  final String title;
  final String location;
  final String note;
  final DateTime scheduledAt;
  final int createdById;
  final String createdByAlias;
  final String createdByRole;
  final DateTime createdAt;

  Meeting({
    required this.id,
    required this.groupId,
    required this.title,
    required this.location,
    required this.note,
    required this.scheduledAt,
    required this.createdById,
    required this.createdByAlias,
    required this.createdByRole,
    required this.createdAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['ID'] as int,
      groupId: (json['group_id'] as int?) ?? 0,
      title: json['title'] as String,
      location: json['location'] as String,
      note: (json['note'] as String?) ?? '',
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      createdById: (json['created_by_id'] as int?) ?? 0,
      createdByAlias: (json['created_by_alias'] as String?) ?? '',
      createdByRole: (json['created_by_role'] as String?) ?? '',
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }
}
