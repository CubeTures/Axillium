package com.example.axillium

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val riskChannel = "com.example.axillium/risk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            riskChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Returns "active", "not_active", or "no_permission"
                "requestPermissions" -> {
                    requestRiskPermissions()
                    result.success(hasUsagePermission())
                }
                "testAlert" -> {
                    val userId = call.argument<String>("userId") ?: ""
                    val apiBase = call.argument<String>("apiBase") ?: ""
                    Thread {
                        val status = fireTestAlert(userId, apiBase)
                        runOnUiThread { result.success(status) }
                    }.start()
                }
                "kalshiStatus" -> result.success(kalshiStatus())
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "startMonitoring" -> {
                    val userId = call.argument<String>("userId") ?: ""
                    val apiBase = call.argument<String>("apiBase") ?: ""
                    // Store config for the accessibility service to read
                    getSharedPreferences(AppDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putString(AppDetectionService.KEY_USER_ID, userId)
                        .putString(AppDetectionService.KEY_API_BASE, apiBase)
                        .apply()
                    result.success(null)
                }
                "stopMonitoring" -> {
                    getSharedPreferences(AppDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .remove(AppDetectionService.KEY_USER_ID)
                        .remove(AppDetectionService.KEY_API_BASE)
                        .apply()
                    result.success(null)
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "getMonitoringStatus" -> {
                    val prefs = getSharedPreferences(AppDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                    val status = mapOf(
                        "accessibility_enabled" to isAccessibilityServiceEnabled(),
                        "service_connected" to (AppDetectionService.connected || prefs.getBoolean(AppDetectionService.KEY_SERVICE_CONNECTED, false)),
                        "user_id" to (prefs.getString(AppDetectionService.KEY_USER_ID, null) ?: ""),
                        "api_base" to (prefs.getString(AppDetectionService.KEY_API_BASE, null) ?: ""),
                        "last_package" to (prefs.getString(AppDetectionService.KEY_LAST_PACKAGE, null) ?: ""),
                        "last_event_ms" to prefs.getLong(AppDetectionService.KEY_LAST_EVENT_MS, 0),
                    )
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestRiskPermissions() {
        // POST_NOTIFICATIONS — runtime permission required on Android 13+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
            }
        }
    }

    // Returns a status string to report back to Flutter
    private fun fireTestAlert(userId: String, apiBase: String): String {
        val responseCode: Int
        val responseBody: String

        try {
            val url = java.net.URL("$apiBase/users/$userId/risk-alert")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.doOutput = true
            conn.outputStream.bufferedWriter().use { it.write("""{"risk_type":"gambling_app","detail":"Kalshi (test)"}""") }
            responseCode = conn.responseCode
            responseBody = try {
                (if (responseCode in 200..299) conn.inputStream else conn.errorStream)
                    ?.bufferedReader()?.readText() ?: ""
            } catch (_: Exception) { "" }
            conn.disconnect()
        } catch (e: Exception) {
            return "network_error: ${e.message}"
        }

        if (responseCode !in 200..299) {
            return "backend_error $responseCode: $responseBody"
        }

        // Parse the status field from the JSON response
        val status = Regex(""""status"\s*:\s*"([^"]+)"""").find(responseBody)?.groupValues?.get(1) ?: "ok"
        if (status == "no_sponsor") return "no_sponsor"

        // Success — show the system notification
        val nm = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        nm.createNotificationChannel(
            android.app.NotificationChannel(AppMonitorService.ALERT_CHANNEL_ID, "Risk alerts", android.app.NotificationManager.IMPORTANCE_HIGH)
        )
        runOnUiThread {
            val notif = android.app.Notification.Builder(this, AppMonitorService.ALERT_CHANNEL_ID)
                .setContentTitle("Test alert fired")
                .setContentText("Sponsor notified. Switch to Sophie to verify.")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setAutoCancel(true)
                .build()
            nm.notify(9999, notif)
        }
        return "notified"
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabled = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        return enabled.any { it.resolveInfo.serviceInfo.name == AppDetectionService::class.java.name }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun kalshiStatus(): String {
        if (!hasUsagePermission()) return "no_permission"

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val fiveMinutesAgo = now - 5 * 60 * 1000L

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            fiveMinutesAgo,
            now,
        )
        val kalshi = stats?.find { it.packageName == "com.kalshi.mobile" }
        return if (kalshi != null && kalshi.lastTimeUsed >= fiveMinutesAgo) "active" else "not_active"
    }
}
