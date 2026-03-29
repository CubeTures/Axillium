import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/direct_message.dart';

class DmService {
  static const String _base = apiBase;

  Future<List<DirectMessage>> getDMs(int userA, int userB) async {
    final uri = Uri.parse('$_base/dm')
        .replace(queryParameters: {'user_a': '$userA', 'user_b': '$userB'});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => DirectMessage.fromJson(e)).toList();
    }
    throw Exception('Failed to load messages (${response.statusCode})');
  }

  Future<DirectMessage> sendDM({
    required int senderId,
    required int recipientId,
    required String senderAlias,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/dm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'recipient_id': recipientId,
        'sender_alias': senderAlias,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return DirectMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to send message (${response.statusCode})');
  }
}
