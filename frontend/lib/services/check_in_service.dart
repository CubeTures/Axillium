import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/check_in.dart';
import '../models/user_stats.dart';

class CheckInService {
  static const String _baseUrl = apiBase;

  Future<CheckIn> submit({
    required int userId,
    required int moodScore,
    required bool relapsed,
    required String reflection,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/check-ins'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'mood_score': moodScore,
        'relapsed': relapsed,
        'reflection': reflection,
      }),
    );
    if (response.statusCode == 201) {
      return CheckIn.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body)['error'] ?? 'Failed to submit check-in';
    throw Exception(error);
  }

  /// Returns today's check-in if one exists, or null if not yet checked in.
  Future<CheckIn?> getTodayCheckIn(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/check-ins/$userId/today'),
    );
    if (response.statusCode == 200) {
      return CheckIn.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to query today\'s check-in');
  }

  Future<List<CheckIn>> getHistory(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/check-ins/$userId'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => CheckIn.fromJson(j)).toList();
    }
    throw Exception('Failed to load check-in history');
  }

  Future<UserStats> getStats(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/check-ins/$userId/stats'),
    );
    if (response.statusCode == 200) {
      return UserStats.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load stats');
  }
}
