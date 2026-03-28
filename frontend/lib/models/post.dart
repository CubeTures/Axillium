class Post {
  final int id;
  final int authorId;
  final String authorAlias;
  final String addictionType;
  final String title;
  final String content;
  final String status;
  final bool featured;
  final String featuredWeek;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorAlias,
    required this.addictionType,
    required this.title,
    required this.content,
    required this.status,
    required this.featured,
    required this.featuredWeek,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['ID'],
      authorId: json['author_id'] ?? 0,
      authorAlias: json['author_alias'] ?? '',
      addictionType: json['addiction_type'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      status: json['status'] ?? '',
      featured: json['featured'] ?? false,
      featuredWeek: json['featured_week'] ?? '',
      createdAt: DateTime.parse(json['CreatedAt']),
    );
  }

  bool isFeaturedThisWeek() => featured && featuredWeek == _currentISOWeek();
}

String _currentISOWeek() {
  final now = DateTime.now();
  // Find Monday of current week
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfYear = DateTime(monday.year, 1, 1);
  final dayOfYear = monday.difference(startOfYear).inDays;
  final week = (dayOfYear / 7).floor() + 1;
  return '${monday.year}-W${week.toString().padLeft(2, '0')}';
}
