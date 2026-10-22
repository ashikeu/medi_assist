import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/app_colors.dart';
import '../localization/localized_digits.dart';
import '../constants/app_constants.dart';
import '../services/reminder_scheduler.dart';
import '../utils/time_utils.dart';

/// Full-screen alarm UI shown when an alarm rings while the app is in the
/// foreground. When the app is closed the alarm package's own notification
/// (with its Stop action) handles this instead.
void showAlarmRingingDialog(AlarmSettings alarm) {
  if (Get.isDialogOpen == true) return;
  if (Get.context == null) return;

  final settingsBox = GetStorage(AppConstants.settingsBoxName);
  final snoozeMinutes = settingsBox.read<int>(AppConstants.snoozeMinutesKey) ??
      AppConstants.defaultSnoozeMinutes;

  Get.dialog(
    _AlarmRingingDialog(alarm: alarm, snoozeMinutes: snoozeMinutes),
    barrierDismissible: false,
    barrierColor: Colors.black87,
  );
}

class _AlarmRingingDialog extends StatelessWidget {
  const _AlarmRingingDialog({required this.alarm, required this.snoozeMinutes});

  final AlarmSettings alarm;
  final int snoozeMinutes;

  /// `Alarm.stop` cancels the OS schedule for this ID outright — including the
  /// next day's, which the ringing listener re-armed moments ago. The native
  /// re-arm sweep only runs a couple of minutes after the ring, so stopping
  /// later than that would otherwise cost the user a whole day's reminder.
  Future<void> _rearmDailyReminders() =>
      ReminderScheduler.rescheduleAllFromStorage();

  Future<void> _stop() async {
    await Alarm.stop(alarm.id);
    if (Get.isDialogOpen == true) Get.back();
    await _rearmDailyReminders();
  }

  Future<void> _snooze() => _snoozeUntil(
        DateTime.now().add(Duration(minutes: snoozeMinutes)),
        body: 'alarm_snoozed_body'.trParams({
          'minutes': snoozeMinutes.localizedDigits,
        }),
      );

  /// Opens a time picker and snoozes until the clock time the user chooses.
  ///
  /// A time that has already passed today is taken to mean tomorrow, which is
  /// what someone picking 06:00 at 2am means.
  Future<void> _snoozeUntilPicked(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        now.add(Duration(minutes: snoozeMinutes)),
      ),
      helpText: 'alarm_snooze_until_help'.tr,
    );
    if (picked == null) return;

    var target =
        DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    // Under a minute away is indistinguishable from "now" to the alarm plugin,
    // and re-ringing immediately is not what anyone means by snooze.
    if (target.difference(now).inSeconds < 60) {
      target = target.add(const Duration(days: 1));
    }

    await _snoozeUntil(
      target,
      body: 'alarm_snoozed_until_body'.trParams({
        'time': TimeUtils.formatDateTime(target),
      }),
    );
  }

  Future<void> _snoozeUntil(DateTime when, {required String body}) async {
    await Alarm.stop(alarm.id);

    // Snoozes use a separate ID so re-arming one never overwrites the daily
    // alarm, which is already scheduled for tomorrow under the original ID.
    final snoozeId = AppConstants.isSnoozeId(alarm.id)
        ? alarm.id
        : AppConstants.snoozeIdFor(alarm.id);

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: snoozeId,
        dateTime: when,
        // Whatever the original alarm was set to play, including a sound the
        // user imported — carried across rather than re-resolved, so a snooze
        // always sounds like the alarm it came from.
        assetAudioPath: alarm.assetAudioPath,
        loopAudio: false,
        vibrate: alarm.vibrate,
        volumeSettings: VolumeSettings.fade(
          volume: 0.7,
          fadeDuration: const Duration(seconds: 2),
        ),
        warningNotificationOnKill: alarm.warningNotificationOnKill,
        androidFullScreenIntent: false,
        notificationSettings: NotificationSettings(
          title: '⏱️ ${'alarm_snoozed_title'.trParams({
            'title': alarm.notificationSettings.title,
          })}',
          body: body,
          stopButton: 'alarm_cancel_snooze'.tr,
          icon: 'notification_icon',
        ),
      ),
    );

    if (Get.isDialogOpen == true) Get.back();
    debugPrint('⏱️ Alarm ${alarm.id} snoozed until $when as $snoozeId');

    // The stop above took the daily schedule with it; the snooze lives in its
    // own ID range and is untouched by this.
    await _rearmDailyReminders();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.all(24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.15),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                alarm.notificationSettings.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                alarm.notificationSettings.body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.alarm_off_rounded),
                  label: Text(
                    'alarm_stop'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _snooze,
                  icon: const Icon(Icons.snooze_rounded),
                  label: Text(
                    'alarm_snooze'.trParams({
                      'minutes': snoozeMinutes.localizedDigits,
                    }),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // The fixed snooze above covers "a few more minutes"; this is for
              // when the user knows exactly when they want to be asked again.
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _snoozeUntilPicked(context),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    'alarm_snooze_until'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
