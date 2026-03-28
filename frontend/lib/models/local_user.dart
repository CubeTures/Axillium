class LocalUser {
  final String alias;
  final String rank;
  final int? userId;
  final int? groupId;

  const LocalUser({
    required this.alias,
    required this.rank,
    this.userId,
    this.groupId,
  });

  bool get isRegistered => userId != null;

  LocalUser copyWith({String? alias, String? rank, int? userId, int? groupId}) {
    return LocalUser(
      alias: alias ?? this.alias,
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
    );
  }
}
