package com.mediassist.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.gdelataillade.alarm.api.AlarmApiImpl
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.NotificationSettings
import com.gdelataillade.alarm.models.VolumeSettings
import java.util.Date
import kotlin.time.Duration.Companion.seconds

/**
 * Keeps alarm-type reminders repeating while the app is closed.
 *
 * The `alarm` plugin schedules exactly one firing per alarm and has no repeat
 * mode. Rolling a fired alarm forward to the next day used to happen in Dart,
 * in main.dart's `Alarm.ringing` listener — which only runs while a Flutter
 * isolate is alive. With the app swiped away the alarm rang once and then
 * never again, and once the user tapped Stop on the notification the plugin
 * deleted it outright, so not even a reboot could bring it back.
 *
 * This receiver does the roll-forward natively instead, from the app's own
 * [DailyAlarmStore], and is therefore independent of the Flutter engine:
 *
 *  - a self-perpetuating AlarmManager "sweep" fires shortly after each
 *    reminder time and re-arms every alarm for its next occurrence;
 *  - boot and app-update broadcasts run the same sweep. That is also why the
 *    plugin's own BootReceiver is removed in AndroidManifest.xml: it re-armed
 *    alarms at their stale past time, which made every one of them ring at
 *    once on reboot.
 */
class DailyAlarmRearmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in HANDLED_ACTIONS) {
            Log.d(TAG, "Ignoring unhandled action: $action")
            return
        }

        // DataStore writes inside the alarm plugin are too slow for the main
        // thread, and a receiver is torn down as soon as onReceive returns.
        val pending = goAsync()
        val appContext = context.applicationContext
        Thread {
            try {
                rearmAll(appContext)
            } catch (e: Exception) {
                Log.e(TAG, "Re-arm sweep failed", e)
            } finally {
                pending.finish()
            }
        }.start()
    }

    companion object {
        private const val TAG = "DailyAlarmRearm"

        const val ACTION_REARM = "com.mediassist.app.ACTION_REARM_ALARMS"

        private const val SWEEP_REQUEST_CODE = 19781

        /**
         * How long after a reminder time the sweep runs.
         *
         * Long enough that the alarm it is rolling forward has definitely
         * fired — re-arming before it fires would move that firing to tomorrow
         * and the user would never hear it.
         */
        private const val SWEEP_LAG_MS = 2 * 60 * 1000L

        private val HANDLED_ACTIONS = setOf(
            ACTION_REARM,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )

        /**
         * Re-arms every stored daily alarm for its next occurrence and queues
         * the next sweep. Idempotent — setAlarm replaces any existing schedule
         * for the same ID, so running it twice costs nothing.
         *
         * A currently ringing alarm keeps ringing: a fresh [AlarmApiImpl] has
         * an empty in-memory ID list, so it schedules without stopping
         * anything.
         */
        fun rearmAll(context: Context) {
            val now = System.currentTimeMillis()

            // Prayer reminders are stored as an explicit horizon of instants,
            // so firings that have already happened are dead weight; drop them
            // before reading the store back.
            val datedStore = DatedAlarmStore(context)
            datedStore.prune(now)

            val dailySpecs = DailyAlarmStore(context).all()
            val datedSpecs = datedStore.all()
            if (dailySpecs.isEmpty() && datedSpecs.isEmpty()) {
                cancelSweep(context)
                Log.d(TAG, "No alarms stored; sweep cancelled")
                return
            }

            val api = AlarmApiImpl(context)
            var earliest = Long.MAX_VALUE

            for (spec in dailySpecs) {
                val next = spec.nextOccurrenceAfter(now)
                try {
                    api.setAlarm(spec.toAlarmSettings(next))
                    earliest = minOf(earliest, next.time)
                    Log.d(TAG, "Re-armed daily alarm ${spec.id} for $next")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to re-arm daily alarm ${spec.id}", e)
                }
            }

            for (spec in datedSpecs) {
                // Only the next firing is armed. The horizon behind it stays in
                // the store until the sweep that follows this one comes back
                // for it, so a month of prayer times costs one OS alarm.
                val next = spec.nextOccurrenceAfter(now) ?: continue
                try {
                    api.setAlarm(spec.toAlarmSettings(next))
                    earliest = minOf(earliest, next.time)
                    Log.d(TAG, "Re-armed dated alarm ${spec.id} for $next")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to re-arm dated alarm ${spec.id}", e)
                }
            }

            if (earliest != Long.MAX_VALUE) {
                scheduleSweep(context, earliest + SWEEP_LAG_MS)
            } else {
                cancelSweep(context)
            }
        }

        /**
         * Re-points the sweep at the next reminder time without touching the
         * alarms themselves.
         *
         * This is what the Dart side calls after it has armed the alarms
         * itself — re-arming them again here would mean a second round of
         * DataStore writes for no gain.
         */
        fun refreshSweep(context: Context) {
            val now = System.currentTimeMillis()
            val candidates = mutableListOf<Long>()

            DailyAlarmStore(context).all()
                .mapTo(candidates) { it.nextOccurrenceAfter(now).time }
            DatedAlarmStore(context).all()
                .mapNotNullTo(candidates) { it.nextOccurrenceAfter(now)?.time }

            val earliest = candidates.minOrNull()
            if (earliest == null) {
                cancelSweep(context)
                return
            }
            scheduleSweep(context, earliest + SWEEP_LAG_MS)
        }

        private fun scheduleSweep(context: Context, triggerAtMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "AlarmManager unavailable; cannot schedule sweep")
                return
            }

            val pendingIntent = sweepIntent(context)
            try {
                // Exact where allowed: a sweep deferred by Doze past the next
                // reminder time would silently skip a day. Inexact is still a
                // usable fallback when the exact-alarm permission is missing,
                // because the sweep only re-arms, it never alerts the user.
                val canBeExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    alarmManager.canScheduleExactAlarms()
                if (canBeExact) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                    )
                }
                Log.d(TAG, "Next re-arm sweep at ${Date(triggerAtMillis)}")
            } catch (e: SecurityException) {
                Log.w(TAG, "Exact sweep denied, falling back to inexact", e)
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                )
            }
        }

        private fun cancelSweep(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(sweepIntent(context))
        }

        private fun sweepIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            SWEEP_REQUEST_CODE,
            Intent(context, DailyAlarmRearmReceiver::class.java).setAction(ACTION_REARM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun DailyAlarmSpec.toAlarmSettings(next: Date) = alarmSettings(
            id = id,
            next = next,
            assetAudioPath = assetAudioPath,
            title = title,
            body = body,
            stopButton = stopButton,
            loopAudio = loopAudio,
            vibrate = vibrate,
        )

        private fun DatedAlarmSpec.toAlarmSettings(next: Date) = alarmSettings(
            id = id,
            next = next,
            assetAudioPath = assetAudioPath,
            title = title,
            body = body,
            stopButton = stopButton,
            loopAudio = loopAudio,
            vibrate = vibrate,
        )

        private fun alarmSettings(
            id: Int,
            next: Date,
            assetAudioPath: String?,
            title: String,
            body: String,
            stopButton: String?,
            loopAudio: Boolean,
            vibrate: Boolean,
        ) = AlarmSettings(
            id = id,
            dateTime = next,
            assetAudioPath = assetAudioPath,
            volumeSettings = VolumeSettings(
                volume = 1.0,
                fadeDuration = 3.seconds,
                fadeSteps = emptyList(),
                volumeEnforced = false,
            ),
            notificationSettings = NotificationSettings(
                title = title,
                body = body,
                stopButton = stopButton,
                icon = "notification_icon",
            ),
            loopAudio = loopAudio,
            vibrate = vibrate,
            // Alarms now survive the app being killed, so the plugin's
            // "your alarms may not ring" nag would be a lie.
            warningNotificationOnKill = false,
            androidFullScreenIntent = true,
            // Swiping the app away must not cancel a ringing reminder.
            androidStopAlarmOnTermination = false,
        )
    }
}
