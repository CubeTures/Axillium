import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/weekly_prompt.dart';
import '../models/prompt_response.dart';

class WeeklyPromptService {
  // Returns null if no prompt is set for the current week.
  Future<WeeklyPrompt?> getCurrentPrompt() async {
    final response = await http.get(Uri.parse('$apiBase/weekly-prompt'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['prompt'] == null) return null;
      return WeeklyPrompt.fromJson(body['prompt'] as Map<String, dynamic>);
    }
    throw Exception('Failed to load prompt (${response.statusCode})');
  }

  Future<WeeklyPrompt> setCurrentPrompt({
    required int userId,
    required String userAlias,
    required String userRole,
    required String promptText,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/weekly-prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'user_alias': userAlias,
        'user_role': userRole,
        'prompt_text': promptText,
      }),
    );
    if (response.statusCode == 201) {
      return WeeklyPrompt.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    final error =
        (jsonDecode(response.body) as Map<String, dynamic>)['error'] ??
            'Failed to set prompt';
    throw Exception(error);
  }

  Future<List<String>> getSuggestions(String role) async {
    final response = await http.get(
      Uri.parse('$apiBase/weekly-prompt/suggestions?role=$role'),
    );
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load suggestions (${response.statusCode})');
  }

  Future<List<PromptResponse>> getResponses({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiBase/weekly-prompt/responses?page=$page'),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((j) => PromptResponse.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load responses (${response.statusCode})');
  }

  Future<PromptResponse> postResponse({
    required int userId,
    required String userAlias,
    required String userRole,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/weekly-prompt/responses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'user_alias': userAlias,
        'user_role': userRole,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return PromptResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    final error =
        (jsonDecode(response.body) as Map<String, dynamic>)['error'] ??
            'Failed to post response';
    throw Exception(error);
  }
}
