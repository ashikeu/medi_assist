import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────────────────────────
  static const String appName = 'MediAssist';
  static const String appVersion = '1.0.0';

  // ─── Data Storage Keys (cleared when user clears data) ──────────────────────
  static const String medicinesKey       = 'medicines';
  static const String mealsKey           = 'meals';
  static const String medicalRecordsKey  = 'medical_records';
  static const String activitiesKey      = 'activities';
  static const String prayerRemindersKey = 'prayer_reminders';
  static const String customPrayersKey   = 'custom_prayers';

  // ─── Settings Storage Keys (NEVER cleared — persist forever) ────────────────
  // Box name for settings — kept separate from data box
  static const String settingsBoxName        = 'mediassist_settings';

  static const String firstLaunchKey         = 'first_launch';
  static const String permissionAskedKey     = 'permission_asked';
  static const String lastRescheduleDateKey  = 'last_reschedule_date';
  static const String snoozeMinutesKey       = 'snooze_minutes';
  static const String themeKey               = 'theme_mode';
  static const String languageKey            = 'language_code';

  /// The sound every alarm uses unless the reminder itself names another.
  static const String alarmSoundKey          = 'alarm_sound';

  /// Ringtones and audio files the user has imported, so they can be picked
  /// again without going back out to the system picker.
  static const String alarmSoundLibraryKey   = 'alarm_sound_library';

  // Prayer module. Location and calculation preferences belong here rather
  // than in the data box: they are settings the user configured once, and
  // "Clear All Data" wiping them would leave the prayer screen calculating for
  // the fallback city with no hint as to why.
  static const String prayerLocationKey      = 'prayer_location';
  static const String prayerSettingsKey      = 'prayer_settings';
  static const String prayerEnabledKey       = 'prayer_module_enabled';

  /// How many reminder slots were in use the last time prayer reminders were
  /// scheduled. Scheduling cancels this many slots before re-arming, which is
  /// what keeps a deleted reminder from firing without having to sweep the
  /// whole [prayerNotifRange].
  static const String prayerSlotCountKey     = 'prayer_slot_count';

  // Pending notification route (for background tap → navigate on next open)
  static const String pendingRouteKey        = 'pending_notification_route';

  // ─── Notification Channels ──────────────────────────────────────────────────
  static const String medicineChannelId   = 'mediassist_medicine_channel';
  static const String medicineChannelName = 'Medicine Reminders';

  static const String mealChannelId       = 'mediassist_meal_channel';
  static const String mealChannelName     = 'Meal Reminders';

  static const String activityChannelId   = 'mediassist_activity_channel';
  static const String activityChannelName = 'Activity Reminders';

  static const String medicalChannelId    = 'mediassist_medical_channel';
  static const String medicalChannelName  = 'Medical Record Reminders';

  static const String foregroundChannelId   = 'mediassist_foreground_channel';
  static const String foregroundChannelName = 'MediAssist Service';

  // ─── Prayer notification channels ───────────────────────────────────────────
  // Four of them, one per sound/vibration combination.
  //
  // From Android 8 onwards sound and vibration are properties of the *channel*
  // and are fixed when it is created — a per-notification flag is ignored. A
  // reminder that the user configured as silent-but-vibrating therefore has to
  // be posted to a channel that is itself silent and vibrating; there is no
  // way to express it on a single channel. [prayerChannelFor] picks.
  static const String prayerChannelId       = 'mediassist_prayer_channel';
  static const String prayerChannelName     = 'Prayer Reminders';

  static const String prayerSoundOnlyChannelId   = 'mediassist_prayer_sound_channel';
  static const String prayerSoundOnlyChannelName = 'Prayer Reminders (No Vibration)';

  static const String prayerVibrateOnlyChannelId   = 'mediassist_prayer_vibrate_channel';
  static const String prayerVibrateOnlyChannelName = 'Prayer Reminders (Vibrate Only)';

  static const String prayerSilentChannelId   = 'mediassist_prayer_silent_channel';
  static const String prayerSilentChannelName = 'Prayer Reminders (Silent)';

  /// The channel id and fallback name for a reminder's sound/vibration choice.
  static ({String id, String name}) prayerChannelFor({
    required bool playSound,
    required bool vibrate,
  }) {
    if (playSound && vibrate) {
      return (id: prayerChannelId, name: prayerChannelName);
    }
    if (playSound) {
      return (id: prayerSoundOnlyChannelId, name: prayerSoundOnlyChannelName);
    }
    if (vibrate) {
      return (id: prayerVibrateOnlyChannelId, name: prayerVibrateOnlyChannelName);
    }
    return (id: prayerSilentChannelId, name: prayerSilentChannelName);
  }

  // ─── Notification ID Ranges ─────────────────────────────────────────────────
  // Medicine:  1000–1999
  // Meal:      2000–2999
  // Activity:  3000–3999
  // Medical:   4000–4999
  // Prayer:    10000–11999
  static const int medicineNotifBase  = 1000;
  static const int mealNotifBase      = 2000;
  static const int activityNotifBase  = 3000;
  static const int medicalNotifBase   = 4000;
  static const int prayerNotifBase    = 10000;

  /// How many notification IDs the prayer module owns.
  ///
  /// Prayer times move every day, so unlike every other module these cannot be
  /// a single daily-repeating notification — each reminder needs one ID per
  /// day of the scheduling horizon. Deliberately parked above the alarm ranges
  /// rather than squeezed between them.
  static const int prayerNotifRange   = 2000;

  // ─── Alarm ID Ranges ────────────────────────────────────────────────────────
  // Medicine:  5000–5999
  // Meal:      6000–6999
  // Activity:  7000–7999
  // Medical:   8000–8999
  // Snooze:    9000–9999  (mirror of the alarm that was snoozed)
  // Prayer:    12000–12999
  static const int medicineAlarmBase  = 5000;
  static const int mealAlarmBase      = 6000;
  static const int activityAlarmBase  = 7000;
  static const int medicalAlarmBase   = 8000;
  static const int prayerAlarmBase    = 12000;
  static const int prayerAlarmRange   = 1000;

  /// Prayer alarms fire on an explicit schedule held natively, not daily at a
  /// fixed clock time, so the "roll forward 24 hours" fast path in `main.dart`
  /// must leave them alone — the native sweep arms the correct next instant a
  /// couple of minutes later.
  static bool isPrayerAlarmId(int alarmId) =>
      alarmId >= prayerAlarmBase &&
      alarmId < prayerAlarmBase + prayerAlarmRange;

  /// Snoozes get their own ID so re-arming a snooze never overwrites the daily
  /// alarm it came from. `snoozeIdFor(alarmId)` maps an alarm into this range.
  static const int snoozeAlarmBase    = 9000;
  static const int snoozeAlarmMax     = 9999;

  static int snoozeIdFor(int alarmId) =>
      snoozeAlarmBase + (alarmId % (snoozeAlarmMax - snoozeAlarmBase + 1));

  static bool isSnoozeId(int alarmId) =>
      alarmId >= snoozeAlarmBase && alarmId <= snoozeAlarmMax;

  // ─── Notification Types ─────────────────────────────────────────────────────
  static const String notifTypeNotification = 'notification';
  static const String notifTypeAlarm        = 'alarm';
  static const String notifTypeBoth         = 'both';
  static const String notifTypeNone         = 'none';

  // ─── Prayer Reminders ───────────────────────────────────────────────────────
  /// Offsets offered as one-tap presets when adding a prayer reminder.
  /// Negative is before the prayer, positive after.
  static const List<int> prayerOffsetPresets = [-30, -20, -15, -10, -5, 0, 5, 10, 15, 20, 30];

  /// Most reminders one prayer may carry. High enough for the
  /// before/at/after pattern several times over, low enough that the ID
  /// budget below cannot be exhausted.
  static const int maxRemindersPerPrayer = 6;

  /// Ceiling across every prayer.
  ///
  /// Sized against Android's cap of ~500 pending notification intents per app,
  /// not against [prayerNotifRange]: a prayer reminder needs one pending
  /// notification per day of `ReminderScheduler.prayerNotificationHorizonDays`,
  /// so 50 reminders already reserve 350 of them — and the other modules need
  /// the rest. Fifty is five reminders on each of the nine listed prayers.
  static const int maxPrayerReminders = 50;

  // ─── Snooze Options (minutes) ───────────────────────────────────────────────
  static const int defaultSnoozeMinutes = 5;
  static const List<int> snoozeOptions  = [5, 10, 15, 30];

  // ─── Medical Record Types ───────────────────────────────────────────────────
  static const String recordBloodPressure = 'blood_pressure';
  static const String recordHeartRate     = 'heart_rate';
  static const String recordOxygenLevel   = 'oxygen_level';
  static const String recordDiabetesLevel = 'diabetes_level';
  static const String recordTemperature   = 'temperature';
  static const String recordWeight        = 'weight';

  static const List<String> medicalRecordTypes = [
    recordBloodPressure,
    recordHeartRate,
    recordOxygenLevel,
    recordDiabetesLevel,
    recordTemperature,
    recordWeight,
  ];

  static const Map<String, String> medicalRecordLabels = {
    recordBloodPressure: 'Blood Pressure',
    recordHeartRate:     'Heart Rate',
    recordOxygenLevel:   'Oxygen Level',
    recordDiabetesLevel: 'Diabetes Level',
    recordTemperature:   'Temperature',
    recordWeight:        'Weight',
  };

  static const Map<String, String> medicalRecordUnits = {
    recordBloodPressure: 'mmHg',
    recordHeartRate:     'bpm',
    recordOxygenLevel:   '%',
    recordDiabetesLevel: 'mg/dL',
    recordTemperature:   '°C',
    recordWeight:        'kg',
  };

  static const Map<String, IconData> medicalRecordIcons = {
    recordBloodPressure: Icons.monitor_heart_outlined,
    recordHeartRate:     Icons.favorite_outline,
    recordOxygenLevel:   Icons.air_outlined,
    recordDiabetesLevel: Icons.water_drop_outlined,
    recordTemperature:   Icons.thermostat_outlined,
    recordWeight:        Icons.fitness_center_outlined,
  };

  // ─── Medical Category Options ────────────────────────────────────────────────
  static const List<String> bloodPressureCategories = [
    'Normal', 'Elevated', 'High Stage 1',
    'High Stage 2', 'Hypertensive Crisis', 'Low',
  ];
  static const List<String> heartRateCategories = [
    'Normal (60–100 bpm)', 'Bradycardia (<60 bpm)', 'Tachycardia (>100 bpm)',
  ];
  static const List<String> oxygenCategories = [
    'Normal (95–100%)', 'Acceptable (90–94%)', 'Low (<90%)',
  ];
  static const List<String> diabetesCategories = [
    'Fasting', 'Post-meal (2hr)', 'Random', 'HbA1c',
  ];
  static const List<String> temperatureCategories = [
    'Normal', 'Low-grade Fever', 'Moderate Fever', 'High Fever', 'Hypothermia',
  ];
  static const List<String> weightCategories = [
    'Morning Weight', 'Evening Weight', 'After Workout', 'After Meal',
  ];

  // ─── Asset Paths ────────────────────────────────────────────────────────────
  static const String alarmAudioPath = 'assets/audio/alarm.mp3';

  /// Where imported alarm sounds are copied to, relative to the app's
  /// documents directory. The `alarm` plugin resolves a relative
  /// `assetAudioPath` against exactly that directory, which is why the stored
  /// path is relative rather than absolute — an absolute one contains a
  /// sandbox id that can change when the app is updated.
  static const String alarmSoundsDirName = 'alarm_sounds';

  /// Extensions the sound picker accepts. `MediaPlayer` handles all of them,
  /// and the list is what stops someone importing a 40 MB video as a chime.
  static const List<String> alarmSoundExtensions = [
    'mp3', 'ogg', 'wav', 'm4a', 'aac', 'flac', 'opus', 'mid', 'midi',
  ];

  /// Ceiling on an imported sound, in bytes. Alarm tones are seconds long;
  /// anything past this is a podcast and would bloat the app's storage.
  static const int maxAlarmSoundBytes = 10 * 1024 * 1024;
}