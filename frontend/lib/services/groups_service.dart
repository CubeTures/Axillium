import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/group.dart';

class GroupsService {
  static const String _baseUrl = apiBase;

  Future<List<Group>> getGroupsByLocation(String location) async {
    final uri = Uri.parse('$_baseUrl/groups')
        .replace(queryParameters: {'location': location});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Group.fromJson(json)).toList();
    }
    throw Exception('Failed to load groups (${response.statusCode})');
  }

  Future<Group> createGroup(String addictionType, String location, int leaderId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'addiction_type': addictionType,
        'location': location,
        'leader_id': leaderId,
      }),
    );
    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create group (${response.statusCode})');
  }
}
