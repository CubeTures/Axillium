class User {
  final int id;
  final String alias;

  User({required this.id, required this.alias});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      alias: json['alias'] as String,
    );
  }
}
