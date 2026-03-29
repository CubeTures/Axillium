package com.example.axillium

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
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
                "kalshiStatus" -> result.success(kalshiStatus())
                // Opens the Usage Access settings screen so the user can grant permission
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
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
        val kalshi = stats?.find { it.packageName == "com.kalshi.android" }
        return if (kalshi != null && kalshi.lastTimeUsed >= fiveMinutesAgo) "active" else "not_active"
    }
}
