package com.tursinalabs.pulangaman

import android.content.Context

/**
 * Mirrors Flutter [VisualRefreshController] / dart-define so native fullscreen
 * reminder templates can respect the same flag when alarms fire.
 */
object VisualRefreshPrefs {
    private const val PREFS = "pulangaman_ui"
    private const val KEY = "visual_refresh"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY, enabled)
            .apply()
    }
}
