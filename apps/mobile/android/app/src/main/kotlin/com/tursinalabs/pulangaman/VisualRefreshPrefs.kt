package com.tursinalabs.pulangaman

import android.content.Context

/**
 * Native Visual Refresh flag for fullscreen reminder templates.
 * Defaults on — Flutter always syncs true via [MainActivity] setVisualRefresh.
 */
object VisualRefreshPrefs {
    private const val PREFS = "pulangaman_ui"
    private const val KEY = "visual_refresh"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY, enabled)
            .apply()
    }
}
