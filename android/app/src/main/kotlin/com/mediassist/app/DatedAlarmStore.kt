package com.mediassist.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date

/**
 * An alarm whose firings are a *list of instants* rather than a time of day.
 *
 * Every other reminder in this app repeats at the same wall-clock time, which
 * is why [DailyAlarmSpec] can store an hour and a minute and let the native
 * sweep recompute tomorrow. Prayer times do not work that way: they move by a
 * minute or two every day and depend on latitude, longitude and the chosen
 * calculation method. Reproducing that arithmetic in Kotlin would mean a
 * second implementation of it, and the two would drift.
 *
 * So Dart computes the schedule — which it already does, for the screen the
 * user is looking at — and pushes a long horizon of exact timestamps here.
 * The sweep then does what it does for every other alarm: arm the next one and
 * come back afterwards. Only one AlarmManager alarm is ever outstanding per
 * reminder, however many days the horizon covers.
 */
data class DatedAlarmSpec(
    val id: Int,
    val times: List<Long>,
    val title: String,
    val body: String,
    val stopButton: String?,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val assetAudioPath: String?,
) {
    /** The first stored firing strictly after [now], or null once exhausted. */
    fun nextOccurrenceAfter(now: Long): Date? =
        times.firstOrNull { it - now > FIRE_NOW_WINDOW_MS }?.let { Date(it) }

    /** This spec with already-fired times dropped, or null if none are left. */
    fun prunedAfter(now: Long): DatedAlarmSpec? {
        val remaining = times.filter { it - now > FIRE_NOW_WINDOW_MS }
        if (remaining.isEmpty()) return null
        if (remaining.size == times.size) return this
        return copy(times = remaining)
    }

    fun toJson(): String = JSONObject().apply {
        put(KEY_ID, id)
        put(KEY_TIMES, JSONArray().also { array -> times.forEach(array::put) })
        put(KEY_TITLE, title)
        put(KEY_BODY, body)
        put(KEY_STOP_BUTTON, stopButton ?: JSONObject.NULL)
        put(KEY_LOOP_AUDIO, loopAudio)
        put(KEY_VIBRATE, vibrate)
        put(KEY_AUDIO_PATH, assetAudioPath ?: JSONObject.NULL)
    }.toString()

    companion object {
        /**
         * AlarmApiImpl treats anything within a few seconds as "fire now", so
         * a firing that close counts as already past — otherwise a sweep that
         * runs during the ring would immediately re-trigger it.
         */
        private const val FIRE_NOW_WINDOW_MS = 10_000L

        private const val KEY_ID = "id"
        private const val KEY_TIMES = "times"
        private const val KEY_TITLE = "title"
        private const val KEY_BODY = "body"
        private const val KEY_STOP_BUTTON = "stopButton"
        private const val KEY_LOOP_AUDIO = "loopAudio"
        private const val KEY_VIBRATE = "vibrate"
        private const val KEY_AUDIO_PATH = "assetAudioPath"

        fun fromJson(raw: String): DatedAlarmSpec? = try {
            val o = JSONObject(raw)
            val array = o.getJSONArray(KEY_TIMES)
            val times = ArrayList<Long>(array.length())
            for (i in 0 until array.length()) times.add(array.getLong(i))
            DatedAlarmSpec(
                id = o.getInt(KEY_ID),
                times = times.sorted(),
                title = o.optString(KEY_TITLE),
                body = o.optString(KEY_BODY),
                stopButton = if (o.isNull(KEY_STOP_BUTTON)) null else o.optString(KEY_STOP_BUTTON),
                loopAudio = o.optBoolean(KEY_LOOP_AUDIO, false),
                vibrate = o.optBoolean(KEY_VIBRATE, true),
                assetAudioPath = if (o.isNull(KEY_AUDIO_PATH)) null else o.optString(KEY_AUDIO_PATH),
            )
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * The app's record of which dated alarms exist.
 *
 * Deliberately a separate SharedPreferences file from [DailyAlarmStore] so
 * that neither store can corrupt the other's keys, and plain SharedPreferences
 * for the same reason that one is: [DailyAlarmRearmReceiver] reads it with no
 * Flutter engine running.
 */
class DatedAlarmStore(context: Context) {

    private val prefs =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(spec: DatedAlarmSpec) {
        prefs.edit().putString(KEY_PREFIX + spec.id, spec.toJson()).apply()
    }

    fun remove(id: Int) {
        prefs.edit().remove(KEY_PREFIX + id).apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun all(): List<DatedAlarmSpec> = prefs.all.entries
        .filter { it.key.startsWith(KEY_PREFIX) }
        .mapNotNull { (it.value as? String)?.let(DatedAlarmSpec::fromJson) }

    /**
     * Drops firings that have already happened, and specs left with none.
     *
     * Without this the horizon Dart pushes would accumulate indefinitely on a
     * phone whose owner never opens the app.
     */
    fun prune(now: Long) {
        val editor = prefs.edit()
        var changed = false
        for (spec in all()) {
            val pruned = spec.prunedAfter(now)
            when {
                pruned == null -> {
                    editor.remove(KEY_PREFIX + spec.id)
                    changed = true
                }
                pruned !== spec -> {
                    editor.putString(KEY_PREFIX + spec.id, pruned.toJson())
                    changed = true
                }
            }
        }
        if (changed) editor.apply()
    }

    private companion object {
        const val PREFS_NAME = "mediassist_dated_alarms"
        const val KEY_PREFIX = "dated_alarm_"
    }
}
