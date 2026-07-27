package com.tursinalabs.pulangaman

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding

/**
 * Full-screen reminder — YouTube-bedtime inspired structure:
 * copy at top, hero illustration in the middle, pill action near the bottom.
 *
 * When [VisualRefreshPrefs] is on, applies the moment palette (Fraunces-like
 * bold title, muted teal body, per-mood accent button / illustration).
 */
class ReminderFullScreenActivity : ComponentActivity() {
    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ContextCompat.registerReceiver(
            this,
            dismissReceiver,
            IntentFilter(ACTION_DISMISS),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        turnScreenOnAndUnlock()
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val title = intent.getStringExtra(ReminderReceiver.EXTRA_TITLE) ?: "Pengingat"
        val body = intent.getStringExtra(ReminderReceiver.EXTRA_BODY) ?: ""
        val visualRefresh = intent.getBooleanExtra(EXTRA_VISUAL_REFRESH, VisualRefreshPrefs.isEnabled(this))
        val mood = moodFor(title, body)
        val accent = accentFor(mood, visualRefresh)
        val bg = if (visualRefresh) BG_VR else BG_CLASSIC

        val root = FrameLayout(this).apply {
            setBackgroundColor(bg)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }

        val topBar = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        val brand = TextView(this).apply {
            text = "PULANGAMAN"
            setTextColor(if (visualRefresh) MUTED_TEAL else 0x99FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            letterSpacing = if (visualRefresh) 0.14f else 0.08f
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_VERTICAL or Gravity.START,
            )
        }
        val close = TextView(this).apply {
            text = "\u00D7"
            gravity = Gravity.CENTER
            setTextColor(if (visualRefresh) MUTED_TEAL else Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            contentDescription = "Tutup"
            setOnClickListener { finish() }
            layoutParams = FrameLayout.LayoutParams(dp(44), dp(44), Gravity.END)
        }
        topBar.addView(brand)
        topBar.addView(close)

        val titleView = TextView(this).apply {
            text = title
            setTextColor(if (visualRefresh) TITLE_CREAM else Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (visualRefresh) 32f else 30f)
            typeface = if (visualRefresh) {
                Typeface.create("serif", Typeface.BOLD)
            } else {
                Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            setPadding(0, dp(18), 0, dp(8))
            setLineSpacing(0f, 1.1f)
        }
        val bodyView = TextView(this).apply {
            text = body
            setTextColor(if (visualRefresh) MUTED_TEAL else 0xB3FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setLineSpacing(dp(2).toFloat(), 1.25f)
        }

        val hero = ReminderHeroView(this).apply {
            this.mood = mood
            this.visualRefresh = visualRefresh
            this.momentAccent = accent
            this.illustrationBg = ILLUSTRATION_BG
            this.canvasBg = bg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ).apply {
                topMargin = dp(12)
                bottomMargin = dp(12)
            }
        }

        val button = TextView(this).apply {
            text = "Mengerti"
            gravity = Gravity.CENTER
            setTextColor(ON_ACCENT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(accent)
            }
            isClickable = true
            isFocusable = true
            setOnClickListener { finish() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(54),
            )
        }

        column.addView(topBar)
        column.addView(titleView)
        column.addView(bodyView)
        column.addView(hero)
        column.addView(button)
        root.addView(column)
        setContentView(root)

        ViewCompat.setOnApplyWindowInsetsListener(column) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            // Extra bottom inset so the CTA sits in the thumb zone, not flush
            // against the system gesture / nav bar (was dp(20)).
            v.updatePadding(
                left = dp(24) + bars.left,
                top = dp(12) + bars.top,
                right = dp(24) + bars.right,
                bottom = dp(48) + bars.bottom,
            )
            insets
        }
        column.requestApplyInsets()
        window.navigationBarColor = bg
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(dismissReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun moodFor(title: String, body: String): ReminderHeroView.Mood {
        val t = "$title $body".lowercase()
        return when {
            listOf(
                "titik kumpul",
                "emergency meeting",
                "kumpul darurat",
                "meeting point",
            ).any { t.contains(it) } -> ReminderHeroView.Mood.EMP
            listOf("tidur", "istirahat", "sleep", "bedtime", "malam").any { t.contains(it) } ->
                ReminderHeroView.Mood.SLEEP
            listOf("belajar", "study", "baca", "pekerjaan rumah", "pr ").any { t.contains(it) } ->
                ReminderHeroView.Mood.STUDY
            else -> ReminderHeroView.Mood.DEFAULT
        }
    }

    private fun accentFor(mood: ReminderHeroView.Mood, visualRefresh: Boolean): Int {
        if (!visualRefresh) return 0xFFFFC857.toInt()
        return when (mood) {
            ReminderHeroView.Mood.SLEEP -> ACCENT_SLEEP
            ReminderHeroView.Mood.STUDY -> ACCENT_STUDY
            ReminderHeroView.Mood.EMP -> ACCENT_EMP
            ReminderHeroView.Mood.DEFAULT -> ACCENT_CUSTOM
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun turnScreenOnAndUnlock() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguard.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.TRANSPARENT
    }

    companion object {
        const val ACTION_DISMISS = "com.tursinalabs.pulangaman.DISMISS_FULLSCREEN_ALERT"
        const val EXTRA_VISUAL_REFRESH = "visual_refresh"
        private const val BG_CLASSIC = 0xFF0B2E28.toInt()
        private const val BG_VR = 0xFF16362C.toInt()
        private const val ILLUSTRATION_BG = 0xFF2C4C41.toInt()
        private const val TITLE_CREAM = 0xFFFAF7F0.toInt()
        private const val MUTED_TEAL = 0xFFB9CFC5.toInt()
        private const val ON_ACCENT = 0xFF16362C.toInt()
        private const val ACCENT_SLEEP = 0xFFE8B94D.toInt()
        private const val ACCENT_STUDY = 0xFF4A9F6C.toInt()
        private const val ACCENT_CUSTOM = 0xFF7C9A8B.toInt()
        private const val ACCENT_EMP = 0xFFD6875C.toInt()
    }
}
