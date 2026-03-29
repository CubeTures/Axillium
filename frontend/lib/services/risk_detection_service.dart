import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class RiskDetectionService {
  static const _channel = MethodChannel('com.example.axillium/risk');
  static const _cooldownHours = 1;

  // ── Platform checks ────────────────────────────────────────────────────────

  Future<bool> _isKalshiInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isKalshiInstalled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _isNearBar() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));

      // Overpass API — free, no key needed
      final query =
          '[out:json][timeout:5];'
          'node["amenity"~"bar|pub|nightclub"]'
          '(around:100,${position.latitude},${position.longitude});'
          'out count;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter')
          .replace(queryParameters: {'data': query});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        return elements.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  // ── Cooldown ───────────────────────────────────────────────────────────────

  Future<bool> _inCooldown(String riskType) async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('risk_alert_last_$riskType') ?? 0;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last).inHours < _cooldownHours;
  }

  Future<void> _markSent(String riskType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'risk_alert_last_$riskType', DateTime.now().millisecondsSinceEpoch);
  }

  // ── Backend notification ───────────────────────────────────────────────────

  Future<void> _notifyBackend(
      int userId, String riskType, String detail) async {
    try {
      await http
          .post(
            Uri.parse('$apiBase/users/$userId/risk-alert'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'risk_type': riskType, 'detail': detail}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── Entry point ────────────────────────────────────────────────────────────

  /// Runs detection for [addictionType] and notifies the backend if a risk is
  /// found. Returns the triggered risk type string, or null if nothing fired.
  Future<String?> runDetection(int userId, String addictionType) async {
    switch (addictionType.toLowerCase()) {
      case 'gambling':
        if (await _inCooldown('gambling_app')) return null;
        if (await _isKalshiInstalled()) {
          await _notifyBackend(userId, 'gambling_app', 'Kalshi');
          await _markSent('gambling_app');
          return 'gambling_app';
        }
      case 'alcohol':
        if (await _inCooldown('bar_location')) return null;
        if (await _isNearBar()) {
          await _notifyBackend(userId, 'bar_location', 'near a bar or pub');
          await _markSent('bar_location');
          return 'bar_location';
        }
    }
    return null;
  }
}
