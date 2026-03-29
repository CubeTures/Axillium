import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/group_member.dart';

class SponsorRequest {
  final int notifId;
  final int senderId;
  final String alias;
  final String message;

  SponsorRequest({
    required this.notifId,
    required this.senderId,
    required this.alias,
    required this.message,
  });

  factory SponsorRequest.fromJson(Map<String, dynamic> json) {
    return SponsorRequest(
      notifId: json['notif_id'] as int,
      senderId: json['sender_id'] as int,
      alias: json['alias'] as String,
      message: json['message'] as String,
    );
  }
}

class SponsorService {
  static const String _baseUrl = apiBase;

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

  Future<List<SponsorRequest>> getPendingRequests(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId/sponsor-requests'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => SponsorRequest.fromJson(j)).toList();
    }
    throw Exception('Failed to load sponsor requests');
  }

  Future<void> acceptRequest(int userId, int notifId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/sponsor-requests/$notifId/accept'),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to accept request';
      throw Exception(error);
    }
  }

  Future<void> declineRequest(int userId, int notifId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/sponsor-requests/$notifId/decline'),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to decline request';
      throw Exception(error);
    }
  }

  Future<List<GroupMember>> getApprentices(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId/apprentices'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => GroupMember.fromJson(j)).toList();
    }
    throw Exception('Failed to load apprentices');
  }

  /// Returns the pending outgoing request, or null if none.
  Future<({int notifId, int sponsorId, String sponsorAlias})?> getOutgoingRequest(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId/outgoing-sponsor-request'),
    );
    if (response.statusCode == 200) {
      final j = jsonDecode(response.body);
      return (
        notifId: j['notif_id'] as int,
        sponsorId: j['sponsor_id'] as int,
        sponsorAlias: j['sponsor_alias'] as String,
      );
    }
    if (response.statusCode == 404) return null;
    throw Exception('Failed to load outgoing request');
  }

  Future<void> cancelRequest(int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$userId/outgoing-sponsor-request'),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to cancel request';
      throw Exception(error);
    }
  }

  Future<void> removeConfirmedSponsor(int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$userId/sponsor'),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to remove sponsor';
      throw Exception(error);
    }
  }

  Future<void> removeApprentice(int sponsorId, int apprenticeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$sponsorId/apprentices/$apprenticeId'),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to remove apprentice';
      throw Exception(error);
    }
  }

  Future<GroupMember?> getUserBasic(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId'),
    );
    if (response.statusCode == 200) {
      return GroupMember.fromJson(jsonDecode(response.body));
    }
    return null;
  }
}
