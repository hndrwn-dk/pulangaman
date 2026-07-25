package com.tursinalabs.pulangaman

import android.app.KeyguardManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.core.view.setPadding

class ReminderFullScreenActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        turnScreenOnAndUnlock()

        val title = intent.getStringExtra(ReminderReceiver.EXTRA_TITLE) ?: "Pengingat"
        val body = intent.getStringExtra(ReminderReceiver.EXTRA_BODY) ?: ""

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF07584E.toInt())
            setPadding(dp(24))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT,
            )
        }

        val eyebrow = TextView(this).apply {
            text = "PULANGAMAN"
            textSize = 13f
            setTextColor(0xCCFFFFFF.toInt())
            setPadding(0, 0, 0, dp(8))
        }
        val titleView = TextView(this).apply {
            text = title
            textSize = 32f
            setTextColor(0xFFFFFFFF.toInt())
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, 0, 0, dp(12))
        }
        val bodyView = TextView(this).apply {
            text = body
            textSize = 19f
            setTextColor(0xF2FFFFFF.toInt())
        }
        val button = Button(this).apply {
            text = "Mengerti"
            textSize = 18f
            setBackgroundColor(0xFFFFC857.toInt())
            setTextColor(0xFF18332D.toInt())
            setOnClickListener { finish() }
        }

        // Text block sits optically centered; the action stays within thumb reach.
        root.addView(spacer(weight = 1f))
        root.addView(eyebrow)
        root.addView(titleView)
        root.addView(bodyView)
        root.addView(spacer(weight = 1.2f))
        root.addView(
            button,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(56),
            ),
        )
        setContentView(root)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun spacer(weight: Float): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            weight,
        )
    }

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
    }
}
