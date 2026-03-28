class LocalUser {
  final String alias;
  final String rank;
  final int? userId;

  const LocalUser({
    required this.alias,
    required this.rank,
    this.userId,
  });

  bool get isRegistered => userId != null;

  LocalUser copyWith({String? alias, String? rank, int? userId}) {
    return LocalUser(
      alias: alias ?? this.alias,
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
    );
  }
}
