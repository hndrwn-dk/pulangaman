package com.tursinalabs.pulangaman

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

class LocationTrackingService : Service(), LocationListener {
    private val prefs by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    private var locationManager: LocationManager? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private val posting = AtomicBoolean(false)
    private var lastPostedAt = 0L

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        startForeground(NOTIFICATION_ID, buildNotification(false))
        workerThread = HandlerThread("location-upload").also { it.start() }
        workerHandler = Handler(workerThread!!.looper)
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_CONFIG -> {
                startForeground(NOTIFICATION_ID, buildNotification(isPanic()))
                restartUpdates()
                return START_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, buildNotification(isPanic()))
                restartUpdates()
                // Push immediately so parent sees movement ASAP.
                workerHandler?.post { pushLastKnown() }
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {
        }
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onLocationChanged(location: Location) {
        maybePost(location)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    private fun restartUpdates() {
        val manager = locationManager ?: return
        try {
            manager.removeUpdates(this)
        } catch (_: Exception) {
        }

        if (!hasLocationPermission()) {
            Log.w(TAG, "location permission missing")
            return
        }

        val intervalMs = if (isPanic()) PANIC_INTERVAL_MS else NORMAL_INTERVAL_MS
        val minDistance = if (isPanic()) 5f else 12f
        try {
            if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                manager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    intervalMs,
                    minDistance,
                    this,
                    Looper.getMainLooper(),
                )
            }
            if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                manager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    intervalMs,
                    minDistance,
                    this,
                    Looper.getMainLooper(),
                )
            }
        } catch (error: SecurityException) {
            Log.e(TAG, "requestLocationUpdates failed", error)
        }

        workerHandler?.removeCallbacksAndMessages(null)
        scheduleHeartbeat(intervalMs)
    }

    private fun scheduleHeartbeat(intervalMs: Long) {
        workerHandler?.postDelayed({
            pushLastKnown()
            scheduleHeartbeat(if (isPanic()) PANIC_INTERVAL_MS else NORMAL_INTERVAL_MS)
        }, intervalMs)
    }

    private fun pushLastKnown() {
        if (!hasLocationPermission()) return
        val manager = locationManager ?: return
        val candidates = listOfNotNull(
            tryGetLast(manager, LocationManager.GPS_PROVIDER),
            tryGetLast(manager, LocationManager.NETWORK_PROVIDER),
        )
        val best = candidates.maxByOrNull { it.time } ?: return
        maybePost(best, force = true)
    }

    private fun tryGetLast(manager: LocationManager, provider: String): Location? {
        return try {
            manager.getLastKnownLocation(provider)
        } catch (_: SecurityException) {
            null
        }
    }

    private fun maybePost(location: Location, force: Boolean = false) {
        val now = System.currentTimeMillis()
        val minGap = if (isPanic()) PANIC_INTERVAL_MS else NORMAL_INTERVAL_MS
        if (!force && now - lastPostedAt < minGap / 2) return
        if (!posting.compareAndSet(false, true)) return
        workerHandler?.post {
            try {
                postLocation(location)
                lastPostedAt = System.currentTimeMillis()
            } catch (error: Exception) {
                Log.e(TAG, "postLocation failed", error)
            } finally {
                posting.set(false)
            }
        }
    }

    private fun postLocation(location: Location) {
        val apiBase = prefs.getString(KEY_API_BASE, null)?.trimEnd('/') ?: return
        val token = prefs.getString(KEY_TOKEN, null) ?: return
        if (token.isBlank() || apiBase.isBlank()) return

        val battery = readBattery()
        val body = JSONObject()
            .put("lat", location.latitude)
            .put("lng", location.longitude)
            .put("accuracyM", location.accuracy.toDouble())
            .put("source", if (isPanic()) "panic" else "background")
        if (battery != null) {
            body.put("batteryLevel", battery.first)
            body.put("batteryCharging", battery.second)
        }

        val url = URL("$apiBase/api/v1/location")
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

    private fun readBattery(): Pair<Int, Boolean>? {
        return try {
            val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
            val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            if (pct < 0) return null
            val charging = bm.isCharging
            Pair(pct.coerceIn(0, 100), charging)
        } catch (_: Exception) {
            // Fallback for older/quirky devices.
            try {
                val intent = if (android.os.Build.VERSION.SDK_INT >= 33) {
                    registerReceiver(
                        null,
                        IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                        Context.RECEIVER_NOT_EXPORTED,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                } ?: return null
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (level < 0 || scale <= 0) return null
                val pct = ((level * 100f) / scale).toInt().coerceIn(0, 100)
                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                val charging =
                    status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                Pair(pct, charging)
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun isPanic(): Boolean = prefs.getBoolean(KEY_PANIC, false)

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Pelacakan lokasi",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun buildNotification(panic: Boolean) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(
                if (panic) "Mode panik aktif" else "PulangAman membagikan lokasi",
            )
            .setContentText(
                if (panic) {
                    "Lokasi dikirim lebih sering agar orang tua bisa memantau"
                } else {
                    "Orang tua dapat melihat posisi kamu secara langsung"
                },
            )
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    companion object {
        private const val TAG = "LocationTracking"
        const val PREFS_NAME = "location_tracking"
        const val KEY_TOKEN = "auth_token"
        const val KEY_API_BASE = "api_base_url"
        const val KEY_PANIC = "panic_mode"
        const val ACTION_STOP = "com.tursinalabs.pulangaman.STOP_LOCATION"
        const val ACTION_UPDATE_CONFIG = "com.tursinalabs.pulangaman.UPDATE_LOCATION"
        private const val CHANNEL_ID = "location_tracking"
        private const val NOTIFICATION_ID = 4201
        private const val NORMAL_INTERVAL_MS = 10_000L
        private const val PANIC_INTERVAL_MS = 3_000L

        fun saveConfig(
            context: Context,
            token: String,
            apiBaseUrl: String,
            panic: Boolean,
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TOKEN, token)
                .putString(KEY_API_BASE, apiBaseUrl)
                .putBoolean(KEY_PANIC, panic)
                .apply()
        }
    }
}
