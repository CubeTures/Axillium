class CheckIn {
  final int id;
  final int userId;
  final int moodScore;
  final bool relapsed;
  final String reflection;
  final DateTime createdAt;

  CheckIn({
    required this.id,
    required this.userId,
    required this.moodScore,
    required this.relapsed,
    required this.reflection,
    required this.createdAt,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['ID'] as int,
      userId: json['user_id'] as int,
      moodScore: json['mood_score'] as int,
      relapsed: json['relapsed'] as bool,
      reflection: json['reflection'] as String? ?? '',
      createdAt: DateTime.parse(json['CreatedAt'] as String),
    );
  }

  static const moodLabels = {
    1: 'Very hard',
    2: 'Hard',
    3: 'Okay',
    4: 'Good',
    5: 'Great',
  };

  static const moodEmojis = {
    1: '😔',
    2: '😕',
    3: '😐',
    4: '🙂',
    5: '😊',
  };

  String get moodLabel => moodLabels[moodScore] ?? '$moodScore';
  String get moodEmoji => moodEmojis[moodScore] ?? '';
}
