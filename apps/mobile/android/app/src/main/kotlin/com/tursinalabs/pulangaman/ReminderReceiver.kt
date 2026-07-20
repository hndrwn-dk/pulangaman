package com.tursinalabs.pulangaman

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            ReminderScheduler.rescheduleFromPrefs(context)
            return
        }
        if (intent?.action != ACTION_FIRE) return

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Pengingat"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val style = intent.getStringExtra(EXTRA_STYLE) ?: "fullscreen"
        val id = intent.getStringExtra(EXTRA_ID) ?: title

        if (ReminderScheduler.wasFiredToday(context, id) &&
            intent.getBooleanExtra(EXTRA_CATCH_UP, false)
        ) {
            return
        }
        ReminderScheduler.markFiredToday(context, id)

        ensureChannel(context)

        val fullIntent = Intent(context, ReminderFullScreenActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_STYLE, style)
        }

        // Always post a heads-up notification (reliable even if activity is blocked).
        showNotification(context, title, body, fullIntent)

        if (style != "notification") {
            // startActivity from background can fail on some OEMs; try anyway.
            try {
                context.startActivity(fullIntent)
            } catch (error: Exception) {
                Log.w(TAG, "fullscreen start failed", error)
            }
            // Retry once shortly after (helps when app was killed).
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    context.startActivity(fullIntent)
                } catch (_: Exception) {
                }
            }, 1200)
        }

        ReminderScheduler.rescheduleFromPrefs(context)
    }

    private fun showNotification(
        context: Context,
        title: String,
        body: String,
        fullIntent: Intent,
    ) {
        val contentPending = PendingIntent.getActivity(
            context,
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            fullIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .setFullScreenIntent(contentPending, true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(
                (title + body).hashCode() and 0x7fffffff,
                notification,
            )
        } catch (_: SecurityException) {
            Log.w(TAG, "notification permission denied")
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Pengingat keluarga",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Belajar, tidur, dan pesan terjadwal dari orang tua"
                setBypassDnd(true)
                enableVibration(true)
            },
        )
    }

    companion object {
        private const val TAG = "ReminderReceiver"
        const val ACTION_FIRE = "com.tursinalabs.pulangaman.REMINDER_FIRE"
        const val EXTRA_ID = "reminder_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_STYLE = "style"
        const val EXTRA_REQUEST_CODE = "request_code"
        const val EXTRA_CATCH_UP = "catch_up"
        private const val CHANNEL_ID = "family_reminders"
    }
}
