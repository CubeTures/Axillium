import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ChatService {
  // On Android emulator, the host machine is 10.0.2.2, not localhost.
  static const String _baseUrl = 'http://10.0.2.2:8080/api';

  Future<List<Message>> getMessages(int groupId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/messages?page=$page'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    }
    throw Exception('Failed to load messages (${response.statusCode})');
  }

  Future<Message> sendMessage(
    int groupId,
    int userId,
    String alias,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/groups/$groupId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'alias': alias,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to send message (${response.statusCode})');
  }
}
