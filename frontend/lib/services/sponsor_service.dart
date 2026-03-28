import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/group_member.dart';

class SponsorService {
  static const String _baseUrl = 'http://10.0.2.2:8080/api';

  Future<List<GroupMember>> getAvailableSponsors(int groupId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/sponsors'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => GroupMember.fromJson(j)).toList();
    }
    throw Exception('Failed to load sponsors');
  }

  Future<void> requestSponsor(int userId, int sponsorId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/sponsor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sponsor_id': sponsorId}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to request sponsor';
      throw Exception(error);
    }
  }
}
