class WeeklyPrompt {
  final int id;
  final String isoWeek;
  final String promptText;
  final int setById;
  final String setByAlias;
  final String setByRole;
  final DateTime createdAt;

  WeeklyPrompt({
    required this.id,
    required this.isoWeek,
    required this.promptText,
    required this.setById,
    required this.setByAlias,
    required this.setByRole,
    required this.createdAt,
  });

  factory WeeklyPrompt.fromJson(Map<String, dynamic> json) {
    return WeeklyPrompt(
      id: json['ID'] as int,
      isoWeek: json['iso_week'] as String,
      promptText: json['prompt_text'] as String,
      setById: (json['set_by_id'] as int?) ?? 0,
      setByAlias: (json['set_by_alias'] as String?) ?? '',
      setByRole: (json['set_by_role'] as String?) ?? '',
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }
}
