package com.tursinalabs.pulangaman

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray
import org.json.JSONObject

/**
 * Registers circular safe-zones with Android [GeofencingClient].
 * Zone enter/exit alerts are handled by [ZoneGeofenceReceiver], which POSTs
 * a location sample so the existing server [evaluateGeofences] path runs.
 * Continuous live tracking remains [LocationTrackingService]'s job.
 */
object ZoneGeofenceManager {
    private const val TAG = "ZoneGeofence"
    private const val PREFS = "zone_geofences"
    private const val KEY_ZONES_JSON = "zones_json"
    private const val ACTION = "com.tursinalabs.pulangaman.ZONE_GEOFENCE_EVENT"
    private const val PENDING_REQUEST_CODE = 7101

    data class ZoneSpec(
        val id: String,
        val lat: Double,
        val lng: Double,
        val radiusM: Float,
    )

    fun saveAndRegister(context: Context, zones: List<ZoneSpec>) {
        val arr = JSONArray()
        for (z in zones) {
            if (z.id.isBlank()) continue
            if (z.radiusM < 20f) continue
            arr.put(
                JSONObject()
                    .put("id", z.id)
                    .put("lat", z.lat)
                    .put("lng", z.lng)
                    .put("radiusM", z.radiusM.toDouble()),
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ZONES_JSON, arr.toString())
            .apply()
        registerFromPrefs(context)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ZONES_JSON)
            .apply()
        removeAll(context)
    }

    fun registerFromPrefs(context: Context) {
        val zones = loadZones(context)
        if (zones.isEmpty()) {
            removeAll(context)
            return
        }
        if (!hasFineLocation(context)) {
            Log.w(TAG, "skip register: fine location missing")
            return
        }
        addGeofences(context, zones)
    }

    private fun loadZones(context: Context): List<ZoneSpec> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ZONES_JSON, null)
            ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val id = o.optString("id")
                    val lat = o.optDouble("lat", Double.NaN)
                    val lng = o.optDouble("lng", Double.NaN)
                    val radius = o.optDouble("radiusM", 0.0).toFloat()
                    if (id.isBlank() || lat.isNaN() || lng.isNaN() || radius < 20f) continue
                    add(ZoneSpec(id, lat, lng, radius.coerceAtMost(5000f)))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "bad zones json", e)
            emptyList()
        }
    }

    @SuppressLint("MissingPermission")
    private fun addGeofences(context: Context, zones: List<ZoneSpec>) {
        val client = LocationServices.getGeofencingClient(context)
        val pending = geofencePendingIntent(context)

        // Replace all known fences so edits/deletes stick.
        client.removeGeofences(pending)
            .addOnCompleteListener {
                val list = zones.map { z ->
                    Geofence.Builder()
                        .setRequestId(z.id.take(100))
                        .setCircularRegion(z.lat, z.lng, z.radiusM)
                        .setExpirationDuration(Geofence.NEVER_EXPIRE)
                        .setTransitionTypes(
                            Geofence.GEOFENCE_TRANSITION_ENTER or
                                Geofence.GEOFENCE_TRANSITION_EXIT,
                        )
                        .build()
                }
                if (list.isEmpty()) return@addOnCompleteListener
                val request = GeofencingRequest.Builder()
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                    .addGeofences(list)
                    .build()
                client.addGeofences(request, pending)
                    .addOnSuccessListener {
                        Log.i(TAG, "registered ${list.size} geofences")
                    }
                    .addOnFailureListener { error ->
                        Log.w(TAG, "addGeofences failed", error)
                    }
            }
    }

    private fun removeAll(context: Context) {
        val client = LocationServices.getGeofencingClient(context)
        client.removeGeofences(geofencePendingIntent(context))
            .addOnFailureListener { Log.w(TAG, "removeGeofences failed", it) }
    }

    fun geofencePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ZoneGeofenceReceiver::class.java).apply {
            action = ACTION
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(context, PENDING_REQUEST_CODE, intent, flags)
    }

    private fun hasFineLocation(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    const val RECEIVER_ACTION = ACTION
}
