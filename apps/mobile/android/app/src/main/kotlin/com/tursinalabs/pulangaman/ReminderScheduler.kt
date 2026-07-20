package com.tursinalabs.pulangaman

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object ReminderScheduler {
    private const val TAG = "ReminderScheduler"
    private const val PREFS = "family_reminders"
    private const val KEY_JSON = "reminders_json"
    private const val MAX_ALARM_IDS = 200

    fun saveAndSchedule(context: Context, remindersJson: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_JSON, remindersJson)
            .apply()
        cancelAll(context)
        scheduleAll(context)
    }

    fun rescheduleFromPrefs(context: Context) {
        cancelAll(context)
        scheduleAll(context)
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val base = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
        }
        for (requestCode in 1..MAX_ALARM_IDS) {
            val pending = PendingIntent.getBroadcast(
                context,
                requestCode,
                base,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pending != null) {
                alarmManager.cancel(pending)
                pending.cancel()
            }
        }
    }

    private fun scheduleAll(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_JSON, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (error: Exception) {
            Log.e(TAG, "invalid reminders json", error)
            return
        }

        var requestCode = 1
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (!item.optBoolean("enabled", true)) continue
            val days = item.optJSONArray("daysOfWeek") ?: JSONArray("[1,2,3,4,5,6,7]")
            val hour = item.optInt("hour", 0)
            val minute = item.optInt("minute", 0)
            val title = item.optString("title", "Pengingat")
            val body = item.optString("body", "")
            val style = item.optString("style", "fullscreen")
            val id = item.optString("id", "reminder-$i")

            for (d in 0 until days.length()) {
                if (requestCode > MAX_ALARM_IDS) return
                val dayOfWeekIso = days.optInt(d)
                val triggerAt = nextTriggerMillis(hour, minute, dayOfWeekIso)
                scheduleOne(
                    context = context,
                    requestCode = requestCode,
                    triggerAt = triggerAt,
                    id = id,
                    title = title,
                    body = body,
                    style = style,
                    hour = hour,
                    minute = minute,
                    dayOfWeekIso = dayOfWeekIso,
                )
                requestCode += 1
            }
        }
    }

    private fun scheduleOne(
        context: Context,
        requestCode: Int,
        triggerAt: Long,
        id: String,
        title: String,
        body: String,
        style: String,
        hour: Int,
        minute: Int,
        dayOfWeekIso: Int,
    ) {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
            putExtra(ReminderReceiver.EXTRA_ID, id)
            putExtra(ReminderReceiver.EXTRA_TITLE, title)
            putExtra(ReminderReceiver.EXTRA_BODY, body)
            putExtra(ReminderReceiver.EXTRA_STYLE, style)
            putExtra(ReminderReceiver.EXTRA_HOUR, hour)
            putExtra(ReminderReceiver.EXTRA_MINUTE, minute)
            putExtra(ReminderReceiver.EXTRA_DAY, dayOfWeekIso)
            putExtra(ReminderReceiver.EXTRA_REQUEST_CODE, requestCode)
        }
        val pending = pendingIntent(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val showIntent = Intent(context, ReminderFullScreenActivity::class.java).apply {
                    putExtra(ReminderReceiver.EXTRA_TITLE, title)
                    putExtra(ReminderReceiver.EXTRA_BODY, body)
                    putExtra(ReminderReceiver.EXTRA_STYLE, style)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val showPending = PendingIntent.getActivity(
                    context,
                    requestCode + 10_000,
                    showIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerAt, showPending),
                    pending,
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        } catch (error: SecurityException) {
            Log.e(TAG, "exact alarm not permitted", error)
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pending)
        }
    }

    /** ISO day 1=Mon..7=Sun → Calendar DAY_OF_WEEK */
    private fun isoToCalendarDow(iso: Int): Int {
        return when (iso) {
            1 -> Calendar.MONDAY
            2 -> Calendar.TUESDAY
            3 -> Calendar.WEDNESDAY
            4 -> Calendar.THURSDAY
            5 -> Calendar.FRIDAY
            6 -> Calendar.SATURDAY
            else -> Calendar.SUNDAY
        }
    }

    private fun nextTriggerMillis(hour: Int, minute: Int, dayOfWeekIso: Int): Long {
        val targetDow = isoToCalendarDow(dayOfWeekIso)
        val now = Calendar.getInstance()
        val cal = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.DAY_OF_WEEK, targetDow)
        }
        if (cal.timeInMillis <= now.timeInMillis) {
            cal.add(Calendar.WEEK_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    private fun pendingIntent(
        context: Context,
        requestCode: Int,
        intent: Intent,
        flag: Int,
    ): PendingIntent? {
        val flags = flag or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
