import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_notification.dart';

class NotificationService {
  static const String _base = apiBase;

  Future<List<AppNotification>> getNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('$_base/users/$userId/notifications'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => AppNotification.fromJson(e)).toList();
    }
    throw Exception('Failed to load notifications');
  }

  Future<void> markRead(int userId, int notifId) async {
    await http.post(
      Uri.parse('$_base/users/$userId/notifications/$notifId/read'),
    );
  }
}
