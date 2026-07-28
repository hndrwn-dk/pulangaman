package com.tursinalabs.pulangaman

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.BatteryManager
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Relays Android Geofence transitions into the existing location POST pipeline
 * so server-side evaluateGeofences / FCM alerts keep working.
 * Also re-registers fences after reboot (Android clears them).
 */
class ZoneGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ZoneGeofenceManager.registerFromPrefs(context.applicationContext)
            return
        }

        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.w(TAG, "geofence error=${event.errorCode}")
            return
        }

        val transition = event.geofenceTransition
        if (transition != Geofence.GEOFENCE_TRANSITION_ENTER &&
            transition != Geofence.GEOFENCE_TRANSITION_EXIT
        ) {
            return
        }

        val triggering = event.triggeringLocation
        if (triggering == null) {
            Log.w(TAG, "no triggering location")
            return
        }

        val ids = event.triggeringGeofences?.map { it.requestId }.orEmpty()
        Log.i(
            TAG,
            "transition=$transition zones=$ids lat=${triggering.latitude} lng=${triggering.longitude}",
        )

        val pendingResult = goAsync()
        thread(name = "zone-geofence-post") {
            try {
                postLocation(context.applicationContext, triggering)
            } catch (e: Exception) {
                Log.w(TAG, "post failed", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun postLocation(context: Context, location: Location) {
        val prefs = context.getSharedPreferences(
            LocationTrackingService.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val base = prefs.getString(LocationTrackingService.KEY_API_BASE, null)
            ?.trimEnd('/')
            ?: return
        val token = prefs.getString(LocationTrackingService.KEY_TOKEN, null) ?: return
        if (token.isBlank() || base.isBlank()) return

        val body = JSONObject()
            .put("lat", location.latitude)
            .put("lng", location.longitude)
            .put("accuracyM", location.accuracy.toDouble())
            .put("source", "geofence")
        readBattery(context)?.let { (pct, charging) ->
            body.put("batteryLevel", pct)
            body.put("batteryCharging", charging)
        }

        val url = URL("$base/api/v1/location")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 12_000
            readTimeout = 12_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        try {
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
            val code = conn.responseCode
            if (code !in 200..299) {
                Log.w(TAG, "location POST status=$code")
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun readBattery(context: Context): Pair<Int, Boolean>? {
        return try {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            if (pct < 0) return null
            Pair(pct.coerceIn(0, 100), bm.isCharging)
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val TAG = "ZoneGeofenceRx"
    }
}
