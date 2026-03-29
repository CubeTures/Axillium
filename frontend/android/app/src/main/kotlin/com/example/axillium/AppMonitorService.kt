package com.example.axillium

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class AppMonitorService : Service() {

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var scheduledTask: ScheduledFuture<*>? = null
    private var lastAlertedMs = 0L
    private val cooldownMs = 60 * 60 * 1000L // 1 hour between alerts

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val userId = intent?.getStringExtra("userId") ?: return START_NOT_STICKY
        val apiBase = intent.getStringExtra("apiBase") ?: return START_NOT_STICKY

        createNotificationChannels()
        startForeground(SERVICE_NOTIF_ID, buildServiceNotification())

        scheduledTask?.cancel(false)
        scheduledTask = executor.scheduleWithFixedDelay(
            { checkKalshi(userId, apiBase) },
            0L, 10L, TimeUnit.SECONDS
        )

        return START_STICKY
    }

    override fun onDestroy() {
        scheduledTask?.cancel(false)
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Detection ────────────────────────────────────────────────────────────

    private fun checkKalshi(userId: String, apiBase: String) {
        if (!hasUsagePermission()) return

        val now = System.currentTimeMillis()
        if (now - lastAlertedMs < cooldownMs) return

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val windowStart = now - 60 * 1000L // check last 60 seconds
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, windowStart, now)
        val kalshi = stats?.find { it.packageName == KALSHI_PACKAGE }

        if (kalshi != null && kalshi.lastTimeUsed >= windowStart) {
            lastAlertedMs = now
            postRiskAlert(userId, apiBase)
            showAlertNotification()
        }
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

    // ── Backend ───────────────────────────────────────────────────────────────

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
            conn.responseCode // execute request
            conn.disconnect()
        } catch (_: Exception) { /* best-effort */ }
    }

    // ── Notifications ─────────────────────────────────────────────────────────

    private fun createNotificationChannels() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Background monitor",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { setShowBadge(false) }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Risk alerts",
                NotificationManager.IMPORTANCE_HIGH,
            )
        )
    }

    private fun buildServiceNotification(): Notification =
        Notification.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("Axillium")
            .setContentText("Monitoring for risk triggers")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()

    private fun showAlertNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notif = Notification.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle("We noticed you opened Kalshi")
            .setContentText("Your sponsor has been notified. You've got this.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
        nm.notify(ALERT_NOTIF_ID, notif)
    }

    companion object {
        private const val KALSHI_PACKAGE = "com.kalshi.mobile"
        private const val SERVICE_NOTIF_ID = 1001
        private const val ALERT_NOTIF_ID = 1002
        const val SERVICE_CHANNEL_ID = "axillium_monitor"
        const val ALERT_CHANNEL_ID = "axillium_risk_alert"
        const val ACTION_TEST_ALERT = "com.example.axillium.TEST_ALERT"
    }

    // Called via ACTION_TEST_ALERT intent for debug testing
    fun fireTestAlert(userId: String, apiBase: String) {
        createNotificationChannels()
        postRiskAlert(userId, apiBase)
        showAlertNotification()
    }
}
