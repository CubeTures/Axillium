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

  /// Returns "active", "not_active", or "no_permission".
  Future<String> _kalshiStatus() async {
    try {
      return await _channel.invokeMethod<String>('kalshiStatus') ?? 'not_active';
    } on PlatformException {
      return 'not_active';
    }
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } on PlatformException {
      // ignore — device may not support it
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
  /// found. Returns the triggered risk type, "needs_permission" if Usage Access
  /// hasn't been granted yet, or null if nothing fired.
  Future<String?> runDetection(int userId, String addictionType) async {
    switch (addictionType.toLowerCase()) {
      case 'gambling':
        if (await _inCooldown('gambling_app')) return null;
        final status = await _kalshiStatus();
        if (status == 'no_permission') return 'needs_usage_permission';
        if (status == 'active') {
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

  /// Requests POST_NOTIFICATIONS (Android 13+) and opens Usage Access settings
  /// if not yet granted. Returns true if usage access is already granted.
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Debug: fires the full alert path (backend POST + system notification).
  /// Returns the backend status: "notified", "no_sponsor", "network_error:...", etc.
  Future<String> testAlert(int userId, String apiBase) async {
    try {
      final status = await _channel.invokeMethod<String>('testAlert', {
        'userId': userId.toString(),
        'apiBase': apiBase,
      });
      return status ?? 'unknown';
    } on PlatformException catch (e) {
      return 'platform_error: ${e.message}';
    }
  }

  /// Starts the Android background service that polls for Kalshi every 10 s.
  /// Should be called once after login for gambling-addiction users with a sponsor.
  Future<void> startBackgroundMonitoring(int userId, String apiBase) async {
    try {
      await _channel.invokeMethod('startMonitoring', {
        'userId': userId.toString(),
        'apiBase': apiBase,
      });
    } on PlatformException {
      // not on Android or service unavailable
    }
  }

  /// Stops the background monitoring service.
  Future<void> stopBackgroundMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } on PlatformException {
      // ignore
    }
  }

  /// Opens the Android Usage Access settings screen so the user can grant the
  /// permission needed to detect foreground app usage.
  Future<void> requestUsagePermission() => _openUsageAccessSettings();

  /// Returns true if the accessibility service is enabled.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android Accessibility Settings so the user can enable the service.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {
      // ignore
    }
  }

  /// Returns a map of monitoring status for debugging/display.
  /// Keys: accessibility_enabled, service_connected, user_id, api_base,
  ///       last_package, last_event_ms
  Future<Map<String, dynamic>> getMonitoringStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getMonitoringStatus');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException {
      // not on Android
    }
    return {};
  }
}
