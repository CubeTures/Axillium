class Group {
  final int id;
  final String name;
  final String addictionType;
  final String location;
  final int leaderId;

  Group({
    required this.id,
    required this.name,
    required this.addictionType,
    required this.location,
    required this.leaderId,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['ID'] as int,
      name: json['name'] as String,
      addictionType: json['addiction_type'] as String,
      location: json['location'] as String,
      leaderId: json['leader_id'] as int,
    );
  }
}
