import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/meeting.dart';

class MeetingService {
  Future<List<Meeting>> getMeetings(int groupId) async {
    final response = await http.get(
      Uri.parse('$apiBase/groups/$groupId/meetings'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null) return [];
      final list = decoded as List<dynamic>;
      return list
          .map((j) => Meeting.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load meetings (${response.statusCode})');
  }

  Future<Meeting> createMeeting({
    required int groupId,
    required int createdById,
    required String createdByAlias,
    required String createdByRole,
    required String title,
    required String location,
    required String note,
    required DateTime scheduledAt,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/groups/$groupId/meetings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'created_by_id': createdById,
        'created_by_alias': createdByAlias,
        'created_by_role': createdByRole,
        'title': title,
        'location': location,
        'note': note,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      }),
    );
    if (response.statusCode == 201) {
      return Meeting.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    final error =
        (jsonDecode(response.body) as Map<String, dynamic>)['error'] ??
            'Failed to create meeting';
    throw Exception(error);
  }

  Future<void> deleteMeeting({
    required int groupId,
    required int meetingId,
    required int userId,
    required String role,
  }) async {
    final response = await http.delete(
      Uri.parse(
          '$apiBase/groups/$groupId/meetings/$meetingId?user_id=$userId&role=$role'),
    );
    if (response.statusCode != 200) {
      final error =
          (jsonDecode(response.body) as Map<String, dynamic>)['error'] ??
              'Failed to cancel meeting';
      throw Exception(error);
    }
  }
}
