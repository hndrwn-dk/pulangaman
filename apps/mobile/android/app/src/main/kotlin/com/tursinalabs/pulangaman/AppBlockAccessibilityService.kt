package com.tursinalabs.pulangaman

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class AppBlockAccessibilityService : AccessibilityService() {
    private val alwaysAllowed = setOf(
        "com.tursinalabs.pulangaman",
        "com.android.dialer",
        "com.google.android.dialer",
        "com.android.messaging",
        "com.google.android.apps.messaging",
        "com.android.settings",
        "com.android.systemui",
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val foregroundPackage = event.packageName?.toString() ?: return
        val preferences = getSharedPreferences("screen_time_policy", Context.MODE_PRIVATE)
        if (!preferences.getBoolean("enabled", false)) return

        val blocked = jsonSet(preferences.getString("blockedPackages", "[]"))
        val emergency = jsonSet(preferences.getString("emergencyAllowlist", "[]"))
        if (foregroundPackage in alwaysAllowed || foregroundPackage in emergency) return
        if (foregroundPackage !in blocked) return

        performGlobalAction(GLOBAL_ACTION_HOME)
        startActivity(
            Intent(this, BlockedActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("blockedPackage", foregroundPackage)
            },
        )
    }

    override fun onInterrupt() = Unit

    private fun jsonSet(raw: String?): Set<String> {
        val array = JSONArray(raw ?: "[]")
        return buildSet {
            for (index in 0 until array.length()) add(array.optString(index))
        }
    }
}
