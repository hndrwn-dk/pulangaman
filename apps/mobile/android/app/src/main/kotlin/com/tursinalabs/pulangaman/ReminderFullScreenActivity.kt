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
import android.view.View
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
        val mood = moodFor(title, body)

        val root = FrameLayout(this).apply {
            setBackgroundColor(BG)
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
            setTextColor(0x99FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            letterSpacing = 0.08f
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_VERTICAL or Gravity.START,
            )
        }
        val close = TextView(this).apply {
            text = "\u00D7"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            contentDescription = "Tutup"
            setOnClickListener { finish() }
            layoutParams = FrameLayout.LayoutParams(dp(44), dp(44), Gravity.END)
        }
        topBar.addView(brand)
        topBar.addView(close)

        val titleView = TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            setPadding(0, dp(18), 0, dp(8))
            setLineSpacing(0f, 1.1f)
        }
        val bodyView = TextView(this).apply {
            text = body
            setTextColor(0xB3FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setLineSpacing(dp(2).toFloat(), 1.25f)
        }

        val hero = ReminderHeroView(this).apply {
            this.mood = mood
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
            setTextColor(0xFF18332D.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(0xFFFFC857.toInt())
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
            v.updatePadding(
                left = dp(24) + bars.left,
                top = dp(12) + bars.top,
                right = dp(24) + bars.right,
                bottom = dp(20) + bars.bottom,
            )
            insets
        }
        column.requestApplyInsets()
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
            listOf("tidur", "istirahat", "sleep", "bedtime", "malam").any { t.contains(it) } ->
                ReminderHeroView.Mood.SLEEP
            listOf("belajar", "study", "baca", "pekerjaan rumah", "pr ").any { t.contains(it) } ->
                ReminderHeroView.Mood.STUDY
            else -> ReminderHeroView.Mood.DEFAULT
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
        window.navigationBarColor = BG
    }

    companion object {
        const val ACTION_DISMISS = "com.tursinalabs.pulangaman.DISMISS_FULLSCREEN_ALERT"
        private const val BG = 0xFF0B2E28.toInt()
    }
}
