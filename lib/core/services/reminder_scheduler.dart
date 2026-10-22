import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../models/medicine_model.dart';
import '../../models/meal_model.dart';
import '../../models/activity_model.dart';
import '../../models/prayer_reminder_model.dart';
import '../constants/app_constants.dart';
import '../localization/localized_digits.dart';
import 'alarm_service.dart';
import 'notification_service.dart';
import 'prayer_service.dart';
import 'storage_service.dart';

/// Central scheduler — single entry point for all reminder scheduling.
/// Routes each item to notification/alarm/both based on notificationType.
/// All methods are safe to call multiple times (cancel-before-reschedule pattern).
class ReminderScheduler {
  ReminderScheduler._();

  /// A medicine can hold at most this many reminder times. The notification and
  /// alarm ID for slot `i` is `base + i`, and bases are spaced 10 apart, so
  /// allowing an 11th time would collide with the next medicine's block.
  static const int maxMedicineTimes = 10;

  // ════════════════════════════════════════════════════════════════
  // ─── MEDICINE ────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  static Future<void> scheduleMedicine(Medicine medicine) async {
    // Always cancel existing first — prevents duplicate reminders
    await cancelMedicine(medicine);

    if (!medicine.isActive) return;
    if (medicine.notificationType == AppConstants.notifTypeNone) return;
    if (medicine.times.isEmpty) return;

    final notifBaseId = _medicineNotifBase(medicine.id);
    final alarmBaseId = _medicineAlarmBase(medicine.id);
    final type = medicine.notificationType;

