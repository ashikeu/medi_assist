package com.mediassist.app

import android.content.Context
import org.json.JSONObject
import java.util.Calendar
import java.util.Date

/**
 * One daily reminder alarm, as the Dart side defined it.
 *
 * This is deliberately a *time of day* rather than an instant: the alarm
 * plugin only ever holds the single next firing, so the repeat has to be
 * recomputed from the wall-clock time every cycle.
 */
data class DailyAlarmSpec(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val title: String,
    val body: String,
    val stopButton: String?,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val assetAudioPath: String?,
) {
    /** The first occurrence of [hour]:[minute] strictly after [now]. */
    fun nextOccurrenceAfter(now: Long): Date {
        val cal = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // AlarmApiImpl treats a delay of <= 5s as "fire right now", so anything
        // that close counts as already past — otherwise re-arming during the
        // ring would immediately re-trigger the alarm.
        while (cal.timeInMillis - now <= FIRE_NOW_WINDOW_MS) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return Date(cal.timeInMillis)
    }

    fun toJson(): String = JSONObject().apply {
        put(KEY_ID, id)
        put(KEY_HOUR, hour)
        put(KEY_MINUTE, minute)
        put(KEY_TITLE, title)
        put(KEY_BODY, body)
        put(KEY_STOP_BUTTON, stopButton ?: JSONObject.NULL)
        put(KEY_LOOP_AUDIO, loopAudio)
        put(KEY_VIBRATE, vibrate)
        put(KEY_AUDIO_PATH, assetAudioPath ?: JSONObject.NULL)
    }.toString()

    companion object {
        private const val FIRE_NOW_WINDOW_MS = 10_000L

        private const val KEY_ID = "id"
        private const val KEY_HOUR = "hour"
        private const val KEY_MINUTE = "minute"
        private const val KEY_TITLE = "title"
        private const val KEY_BODY = "body"
        private const val KEY_STOP_BUTTON = "stopButton"
        private const val KEY_LOOP_AUDIO = "loopAudio"
        private const val KEY_VIBRATE = "vibrate"
        private const val KEY_AUDIO_PATH = "assetAudioPath"

        fun fromJson(raw: String): DailyAlarmSpec? = try {
            val o = JSONObject(raw)
            DailyAlarmSpec(
                id = o.getInt(KEY_ID),
                hour = o.getInt(KEY_HOUR),
                minute = o.getInt(KEY_MINUTE),
                title = o.optString(KEY_TITLE),
                body = o.optString(KEY_BODY),
                stopButton = if (o.isNull(KEY_STOP_BUTTON)) null else o.optString(KEY_STOP_BUTTON),
                loopAudio = o.optBoolean(KEY_LOOP_AUDIO, true),
                vibrate = o.optBoolean(KEY_VIBRATE, true),
                assetAudioPath = if (o.isNull(KEY_AUDIO_PATH)) null else o.optString(KEY_AUDIO_PATH),
            )
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * The app's own record of which daily alarms exist.
 *
 * The `alarm` plugin keeps its own store, but it deletes an alarm as soon as it
 * is stopped — including when the user taps "Stop" on the ringing
 * notification. That makes it useless as the source of truth for a *daily*
 * reminder, so [DailyAlarmRearmReceiver] re-arms from this store instead.
 *
 * Plain SharedPreferences on purpose: it has to be readable from a broadcast
 * receiver with no Flutter engine running.
 */
class DailyAlarmStore(context: Context) {

    private val prefs =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(spec: DailyAlarmSpec) {
        prefs.edit().putString(KEY_PREFIX + spec.id, spec.toJson()).apply()
    }

    fun remove(id: Int) {
        prefs.edit().remove(KEY_PREFIX + id).apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun all(): List<DailyAlarmSpec> = prefs.all.entries
        .filter { it.key.startsWith(KEY_PREFIX) }
        .mapNotNull { (it.value as? String)?.let(DailyAlarmSpec::fromJson) }

    private companion object {
        const val PREFS_NAME = "mediassist_daily_alarms"
        const val KEY_PREFIX = "daily_alarm_"
    }
}
