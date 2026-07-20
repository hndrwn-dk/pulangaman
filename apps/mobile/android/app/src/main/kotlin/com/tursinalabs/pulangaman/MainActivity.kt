package com.tursinalabs.pulangaman

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import android.app.usage.UsageStatsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val screenTimeChannel = "com.tursinalabs.pulangaman/screen_time"
    private val locationChannel = "com.tursinalabs.pulangaman/location_tracking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenTimeChannel)
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
                    "getTodayUsage" -> result.success(getUsageStats("today"))
                    "getUsageStats" -> {
                        val period = call.argument<String>("period") ?: "today"
                        result.success(getUsageStats(period))
                    }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLocationTracking" -> {
                        val token = call.argument<String>("token") ?: ""
                        val apiBaseUrl = call.argument<String>("apiBaseUrl") ?: ""
                        val panic = call.argument<Boolean>("panic") ?: false
                        if (token.isBlank() || apiBaseUrl.isBlank()) {
                            result.error("invalid_args", "token and apiBaseUrl required", null)
                            return@setMethodCallHandler
                        }
                        LocationTrackingService.saveConfig(this, token, apiBaseUrl, panic)
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, LocationTrackingService::class.java),
                        )
                        result.success(true)
                    }
                    "updateLocationTracking" -> {
                        val token = call.argument<String>("token")
                        val apiBaseUrl = call.argument<String>("apiBaseUrl")
                        val panic = call.argument<Boolean>("panic") ?: false
                        val prefs = getSharedPreferences(
                            LocationTrackingService.PREFS_NAME,
                            MODE_PRIVATE,
                        )
                        val resolvedToken =
                            token ?: prefs.getString(LocationTrackingService.KEY_TOKEN, "") ?: ""
                        val resolvedBase = apiBaseUrl
                            ?: prefs.getString(LocationTrackingService.KEY_API_BASE, "")
                            ?: ""
                        LocationTrackingService.saveConfig(
                            this,
                            resolvedToken,
                            resolvedBase,
                            panic,
                        )
                        val intent = Intent(this, LocationTrackingService::class.java).apply {
                            action = LocationTrackingService.ACTION_UPDATE_CONFIG
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }
                    "stopLocationTracking" -> {
                        val intent = Intent(this, LocationTrackingService::class.java).apply {
                            action = LocationTrackingService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "isLocationTrackingRunning" -> {
                        result.success(isServiceRunning(LocationTrackingService::class.java))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
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

    private fun getUsageStats(period: String): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val now = System.currentTimeMillis()
        val calendar = java.util.Calendar.getInstance()
        when (period.lowercase()) {
            "week" -> {
                calendar.set(java.util.Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
            }
            "month" -> {
                calendar.set(java.util.Calendar.DAY_OF_MONTH, 1)
            }
            else -> {
                calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            }
        }
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        if (period.lowercase() == "today") {
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        }

        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            now,
        )

        val launcherPackages = launcherPackageNames()
        val totals = linkedMapOf<String, Long>()
        for (entry in stats) {
            if (entry.totalTimeInForeground <= 0) continue
            if (!isUserFacingApp(entry.packageName, launcherPackages)) continue
            totals[entry.packageName] =
                (totals[entry.packageName] ?: 0L) + entry.totalTimeInForeground
        }

        return totals.entries
            .sortedByDescending { it.value }
            .map { (pkg, millis) ->
                mapOf(
                    "packageName" to pkg,
                    "appLabel" to appLabel(pkg),
                    "durationSeconds" to millis / 1000,
                )
            }
    }

    private fun launcherPackageNames(): Set<String> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return packageManager.queryIntentActivities(home, 0)
            .mapNotNull { it.activityInfo?.packageName }
            .toSet()
    }

    private fun isUserFacingApp(packageName: String, launchers: Set<String>): Boolean {
        if (packageName in systemPackageDenylist) return false
        if (packageName in launchers) return false
        if (packageName == this.packageName) return true
        // Only apps the user can open from the app drawer.
        if (packageManager.getLaunchIntentForPackage(packageName) == null) return false
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            val isSystem = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystem =
                (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            // Keep user-installed apps and common preinstalled consumer apps.
            !isSystem || isUpdatedSystem || isKnownConsumerApp(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun isKnownConsumerApp(packageName: String): Boolean {
        return packageName.startsWith("com.android.chrome") ||
            packageName.startsWith("com.google.android.gm") ||
            packageName.startsWith("com.google.android.youtube") ||
            packageName.startsWith("com.google.android.apps.maps") ||
            packageName.startsWith("com.google.android.apps.photos") ||
            packageName.startsWith("com.google.android.apps.messaging") ||
            packageName.startsWith("com.google.android.dialer") ||
            packageName.startsWith("com.google.android.contacts") ||
            packageName.startsWith("com.android.vending") ||
            packageName.startsWith("com.spotify.") ||
            packageName.startsWith("com.instagram.") ||
            packageName.startsWith("com.whatsapp") ||
            packageName.startsWith("com.zhiliaoapp.musically") ||
            packageName.startsWith("com.ss.android.ugc.trill")
    }

    private fun appLabel(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName.substringAfterLast('.')
        }
    }

    companion object {
        private val systemPackageDenylist = setOf(
            "com.android.systemui",
            "com.android.settings",
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.providers.downloads",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.google.android.permissioncontroller",
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.inputmethod.latin",
            "com.android.inputmethod.latin",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.google.android.apps.wallpaper",
            "android",
        )
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
