import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_locales.dart';
import 'core/localization/app_translations.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/alarm_ringing_dialog.dart';

// ─── Alarm stream subscription (top-level — survives navigation) ─────────────
StreamSubscription<AlarmSet>? _alarmRingingSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Android 15 forces edge-to-edge for targetSdk 35 regardless of what we ask
  // for. Opting in explicitly means every Android version renders the same way,
  // instead of only Android 15+ users seeing content behind the system bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // ── Init BOTH storage boxes (data + settings) ──────────────────────────────
  await GetStorage.init();
  await GetStorage.init(AppConstants.settingsBoxName);

  // ── Language ───────────────────────────────────────────────────────────────
  // GetX only registers translations and sets `Get.locale` inside
  // GetMaterialApp's initState, and `.tr` returns the raw key until it does.
  // Everything below this line runs before that — `NotificationService`
  // creates its notification channels during `initialize()`, and those names
  // are what the user sees in Android's own settings. Seeding GetX here means
  // `.tr` is usable from this point on; GetMaterialApp later sets the same
  // values again, so nothing conflicts.
  Get.addTranslations(AppTranslations().keys);
  Get.locale = AppLocales.initial.locale;
  Get.fallbackLocale = AppLocales.fallback.locale;

  // ── Notifications (also resolves the device timezone) ──────────────────────
  await NotificationService.initialize();

  // ── Alarm package ──────────────────────────────────────────────────────────
  await Alarm.init();

  // ── Alarm ringing listener ─────────────────────────────────────────────────
  _setupAlarmRingingListener();

  runApp(const MediAssistApp());
}

// ─── Alarm ringing listener ───────────────────────────────────────────────────
void _setupAlarmRingingListener() {
  _alarmRingingSubscription?.cancel();
  _alarmRingingSubscription = Alarm.ringing.listen((AlarmSet alarmSet) {
    debugPrint(
        '🔔 Alarm(s) ringing: ${alarmSet.alarms.map((a) => a.id).toList()}');
    for (final alarmSettings in alarmSet.alarms) {
      _rescheduleAlarmForNextDay(alarmSettings);
      showAlarmRingingDialog(alarmSettings);
    }
  });
}

// ─── Reschedule for next day ──────────────────────────────────────────────────
/// Rolls a fired alarm forward while the app happens to be running.
///
/// This is only a fast path. The authoritative daily repeat lives in
/// `DailyAlarmRearmReceiver` on the Android side, because this listener cannot
/// run at all once the app is killed — and even here it is undone a moment
/// later when the user taps Stop, which cancels the alarm ID this just re-armed.
/// The native sweep repairs both cases a couple of minutes after the ring.
Future<void> _rescheduleAlarmForNextDay(AlarmSettings fired) async {
  // A snooze is a one-off copy of a daily alarm. Rolling it forward would move
  // the daily reminder permanently later by the snooze duration; the original
  // alarm ID has already been re-armed for tomorrow, so there is nothing to do.
  if (AppConstants.isSnoozeId(fired.id)) {
    debugPrint('⏱️ Snooze ${fired.id} fired — daily alarm already armed');
    return;
  }

  // Prayer times move every day, so "same time tomorrow" would be wrong. Their
  // next firing is already stored natively and the re-arm sweep picks it up
  // shortly after this ring.
  if (AppConstants.isPrayerAlarmId(fired.id)) {
    debugPrint('🕌 Prayer alarm ${fired.id} fired — next firing is stored '
        'natively, leaving it to the re-arm sweep');
    return;
  }

  try {
    var nextTime = fired.dateTime.add(const Duration(days: 1));
    // Guard against a stale schedule (device was off, alarm fired late).
    final now = DateTime.now();
    while (nextTime.isBefore(now)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: fired.id,
        dateTime: nextTime,
        assetAudioPath: fired.assetAudioPath,
        loopAudio: fired.loopAudio,
        vibrate: fired.vibrate,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 3),
        ),
        warningNotificationOnKill: fired.warningNotificationOnKill,
        androidFullScreenIntent: fired.androidFullScreenIntent,
        androidStopAlarmOnTermination: fired.androidStopAlarmOnTermination,
        notificationSettings: fired.notificationSettings,
      ),
    );
    debugPrint('✅ Alarm ${fired.id} rescheduled → $nextTime');
  } catch (e) {
    debugPrint('❌ Failed to reschedule alarm ${fired.id}: $e');
  }
}
