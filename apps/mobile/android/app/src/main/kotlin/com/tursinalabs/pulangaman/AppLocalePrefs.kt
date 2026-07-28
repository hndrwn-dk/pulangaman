package com.tursinalabs.pulangaman

import android.content.Context

/**
 * Flutter [LocaleController] language for native reminder UI chrome
 * (CTA label, etc.). Defaults to Indonesian to match app default.
 */
object AppLocalePrefs {
    private const val PREFS = "pulangaman_ui"
    private const val KEY = "app_language"

    fun languageCode(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, "id") ?: "id"

    fun setLanguageCode(context: Context, languageCode: String) {
        val code = if (languageCode == "en") "en" else "id"
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, code)
            .apply()
    }

    fun isEnglish(context: Context): Boolean = languageCode(context) == "en"
}
