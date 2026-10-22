import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../models/alarm_sound_model.dart';
import 'alarm_sound_service.dart';

/// Label on the ringing notification's stop action.
///
/// Passed through to the native mirror so a re-armed alarm is labelled
/// identically to one armed from Dart. Resolved per call rather than held as a
/// constant: the label is baked into the scheduled alarm, so it has to follow
/// whichever language was in force when the alarm was set.
String get _stopButtonLabel => 'alarm_stop'.tr;

class AlarmService extends GetxService {
  static AlarmService get to => Get.find();

  /// Bridge to the native daily-alarm mirror — see `MainActivity.kt` and
  /// `DailyAlarmRearmReceiver.kt`.
  ///
  /// The `alarm` package arms exactly one firing per alarm and has no repeat
  /// mode, and its ringing stream only exists while a Flutter isolate is
  /// alive. Mirroring every daily alarm natively is what lets
  /// `DailyAlarmRearmReceiver` roll them forward with the app closed.
  static const MethodChannel _dailyChannel =
      MethodChannel('com.mediassist.app/daily_alarms');

  Future<void> _invokeDaily(String method, [Map<String, dynamic>? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _dailyChannel.invokeMethod<void>(method, args);
    } catch (e) {
      // A failure here costs the app-closed repeat, not the next firing, so it
      // must never take down the scheduling call that triggered it.
      debugPrint('⚠️ Daily alarm mirror "$method" failed: $e');
    }
  }

  /// Drops every mirrored alarm. Pairs with "Clear all data".
  Future<void> clearDailySpecs() => _invokeDaily('clear');

  /// Re-points the native re-arm sweep at the earliest upcoming alarm.
  Future<void> syncDailySpecs() => _invokeDaily('sync');

  // ─── Core schedule method ─────────────────────────────────────────────────
  Future<void> scheduleAlarm({
    required int alarmId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool loopAudio = true,
    bool vibrate = true,
    AlarmSound? sound,
  }) async {
    try {
      // `null` here is meaningful, not missing: the plugin reads it as "use the
      // device's default alarm sound". Resolution — including the fallback for
      // a custom sound whose file has vanished — lives in AlarmSoundService so
      // it happens identically for every kind of alarm.
      final audioPath = AlarmSoundService.to.resolvedAudioPath(sound);
      final now = DateTime.now();
      DateTime scheduledTime = DateTime(
        now.year, now.month, now.day, hour, minute, 0,
      );

      // Only roll forward once the time has actually passed. Skipping a slot
      // that is merely seconds away — which `rescheduleAllFromStorage()` can
      // easily land on, since it runs on every resume — would drop today's
      // dose entirely.
      if (!scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: audioPath,
        loopAudio: loopAudio,
        vibrate: vibrate,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 3),
        ),
        // Alarms are re-armed natively now, so the plugin's "reopen the app or
        // your alarms may not ring" warning would be telling the user to do
        // something that is no longer needed.
        warningNotificationOnKill: false,
        // ✅ Full screen intent — shows over lock screen
        androidFullScreenIntent: true,
        // Swiping the app out of recents must not silence an alarm that is
        // already ringing.
        androidStopAlarmOnTermination: false,
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          // ✅ Stop button in notification bar — user can stop without opening app
          stopButton: _stopButtonLabel,
          icon: 'notification_icon',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);

      // Mirror the *time of day*, not this one firing: the native receiver
      // recomputes the next occurrence from it every cycle.
      await _invokeDaily('save', {
        'id': alarmId,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'stopButton': _stopButtonLabel,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'assetAudioPath': audioPath,
      });

