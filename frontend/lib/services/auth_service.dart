import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static const String _baseUrl = apiBase;

  Future<User> register(String phoneNumber, String password, String alias, {int groupId = 0}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'password': password,
        'alias': alias,
        'group_id': groupId,
      }),
    );
    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body)['error'] ?? 'Registration failed';
    throw Exception(error);
  }

  Future<void> uploadProfilePicture(int userId, String base64DataUrl) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/profile-picture'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_data': base64DataUrl}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Upload failed';
      throw Exception(error);
    }
  }

  Future<User> login(String phoneNumber, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body)['error'] ?? 'Login failed';
    throw Exception(error);
  }
}
