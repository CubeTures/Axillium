package com.example.axillium

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class AppDetectionService : AccessibilityService() {

    private val executor = Executors.newSingleThreadExecutor()
    private var lastAlertedMs = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 300
        }
        connected = true
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SERVICE_CONNECTED, true)
            .apply()
    }

    override fun onDestroy() {
        connected = false
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SERVICE_CONNECTED, false)
            .apply()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // Write every foreground switch for debugging
        Log.d(TAG, "Window changed: $pkg (class=${event.className})")
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_PACKAGE, pkg)
            .putLong(KEY_LAST_EVENT_MS, System.currentTimeMillis())
            .apply()

        if (pkg != KALSHI_PACKAGE) return

        Log.d(TAG, "Kalshi detected!")
        val now = System.currentTimeMillis()
        if (now - lastAlertedMs < COOLDOWN_MS) {
            Log.d(TAG, "Still in cooldown, skipping")
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val userId = prefs.getString(KEY_USER_ID, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
        if (userId == null || apiBase == null) {
            Log.w(TAG, "No userId/apiBase in prefs, cannot alert (userId=$userId, apiBase=$apiBase)")
            return
        }

        lastAlertedMs = now
        Log.d(TAG, "Firing risk alert for user $userId")
        executor.execute {
            postRiskAlert(userId, apiBase)
            showAlertNotification()
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
    }

    private fun postRiskAlert(userId: String, apiBase: String) {
        try {
            val url = URL("$apiBase/users/$userId/risk-alert")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.doOutput = true
            val body = """{"risk_type":"gambling_app","detail":"Kalshi"}"""
            conn.outputStream.bufferedWriter().use { it.write(body) }
            val code = conn.responseCode
            Log.d(TAG, "Risk alert POST response: $code")
            conn.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Risk alert POST failed", e)
        }
    }

    private fun showAlertNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Risk alerts",
                NotificationManager.IMPORTANCE_HIGH,
            )
        )
        val notif = Notification.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle("We noticed you opened Kalshi")
            .setContentText("Your sponsor has been notified. You've got this.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
        nm.notify(ALERT_NOTIF_ID, notif)
    }

    companion object {
        private const val TAG = "AppDetectionService"
        private const val KALSHI_PACKAGE = "com.kalshi.mobile"
        private const val COOLDOWN_MS = 60 * 60 * 1000L // 1 hour
        private const val ALERT_CHANNEL_ID = "axillium_risk_alert"
        private const val ALERT_NOTIF_ID = 1002
        const val PREFS_NAME = "axillium_monitor"
        const val KEY_USER_ID = "monitor_user_id"
        const val KEY_API_BASE = "monitor_api_base"
        const val KEY_SERVICE_CONNECTED = "service_connected"
        const val KEY_LAST_PACKAGE = "last_package"
        const val KEY_LAST_EVENT_MS = "last_event_ms"

        @Volatile
        var connected = false
            private set
    }
}
