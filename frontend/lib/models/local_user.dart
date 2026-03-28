class LocalUser {
  final String alias;
  final String rank;
  final int? userId;
  final String? location;
  final String? addictionType;
  final int? groupId;
  final bool isLeader;

  const LocalUser({
    required this.alias,
    required this.rank,
    this.userId,
    this.location,
    this.addictionType,
    this.groupId,
    this.isLeader = false,
  });

  bool get isRegistered => userId != null;

  LocalUser copyWith({
    String? alias,
    String? rank,
    int? userId,
    String? location,
    String? addictionType,
    int? groupId,
    bool? isLeader,
  }) {
    return LocalUser(
      alias: alias ?? this.alias,
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      location: location ?? this.location,
      addictionType: addictionType ?? this.addictionType,
      groupId: groupId ?? this.groupId,
      isLeader: isLeader ?? this.isLeader,
    );
  }
}
