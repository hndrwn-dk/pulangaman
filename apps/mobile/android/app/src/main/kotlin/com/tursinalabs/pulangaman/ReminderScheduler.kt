package com.tursinalabs.pulangaman

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.util.Calendar

object ReminderScheduler {
    private const val TAG = "ReminderScheduler"
    private const val PREFS = "family_reminders"
    private const val KEY_JSON = "reminders_json"
    private const val KEY_FIRED = "fired_dates"
    private const val MAX_ALARM_IDS = 80
    /** If sync happens shortly after the scheduled minute, still show once. */
    private const val CATCH_UP_WINDOW_MS = 45L * 60L * 1000L

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

    fun markFiredToday(context: Context, reminderId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = dayKey()
        val map = JSONArray(prefs.getString(KEY_FIRED, "[]") ?: "[]")
        val next = JSONArray()
        for (i in 0 until map.length()) {
            val row = map.optJSONObject(i) ?: continue
            if (row.optString("day") == today && row.optString("id") == reminderId) {
                continue
            }
            // Drop old days.
            if (row.optString("day") == today) next.put(row)
        }
        next.put(
            org.json.JSONObject()
                .put("id", reminderId)
                .put("day", today),
        )
        prefs.edit().putString(KEY_FIRED, next.toString()).apply()
    }

    fun wasFiredToday(context: Context, reminderId: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = dayKey()
        val map = JSONArray(prefs.getString(KEY_FIRED, "[]") ?: "[]")
        for (i in 0 until map.length()) {
            val row = map.optJSONObject(i) ?: continue
            if (row.optString("day") == today && row.optString("id") == reminderId) {
                return true
            }
        }
        return false
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
        val now = System.currentTimeMillis()
        for (i in 0 until array.length()) {
            if (requestCode > MAX_ALARM_IDS) break
            val item = array.optJSONObject(i) ?: continue
            if (!item.optBoolean("enabled", true)) continue

            val days = mutableSetOf<Int>()
            val daysArr = item.optJSONArray("daysOfWeek")
            if (daysArr != null) {
                for (d in 0 until daysArr.length()) {
                    days.add(daysArr.optInt(d))
                }
            }
            if (days.isEmpty()) days.addAll(1..7)

            val hour = item.optInt("hour", 0)
            val minute = item.optInt("minute", 0)
            val title = item.optString("title", "Pengingat")
            val body = item.optString("body", "")
            val style = item.optString("style", "fullscreen")
            val id = item.optString("id", "reminder-$i")

            // Catch-up: schedule was missed by up to 45 minutes (common when
            // parent saves after the clock time, or child syncs late).
            val todaysSlot = todaysSlotMillis(hour, minute)
            val missedRecently = todaysSlot != null &&
                days.contains(todayIsoDay()) &&
                now in (todaysSlot + 1)..(todaysSlot + CATCH_UP_WINDOW_MS) &&
                !wasFiredToday(context, id)

            if (missedRecently) {
                Log.i(TAG, "catch-up reminder id=$id in 8s")
                scheduleOne(
                    context = context,
                    requestCode = requestCode,
                    triggerAt = now + 8_000L,
                    id = id,
                    title = title,
                    body = body,
                    style = style,
                )
                requestCode += 1
            }

            if (requestCode > MAX_ALARM_IDS) break
            val nextAt = nextTriggerMillis(hour, minute, days)
            Log.i(TAG, "schedule id=$id next=$nextAt hour=$hour:$minute")
            scheduleOne(
                context = context,
                requestCode = requestCode,
                triggerAt = nextAt,
                id = id,
                title = title,
                body = body,
                style = style,
            )
            requestCode += 1
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
    ) {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
            putExtra(ReminderReceiver.EXTRA_ID, id)
            putExtra(ReminderReceiver.EXTRA_TITLE, title)
            putExtra(ReminderReceiver.EXTRA_BODY, body)
            putExtra(ReminderReceiver.EXTRA_STYLE, style)
            putExtra(ReminderReceiver.EXTRA_REQUEST_CODE, requestCode)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        try {
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerAt, showPending),
                    pending,
                )
            } else {
                @Suppress("DEPRECATION")
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        } catch (error: SecurityException) {
            Log.e(TAG, "exact alarm not permitted", error)
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pending)
        }
    }

    private fun todayIsoDay(): Int {
        return when (Calendar.getInstance().get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }
    }

    private fun calendarDowToIso(dow: Int): Int {
        return when (dow) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }
    }

    private fun todaysSlotMillis(hour: Int, minute: Int): Long? {
        val cal = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
        }
        return cal.timeInMillis
    }

    private fun nextTriggerMillis(hour: Int, minute: Int, daysIso: Set<Int>): Long {
        val now = System.currentTimeMillis()
        for (addDays in 0..8) {
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, addDays)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
            }
            val iso = calendarDowToIso(cal.get(Calendar.DAY_OF_WEEK))
            if (daysIso.contains(iso) && cal.timeInMillis > now + 3_000L) {
                return cal.timeInMillis
            }
        }
        // Fallback: tomorrow same time.
        return Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun dayKey(): String {
        val c = Calendar.getInstance()
        return "${c.get(Calendar.YEAR)}-${c.get(Calendar.DAY_OF_YEAR)}"
    }
}
