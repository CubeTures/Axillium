import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/crisis_alert.dart';

class CrisisService {
  Future<CrisisAlert> trigger({
    required int userId,
    required String userAlias,
    required int groupId,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/crisis'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'user_alias': userAlias,
        'group_id': groupId,
      }),
    );
    // 201 = created, 409 = already active (return existing alert)
    if (response.statusCode == 201 || response.statusCode == 409) {
      return CrisisAlert.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    final error =
        (jsonDecode(response.body) as Map<String, dynamic>)['error'] ??
            'Failed to trigger alert';
    throw Exception(error);
  }

  Future<void> escalate(int alertId, int userId) async {
    await http.post(
      Uri.parse('$apiBase/crisis/$alertId/escalate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }

  Future<void> cancel(int alertId, int userId) async {
    await http.post(
      Uri.parse('$apiBase/crisis/$alertId/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }

  Future<void> respond({
    required int crisisUserId,
    required int responderId,
    required String responderAlias,
  }) async {
    await http.post(
      Uri.parse('$apiBase/crisis/respond'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'crisis_user_id': crisisUserId,
        'responder_id': responderId,
        'responder_alias': responderAlias,
      }),
    );
  }

  Future<CrisisAlert?> getActive(int userId) async {
    final response = await http.get(
      Uri.parse('$apiBase/crisis/active?user_id=$userId'),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['alert'] == null) return null;
      return CrisisAlert.fromJson(body['alert'] as Map<String, dynamic>);
    }
    return null;
  }
}
