package id.pulangaman.pulangaman

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import android.view.accessibility.AccessibilityManager
import android.app.usage.UsageStatsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channelName = "id.pulangaman/screen_time"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "getTodayUsage" -> result.success(getTodayUsage())
                    "applyPolicy" -> {
                        savePolicy(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                        result.success(null)
                    }
                    "startEnforcement" -> {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, ScreenTimeForegroundService::class.java),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = "$packageName/${AppBlockAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }

    private fun getTodayUsage(): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val now = System.currentTimeMillis()
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        return manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            now,
        ).filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "durationSeconds" to it.totalTimeInForeground / 1000,
                )
            }
    }

    private fun savePolicy(policy: Map<*, *>) {
        val preferences = getSharedPreferences("screen_time_policy", Context.MODE_PRIVATE)
        val blocked = policy["blocked_packages"] as? List<*> ?: emptyList<Any>()
        val allowlist = policy["emergency_allowlist"] as? List<*> ?: emptyList<Any>()
        preferences.edit()
            .putBoolean("enabled", policy["enabled"] == true)
            .putInt("dailyLimitMinutes", (policy["daily_limit_minutes"] as? Number)?.toInt() ?: 120)
            .putString("blockedPackages", JSONArray(blocked).toString())
            .putString("emergencyAllowlist", JSONArray(allowlist).toString())
            .apply()
    }
}