      debugPrint('✅ Alarm set: id=$alarmId at $hour:$minute → $scheduledTime');
    } catch (e) {
      debugPrint('❌ Failed to set alarm id=$alarmId: $e');
    }
  }

  // ─── Dated alarms (prayer reminders) ──────────────────────────────────────
  /// Arms an alarm that fires at a *list of instants* rather than daily at a
  /// fixed clock time.
  ///
  /// Prayer times move every day, so [scheduleAlarm]'s hour-and-minute mirror
  /// would drift — and recomputing them natively would mean a second copy of
  /// the astronomical code. Instead Dart pushes a horizon of exact instants to
  /// `DatedAlarmStore`, and the native sweep arms them one at a time. Only the
  /// first is handed to the plugin here; the rest are the store's job.
  ///
  /// [times] may be in any order and may contain past instants — both are
  /// filtered here and again natively.
  Future<void> scheduleDatedAlarm({
    required int alarmId,
    required String title,
    required String body,
    required List<DateTime> times,
    bool loopAudio = false,
    bool vibrate = true,
    AlarmSound? sound,
  }) async {
    final audioPath = AlarmSoundService.to.resolvedAudioPath(sound);
    final now = DateTime.now();
    final upcoming = times
        .map((t) => t.toLocal())
        // A firing seconds away is treated as "fire now" by the plugin, so
        // anything that close counts as past.
        .where((t) => t.difference(now).inSeconds > 10)
        .toList()
      ..sort();

    if (upcoming.isEmpty) {
      await cancelAlarm(alarmId);
      return;
    }

    try {
      await Alarm.set(
        alarmSettings: AlarmSettings(
          id: alarmId,
          dateTime: upcoming.first,
          assetAudioPath: audioPath,
          loopAudio: loopAudio,
          vibrate: vibrate,
          volumeSettings: VolumeSettings.fade(
            volume: 1.0,
            fadeDuration: const Duration(seconds: 3),
          ),
          warningNotificationOnKill: false,
          androidFullScreenIntent: true,
          androidStopAlarmOnTermination: false,
          notificationSettings: NotificationSettings(
            title: title,
            body: body,
            stopButton: _stopButtonLabel,
            icon: 'notification_icon',
          ),
        ),
      );

      await _invokeDaily('saveDated', {
        'id': alarmId,
        'times':
            upcoming.map((t) => t.millisecondsSinceEpoch).toList(),
        'title': title,
        'body': body,
        'stopButton': _stopButtonLabel,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'assetAudioPath': audioPath,
      });

      debugPrint('✅ Dated alarm set: id=$alarmId, next=${upcoming.first}, '
          '${upcoming.length} firing(s) stored');
    } catch (e) {
      debugPrint('❌ Failed to set dated alarm id=$alarmId: $e');
    }
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────
  Future<void> cancelAlarm(int alarmId) async {
    try {
      await Alarm.stop(alarmId);
      // Drop the mirror too, otherwise the native sweep would resurrect the
      // alarm tomorrow morning.
      await _invokeDaily('remove', {'id': alarmId});
      debugPrint('🗑️ Alarm cancelled: id=$alarmId');
    } catch (e) {
      debugPrint('❌ Failed to cancel alarm id=$alarmId: $e');
    }
  }

  Future<void> cancelAlarms(List<int> alarmIds) async {
    for (final id in alarmIds) {
      await cancelAlarm(id);
    }
  }

  // ─── Query ────────────────────────────────────────────────────────────────
  Future<List<AlarmSettings>> getActiveAlarms() async {
    return await Alarm.getAlarms();
  }

  Future<bool> isAlarmActive(int alarmId) async {
    final alarms = await Alarm.getAlarms();
    return alarms.any((a) => a.id == alarmId);
  }

  // ─── Medicine alarms ──────────────────────────────────────────────────────
  Future<void> scheduleMedicineAlarms({
    required String medicineId,
    required String medicineName,
    required List<TimeOfDay> times,
    required int baseAlarmId,
    AlarmSound? sound,
  }) async {
    await cancelMedicineAlarms(times: times, baseAlarmId: baseAlarmId);

    for (int i = 0; i < times.length; i++) {
      await scheduleAlarm(
        alarmId: baseAlarmId + i,
        title: '💊 ${'alarm_medicine_title'.tr}',
        body: 'alarm_medicine_body'.trParams({'name': medicineName}),
        hour: times[i].hour,
        minute: times[i].minute,
        loopAudio: true,
        vibrate: true,
        sound: sound,
      );
    }
  }

  Future<void> cancelMedicineAlarms({
    required List<TimeOfDay> times,
    required int baseAlarmId,
  }) async {
    for (int i = 0; i < times.length; i++) {
      await cancelAlarm(baseAlarmId + i);
    }
  }

  // ─── Meal alarms ──────────────────────────────────────────────────────────
  Future<void> scheduleMealAlarm({
    required String mealId,
    required String mealName,
    required TimeOfDay time,
    required int alarmId,
    AlarmSound? sound,
  }) async {
    await cancelAlarm(alarmId);
    await scheduleAlarm(
      alarmId: alarmId,
      title: '🍽️ ${'alarm_meal_title'.tr}',
      body: 'alarm_time_for'.trParams({'name': mealName}),
      hour: time.hour,
      minute: time.minute,
      loopAudio: false,
      vibrate: true,
      sound: sound,
    );
  }

  // ─── Activity alarms ──────────────────────────────────────────────────────
  Future<void> scheduleActivityAlarm({
    required String activityId,
    required String activityName,
    required TimeOfDay time,
    required int alarmId,
    AlarmSound? sound,
  }) async {
    await cancelAlarm(alarmId);
    await scheduleAlarm(
      alarmId: alarmId,
      title: '🏃 ${'alarm_activity_title'.tr}',
      body: 'alarm_time_for'.trParams({'name': activityName}),
      hour: time.hour,
      minute: time.minute,
      loopAudio: false,
      vibrate: true,
      sound: sound,
    );
  }
}
