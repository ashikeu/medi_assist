package com.mediassist.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /// The ringtone picker and preview player. Held so the Activity can hand
    /// it the picker's result and release the player on the way out.
    private var soundChannel: SoundChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Mirrors alarm-type reminders into native storage so
        // DailyAlarmRearmReceiver can keep them firing with no Flutter engine
        // running. See AlarmService on the Dart side.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DAILY_ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                val store = DailyAlarmStore(applicationContext)
                val datedStore = DatedAlarmStore(applicationContext)
                when (call.method) {
                    "save" -> {
                        val id = call.argument<Int>("id")
                        val hour = call.argument<Int>("hour")
                        val minute = call.argument<Int>("minute")
                        if (id == null || hour == null || minute == null) {
                            result.error("bad_args", "id, hour and minute are required", null)
                            return@setMethodCallHandler
                        }
                        store.save(
                            DailyAlarmSpec(
                                id = id,
                                hour = hour,
                                minute = minute,
                                title = call.argument<String>("title") ?: "",
                                body = call.argument<String>("body") ?: "",
                                stopButton = call.argument<String>("stopButton"),
                                loopAudio = call.argument<Boolean>("loopAudio") ?: true,
                                vibrate = call.argument<Boolean>("vibrate") ?: true,
                                assetAudioPath = call.argument<String>("assetAudioPath"),
                            )
                        )
                        DailyAlarmRearmReceiver.refreshSweep(applicationContext)
                        result.success(null)
                    }

                    // Prayer reminders: an explicit horizon of instants rather
                    // than a repeating time of day, because prayer times move
                    // daily. See DatedAlarmStore.
                    "saveDated" -> {
                        val id = call.argument<Int>("id")
                        val rawTimes = call.argument<List<*>>("times")
                        if (id == null || rawTimes == null) {
                            result.error("bad_args", "id and times are required", null)
                            return@setMethodCallHandler
                        }
                        val times = rawTimes
                            .mapNotNull { (it as? Number)?.toLong() }
                            .sorted()
                        if (times.isEmpty()) {
                            // Nothing left to fire — treat it as a removal so
                            // the store never holds an empty spec.
                            datedStore.remove(id)
                        } else {
                            datedStore.save(
                                DatedAlarmSpec(
                                    id = id,
                                    times = times,
                                    title = call.argument<String>("title") ?: "",
                                    body = call.argument<String>("body") ?: "",
                                    stopButton = call.argument<String>("stopButton"),
                                    loopAudio = call.argument<Boolean>("loopAudio") ?: false,
                                    vibrate = call.argument<Boolean>("vibrate") ?: true,
                                    assetAudioPath = call.argument<String>("assetAudioPath"),
                                )
                            )
                        }
                        DailyAlarmRearmReceiver.refreshSweep(applicationContext)
                        result.success(null)
                    }

                    "remove" -> {
                        val id = call.argument<Int>("id")
                        if (id == null) {
                            result.error("bad_args", "id is required", null)
                            return@setMethodCallHandler
                        }
                        // An ID belongs to exactly one of the two stores, but
                        // removing from both costs nothing and means a caller
                        // never has to know which kind it is cancelling.
                        store.remove(id)
                        datedStore.remove(id)
                        DailyAlarmRearmReceiver.refreshSweep(applicationContext)
                        result.success(null)
                    }

                    "clear" -> {
                        store.clear()
                        datedStore.clear()
                        DailyAlarmRearmReceiver.refreshSweep(applicationContext)
                        result.success(null)
                    }

                    "sync" -> {
                        DailyAlarmRearmReceiver.refreshSweep(applicationContext)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        // A coordinate for the prayer-time calculation. Deliberately the
        // platform's own LocationManager rather than a plugin: the app needs
        // one fix, occasionally, with no background tracking and no network
        // round trip — see DeviceLocationService on the Dart side.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> requestCurrentLocation(
                        timeoutMs = (call.argument<Int>("timeoutMs") ?: 20_000).toLong(),
                        result = result,
                    )
                    else -> result.notImplemented()
                }
            }

        // Ringtone picking, copying and preview. See SoundChannel.
        val sounds = SoundChannel(this)
        soundChannel = sounds
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SoundChannel.CHANNEL)
            .setMethodCallHandler(sounds::handle)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (soundChannel?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        soundChannel?.dispose()
        soundChannel = null
        super.onDestroy()
    }

    // ─── Location ────────────────────────────────────────────────────────────

    /**
     * Resolves a single fix.
     *
     * Tries the freshest cached fix first — it is instant and almost always
     * good enough to name a city — and only listens for a live one when there
     * is nothing recent. The listener is always torn down, on success and on
     * timeout alike, so nothing keeps the GPS awake after this returns.
     */
    private fun requestCurrentLocation(timeoutMs: Long, result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("permission_denied", "Location permission not granted", null)
            return
        }

        val manager = getSystemService(LOCATION_SERVICE) as? LocationManager
        if (manager == null) {
            result.error("unavailable", "LocationManager unavailable", null)
            return
        }

        val cached = freshestCachedFix(manager)
        if (cached != null &&
            System.currentTimeMillis() - cached.time < CACHED_FIX_MAX_AGE_MS
        ) {
            result.success(cached.toMap())
            return
        }

        val provider = when {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> null
        }

        if (provider == null) {
            // Location is switched off entirely. A stale cached fix still beats
            // nothing — the caller decides whether to trust it.
            if (cached != null) {
                result.success(cached.toMap())
            } else {
                result.error("location_off", "Location services are disabled", null)
            }
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var settled = false
        var listener: LocationListener? = null

        val finish = { action: () -> Unit ->
            if (!settled) {
                settled = true
                listener?.let { manager.removeUpdates(it) }
                action()
            }
        }

        val timeout = Runnable {
            finish {
                if (cached != null) {
                    result.success(cached.toMap())
                } else {
                    result.error("timeout", "Timed out waiting for a location fix", null)
                }
            }
        }

        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                handler.removeCallbacks(timeout)
                finish { result.success(location.toMap()) }
            }

            // Required on API levels below 30; the default implementations are
            // only added in Android 11.
            override fun onProviderEnabled(provider: String) = Unit
            override fun onProviderDisabled(provider: String) {
                handler.removeCallbacks(timeout)
                finish {
                    if (cached != null) {
                        result.success(cached.toMap())
                    } else {
                        result.error("location_off", "Location provider disabled", null)
                    }
                }
            }

            @Deprecated("Deprecated in API 29, still called below it")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }

        try {
            manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            handler.postDelayed(timeout, timeoutMs)
        } catch (e: SecurityException) {
            finish { result.error("permission_denied", "Location permission revoked", null) }
        } catch (e: Exception) {
            finish { result.error("unavailable", e.message, null) }
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun freshestCachedFix(manager: LocationManager): Location? = try {
        listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).mapNotNull { provider ->
            runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
        }.maxByOrNull { it.time }
    } catch (e: SecurityException) {
        null
    }

    private fun Location.toMap(): Map<String, Any> = mapOf(
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy.toDouble(),
        "timestamp" to time,
    )

    private companion object {
        const val DAILY_ALARM_CHANNEL = "com.mediassist.app/daily_alarms"
        const val LOCATION_CHANNEL = "com.mediassist.app/location"

        /**
         * How old a cached fix may be and still be returned without listening
         * for a new one. Prayer times change by seconds over a few kilometres,
         * so a ten-minute-old fix is indistinguishable from a fresh one.
         */
        const val CACHED_FIX_MAX_AGE_MS = 10 * 60 * 1000L
    }
}