    try {
      if (type == AppConstants.notifTypeNotification ||
          type == AppConstants.notifTypeBoth) {
        await NotificationService.to.scheduleMedicineNotifications(
          medicineId: medicine.id,
          medicineName: medicine.name,
          times: medicine.times,
          baseId: notifBaseId,
        );
      }

      if (type == AppConstants.notifTypeAlarm ||
          type == AppConstants.notifTypeBoth) {
        await AlarmService.to.scheduleMedicineAlarms(
          medicineId: medicine.id,
          medicineName: medicine.name,
          times: medicine.times,
          baseAlarmId: alarmBaseId,
          sound: medicine.alarmSound,
        );
      }

      debugPrint(
          '✅ Medicine "${medicine.name}" scheduled ($type, ${medicine.times.length} time(s))');
    } catch (e) {
      debugPrint('❌ Failed to schedule medicine "${medicine.name}": $e');
    }
  }

  static Future<void> cancelMedicine(Medicine medicine) async {
    try {
      await NotificationService.to.cancelMedicineNotifications(
        medicineId: medicine.id,
        times: medicine.times,
        baseId: _medicineNotifBase(medicine.id),
      );
      await AlarmService.to.cancelMedicineAlarms(
        times: medicine.times,
        baseAlarmId: _medicineAlarmBase(medicine.id),
      );
    } catch (e) {
      debugPrint('⚠️ Cancel medicine warning: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ─── MEAL ────────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  static Future<void> scheduleMeal(Meal meal) async {
    await cancelMeal(meal);

    if (!meal.isActive) return;
    if (meal.notificationType == AppConstants.notifTypeNone) return;

    final notifId = _mealNotifId(meal.id);
    final alarmId = _mealAlarmId(meal.id);
    final type = meal.notificationType;

    try {
      if (type == AppConstants.notifTypeNotification ||
          type == AppConstants.notifTypeBoth) {
        await NotificationService.to.scheduleMealNotification(
          mealId: meal.id,
          mealName: meal.name,
          time: meal.time,
          notifId: notifId,
        );
      }

      if (type == AppConstants.notifTypeAlarm ||
          type == AppConstants.notifTypeBoth) {
        await AlarmService.to.scheduleMealAlarm(
          mealId: meal.id,
          mealName: meal.name,
          time: meal.time,
          alarmId: alarmId,
          sound: meal.alarmSound,
        );
      }

      debugPrint('✅ Meal "${meal.name}" scheduled ($type)');
    } catch (e) {
      debugPrint('❌ Failed to schedule meal "${meal.name}": $e');
    }
  }

  static Future<void> cancelMeal(Meal meal) async {
    try {
      await NotificationService.to.cancelNotification(_mealNotifId(meal.id));
      await AlarmService.to.cancelAlarm(_mealAlarmId(meal.id));
    } catch (e) {
      debugPrint('⚠️ Cancel meal warning: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ─── ACTIVITY ────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  static Future<void> scheduleActivity(Activity activity) async {
    await cancelActivity(activity);

    if (!activity.isActive) return;
    if (activity.notificationType == AppConstants.notifTypeNone) return;

    final notifId = _activityNotifId(activity.id);
    final alarmId = _activityAlarmId(activity.id);
    final type = activity.notificationType;

    try {
      if (type == AppConstants.notifTypeNotification ||
          type == AppConstants.notifTypeBoth) {
        await NotificationService.to.scheduleActivityNotification(
          activityId: activity.id,
          activityName: activity.name,
          time: activity.time,
          notifId: notifId,
        );
      }

      if (type == AppConstants.notifTypeAlarm ||
          type == AppConstants.notifTypeBoth) {
        await AlarmService.to.scheduleActivityAlarm(
          activityId: activity.id,
          activityName: activity.name,
          time: activity.time,
          alarmId: alarmId,
          sound: activity.alarmSound,
        );
      }

      debugPrint('✅ Activity "${activity.name}" scheduled ($type)');
    } catch (e) {
      debugPrint('❌ Failed to schedule activity "${activity.name}": $e');
    }
  }

  static Future<void> cancelActivity(Activity activity) async {
    try {
      await NotificationService.to
          .cancelNotification(_activityNotifId(activity.id));
      await AlarmService.to.cancelAlarm(_activityAlarmId(activity.id));
    } catch (e) {
      debugPrint('⚠️ Cancel activity warning: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ─── PRAYER ──────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  //
  // Every other module schedules one daily-repeating reminder per item,
  // because its time is a fixed hour and minute. Prayer times are not: they
  // move by a minute or two every day and depend on the location and the
  // calculation method. So the prayer module schedules a rolling *horizon* of
  // one-off firings and refills it whenever the app runs — which is on every
  // launch and every resume, via `rescheduleAllFromStorage`.

  /// How many days of one-off notifications are kept armed.
  ///
  /// Short, because each day costs its own notification ID and Android caps
  /// how many a single app may have pending. Anyone who opens the app even
  /// once a week never notices the edge.
  static const int prayerNotificationHorizonDays = 7;

  /// How many days of alarm firings are pushed to the native store.
  ///
  /// Much longer, because those cost one stored timestamp each and only ever
  /// one outstanding OS alarm — the native sweep arms them one at a time. A
  /// phone whose owner does not open the app for a month still gets the adhan.
  static const int prayerAlarmHorizonDays = 45;

  /// Re-arms every prayer reminder from storage.
  ///
  /// Cancel-before-schedule like the rest of the module, but the cancel side
  /// works off the slot count persisted by the previous run rather than the
  /// current reminder list: a reminder that has since been deleted is not in
  /// the list any more, and its notifications would otherwise keep firing.
  static Future<void> schedulePrayerReminders() async {
    final storage = StorageService.to;

    await _cancelPrayerSlots(storage.prayerSlotCount);

    if (!storage.isPrayerModuleEnabled) {
      await storage.setPrayerSlotCount(0);
      debugPrint('🕌 Prayer module disabled — reminders cleared');
      return;
    }

    final active = storage
        .getPrayerReminders()
        .where((r) =>
            r.isActive && r.notificationType != AppConstants.notifTypeNone)
        .take(AppConstants.maxPrayerReminders)
        .toList();

    if (active.isEmpty) {
      await storage.setPrayerSlotCount(0);
      return;
    }

    final prayer = PrayerService.to;
    final today = prayer.currentDate;
    final now = DateTime.now().toUtc();

    for (var slot = 0; slot < active.length; slot++) {
      final reminder = active[slot];
      final name = prayer.targetName(reminder.prayerId);
      final title = _prayerTitle(reminder);
      final body = _prayerBody(reminder, name);

      final alarmTimes = <DateTime>[];

      for (var day = 0; day < prayerAlarmHorizonDays; day++) {
        final date = today.add(Duration(days: day));

        final DateTime? fire;
        final exact = reminder.exactTime;
        if (exact != null) {
          // A fixed clock time is read on the *location's* clock, not the
          // phone's, so it stays put for a user checking another city — and it
          // needs no prayer time at all, which is why this branch comes first.
          fire = prayer.instantFromWallClock(
            DateTime(date.year, date.month, date.day, exact.hour, exact.minute),
          );
        } else {
          final target = prayer.targetInstant(reminder.prayerId, date);
          // Polar latitudes, or a custom entry whose anchor has no time that
          // day: skip the day rather than guessing at one.
          if (target == null) continue;
          fire = reminder.fireTimeFor(target);
        }

        if (!fire.isAfter(now)) continue;

        if (reminder.usesAlarm) alarmTimes.add(fire);

        if (reminder.usesNotification &&
            day < prayerNotificationHorizonDays) {
          final channel = AppConstants.prayerChannelFor(
            playSound: reminder.playSound,
            vibrate: reminder.vibrate,
          );
          await NotificationService.to.scheduleOneShotNotification(
            id: _prayerNotifId(slot, day),
            title: title,
            body: body,
            when: fire.toLocal(),
            channelId: channel.id,
            channelName: channel.name,
            payload: 'prayer_${reminder.prayerId}',
          );
        }
      }

      if (reminder.usesAlarm) {
        await AlarmService.to.scheduleDatedAlarm(
          alarmId: _prayerAlarmId(slot),
          title: title,
          body: body,
          times: alarmTimes,
          loopAudio: reminder.loopAudio,
          vibrate: reminder.vibrate,
          sound: reminder.alarmSound,
        );
      }
    }

    await storage.setPrayerSlotCount(active.length);
    debugPrint('🕌 Prayer reminders scheduled — ${active.length} reminder(s)');
  }

  /// Clears the notification and alarm IDs belonging to the first [count]
  /// slots. Safe to call with a count larger than what is currently in use.
  static Future<void> _cancelPrayerSlots(int count) async {
    if (count <= 0) return;
    final capped = count.clamp(0, AppConstants.maxPrayerReminders);
    for (var slot = 0; slot < capped; slot++) {
      for (var day = 0; day < prayerNotificationHorizonDays; day++) {
        try {
          await NotificationService.to
              .cancelNotification(_prayerNotifId(slot, day));
        } catch (e) {
          debugPrint('⚠️ Cancel prayer notification warning: $e');
        }
      }
      try {
        await AlarmService.to.cancelAlarm(_prayerAlarmId(slot));
      } catch (e) {
        debugPrint('⚠️ Cancel prayer alarm warning: $e');
      }
    }
  }

  /// Cancels every prayer reminder without touching the stored reminders —
  /// used when the module is switched off.
  static Future<void> cancelAllPrayerReminders() async {
    final storage = StorageService.to;
    await _cancelPrayerSlots(storage.prayerSlotCount);
    await storage.setPrayerSlotCount(0);
  }

  static String _prayerTitle(PrayerReminder reminder) {
    final custom = reminder.title?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return '🕌 ${'notif_prayer_title'.tr}';
  }

  static String _prayerBody(PrayerReminder reminder, String prayerName) {
    final custom = reminder.message?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    // An exact-time reminder is not "before" or "after" anything, so the
    // offset wording would be a lie. It names the prayer and leaves it there.
    if (reminder.usesExactTime) {
      return 'prayer_reminder_exact'.trParams({'prayer': prayerName});
    }

    final minutes = reminder.offsetMinutes.abs().localizedDigits;
    if (reminder.isAtPrayerTime) {
      return 'prayer_reminder_now'.trParams({'prayer': prayerName});
    }
    if (reminder.isBefore) {
      return 'prayer_reminder_before'
          .trParams({'prayer': prayerName, 'minutes': minutes});
    }
    return 'prayer_reminder_after'
        .trParams({'prayer': prayerName, 'minutes': minutes});
  }

  // ════════════════════════════════════════════════════════════════
  // ─── RESCHEDULE ALL ──────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  static Future<void> rescheduleAll({
    required List<Medicine> medicines,
    required List<Meal> meals,
    required List<Activity> activities,
  }) async {
    debugPrint(
        '🔄 Rescheduling all — medicines:${medicines.length} meals:${meals.length} activities:${activities.length}');

    int successCount = 0;
    int failCount = 0;

    for (final m in medicines) {
      try {
        await scheduleMedicine(m);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }
    for (final m in meals) {
      try {
        await scheduleMeal(m);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }
    for (final a in activities) {
      try {
        await scheduleActivity(a);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    // Prayer reminders come from storage rather than being passed in: they are
    // derived from the location and calculation settings, not from a list the
    // caller holds.
    try {
      await schedulePrayerReminders();
    } catch (e) {
      debugPrint('⚠️ Prayer reminder scheduling warning: $e');
    }

    // Point the native re-arm sweep at whatever is now the earliest alarm. The
    // per-alarm mirror writes above already happened; this only moves the
    // wake-up that keeps them repeating once the app is gone.
    await AlarmService.to.syncDailySpecs();

    debugPrint(
        '✅ Reschedule complete — $successCount succeeded, $failCount failed');
  }

  // ════════════════════════════════════════════════════════════════
  // ─── RESCHEDULE FROM STORAGE ─────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  /// Re-arms every reminder from what is currently in storage.
  ///
  /// This is the app's safety net now that there is no polling service: it runs
  /// on launch and on resume. Scheduling is cancel-before-set and therefore
  /// idempotent, so calling it repeatedly is cheap and cannot double-fire.
  static Future<void> rescheduleAllFromStorage() async {
    final storage = StorageService.to;
    await rescheduleAll(
      medicines: storage.getMedicines(),
      meals: storage.getMeals(),
      activities: storage.getActivities(),
    );
  }

  /// Cancels every reminder this app owns, including ones whose backing entity
  /// has already been deleted.
  ///
  /// Needed because "Clear all data" wipes the entities first; without this the
  /// alarms they scheduled keep ringing daily with no UI left to stop them.
  static Future<void> cancelEverything() async {
    try {
      await NotificationService.to.cancelAll();
    } catch (e) {
      debugPrint('⚠️ Cancel all notifications warning: $e');
    }
    try {
      for (final alarm in await Alarm.getAlarms()) {
        await Alarm.stop(alarm.id);
      }
      // Wipe the native mirror as well — the re-arm sweep reads from it, not
      // from the plugin, so leaving it populated would bring every alarm back
      // tomorrow.
      await AlarmService.to.clearDailySpecs();
    } catch (e) {
      debugPrint('⚠️ Cancel all alarms warning: $e');
    }
    // The slot count is what the next run cancels against. Leaving it set
    // after everything has already been cancelled is harmless but misleading;
    // leaving it set after a *partial* failure above would be worse.
    try {
      await StorageService.to.setPrayerSlotCount(0);
    } catch (e) {
      debugPrint('⚠️ Prayer slot reset warning: $e');
    }
    debugPrint('🗑️ All reminders cancelled');
  }

  // ════════════════════════════════════════════════════════════════
  // ─── ID HELPERS ──────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  //
  // These are the single source of truth for reminder IDs. Anything that needs
  // to address a scheduled reminder must go through them — a second copy of the
  // arithmetic elsewhere silently produces a different ID for the same entity,
  // which shows up as duplicate notifications rather than an error.

  static int _medicineNotifBase(String id) =>
      AppConstants.medicineNotifBase + (id.hashCode.abs() % 100) * 10;

  static int _medicineAlarmBase(String id) =>
      AppConstants.medicineAlarmBase + (id.hashCode.abs() % 100) * 10;

  static int _mealNotifId(String id) =>
      AppConstants.mealNotifBase + (id.hashCode.abs() % 1000);

  static int _mealAlarmId(String id) =>
      AppConstants.mealAlarmBase + (id.hashCode.abs() % 1000);

  static int _activityNotifId(String id) =>
      AppConstants.activityNotifBase + (id.hashCode.abs() % 1000);

  static int _activityAlarmId(String id) =>
      AppConstants.activityAlarmBase + (id.hashCode.abs() % 1000);

  // Prayer IDs are indexed by *slot* — the reminder's position in the stored
  // list at the moment it was scheduled — rather than hashed from its id.
  //
  // Hashing would collide: two reminders landing on the same ID would
  // silently overwrite each other, and unlike a medicine there is no natural
  // per-entity spacing to hash into. Slots are dense and deterministic, and
  // `prayerSlotCount` in the settings box records how many were in use so the
  // next run knows exactly what to cancel.
  //
  // A notification ID also carries the day, because each day of the horizon is
  // its own one-off firing.

  static int _prayerNotifId(int slot, int dayOffset) =>
      AppConstants.prayerNotifBase +
      (slot * prayerNotificationHorizonDays) +
      dayOffset;

  static int _prayerAlarmId(int slot) => AppConstants.prayerAlarmBase + slot;
}