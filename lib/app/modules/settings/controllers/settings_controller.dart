import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/alarm_sound_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/prayer_service.dart';
import '../../../../core/services/reminder_scheduler.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_locales.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../models/alarm_sound_model.dart';
import '../../activity/controllers/activity_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../meal/controllers/meal_controller.dart';
import '../../medical_records/controllers/medical_records_controller.dart';
import '../../medicine/controllers/medicine_controller.dart';

class SettingsController extends GetxController {
  static SettingsController get to => Get.find();

  // ─── Observable state ────────────────────────────────────────────────────────
  final RxBool isLoadingPermissions  = false.obs;
  final RxMap<String, bool> permissionStatus = <String, bool>{}.obs;
  final RxInt  pendingNotifCount     = 0.obs;
  // ✅ Persisted snooze preference
  final RxInt  snoozeMinutes         = AppConstants.defaultSnoozeMinutes.obs;

  /// Language tag currently in effect, e.g. `bn_BD`.
  ///
  /// `Get.locale` is the real source of truth; this mirrors it so the picker
  /// can repaint its tick the instant a row is tapped.
  final RxString languageTag = AppLocales.fallback.tag.obs;

  /// The prayer location, as the Settings row shows it. Mirrored into an
  /// observable so the row updates the moment the user picks somewhere new
  /// and comes back, without this screen having to be rebuilt from scratch.
  final RxString prayerLocationLabel = ''.obs;

  /// The app-wide default alarm sound, as an observable the picker row can
  /// drive directly. It is never null here — this *is* the default, so it has
  /// nothing to inherit from.
  final Rx<AlarmSound?> defaultAlarmSound = Rx<AlarmSound?>(null);

  // ─── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadPersistedSettings();
    _loadStatus();
  }

  // ─── Load persisted settings from storage on every open ──────────────────────
  // ✅ This ensures settings are NEVER reset — always loaded from persistent storage
  void _loadPersistedSettings() {
    snoozeMinutes.value = StorageService.to.snoozeMinutes;
    languageTag.value = AppLocales.current.tag;
    prayerLocationLabel.value = PrayerService.to.location.displayName;
    defaultAlarmSound.value = AlarmSoundService.to.defaultSound;
    // Restore any other persisted settings here
  }

  // ─── Alarm sound ─────────────────────────────────────────────────────────────
  /// Changes the sound every reminder that has not chosen its own will play.
  ///
  /// Already-scheduled alarms carry the old sound baked in — both in the OS
  /// schedule and in the native re-arm mirror — so they have to be re-armed,
  /// the same reason a language change reschedules everything.
  Future<void> setDefaultAlarmSound(AlarmSound? sound) async {
    final chosen = sound ?? AlarmSound.appDefault;
    defaultAlarmSound.value = chosen;
    await AlarmSoundService.to.setDefaultSound(chosen);
    await ReminderScheduler.rescheduleAllFromStorage();
    AppUtils.showSuccess(
      'alarm_sound_default_changed'.trParams({'sound': chosen.displayLabel}),
    );
  }

  @override
  void onReady() {
    super.onReady();
    // The location screen is reached from here, so refresh the row's label
    // when this screen becomes visible again.
    ever<int>(PrayerService.to.revision, (_) {
      prayerLocationLabel.value = PrayerService.to.location.displayName;
    });
  }

  // ─── Language ────────────────────────────────────────────────────────────────
  /// Switches the app's language and persists the choice.
  ///
  /// Takes effect immediately: `AppLocales.change` calls `Get.updateLocale`,
  /// which rebuilds every screen, so there is nothing for the user to restart.
  Future<void> changeLanguage(AppLanguage language) async {
    if (languageTag.value == language.tag) return;

    await AppLocales.change(language);
    languageTag.value = language.tag;

    // The screens repaint themselves, but two things live outside the widget
    // tree and would otherwise stay in the old language indefinitely:
    //
    //  * the Android notification channels, whose names and descriptions the
    //    user sees in system Settings;
    //  * every already-scheduled reminder, whose title and body were baked in
    //    when it was scheduled — including the copy mirrored to the native
    //    re-arm store, which is what keeps alarms repeating while the app is
    //    closed.
    await NotificationService.refreshChannels();
    await ReminderScheduler.rescheduleAllFromStorage();

    // Read after the switch, so the confirmation itself is already in the new
    // language — the first proof to the user that it worked.
    AppUtils.showSuccess(
      'settings_language_changed'.trParams({'language': language.name}),
    );
  }

  Future<void> _loadStatus() async {
    await refreshPermissions();
    await loadPendingNotifications();
  }

  // ─── Permissions ─────────────────────────────────────────────────────────────
  Future<void> refreshPermissions() async {
    isLoadingPermissions.value = true;
    try {
      final status = await PermissionService.to.checkAllPermissions();
      permissionStatus.assignAll(status);
    } finally {
      isLoadingPermissions.value = false;
    }
  }

  Future<void> requestAllPermissions() async {
    await PermissionService.to.requestAllPermissions();
    await StorageService.to.setPermissionAsked();
    await refreshPermissions();
  }

  Future<void> openBatterySettings() async {
    await PermissionService.to.requestBatteryOptimizationPermission();
    await refreshPermissions();
  }

  Future<void> openAlarmSettings() async {
    await PermissionService.to.requestExactAlarmPermission();
    await refreshPermissions();
  }

  // ─── Snooze duration ─────────────────────────────────────────────────────────
  Future<void> setSnoozeMinutes(int minutes) async {
    snoozeMinutes.value = minutes;
    // ✅ Persist immediately — won't reset on app restart
    await StorageService.to.setSnoozeMinutes(minutes);
    AppUtils.showSuccess('settings_snooze_duration'.trParams({'minutes': minutes.localizedDigits}));
  }

  // ─── Test notification ────────────────────────────────────────────────────────
  Future<void> sendTestNotification() async {
    await NotificationService.to.showImmediateNotification(
      id: 9999,
      title: '🔔 ${'settings_test_notification_title'.tr}',
      body: 'settings_test_notification_body'.tr,
      channelId: AppConstants.medicineChannelId,
      channelName: AppConstants.medicineChannelName,
      payload: 'test',
    );
    AppUtils.showSuccess('settings_test_notification_sent'.tr);
  }

  // ─── Pending notifications ────────────────────────────────────────────────────
  Future<void> loadPendingNotifications() async {
    final pending = await NotificationService.to.getPending();
    pendingNotifCount.value = pending.length;
  }

  // ─── Reschedule all ───────────────────────────────────────────────────────────
  Future<void> rescheduleAll() async {
    try {
      final medicines  = StorageService.to.getMedicines();
      final meals      = StorageService.to.getMeals();
      final activities = StorageService.to.getActivities();

      await ReminderScheduler.rescheduleAll(
        medicines:  medicines,
        meals:      meals,
        activities: activities,
      );

      // ✅ Update last reschedule timestamp
      await StorageService.to.setLastRescheduleDate(DateTime.now());

      await loadPendingNotifications();
      AppUtils.showSuccess('settings_reschedule_success'.tr);
    } catch (e) {
      AppUtils.showError('settings_reschedule_failed'.tr);
    }
  }

  // ─── Clear all data ───────────────────────────────────────────────────────────
  Future<void> clearAllData() async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'settings_clear_data'.tr,
      message: 'settings_clear_data_message'.tr,
      confirmText: 'settings_clear_data_button'.tr,
      cancelText: 'cancel'.tr,
      confirmColor: Colors.red,
      icon: Icons.warning_amber_rounded,
    );

    if (!confirmed) return;

    try {
      // Must cancel alarms too, not just notifications. The entities are about
      // to be deleted, so anything left scheduled would keep ringing daily with
      // no UI left to turn it off.
      await ReminderScheduler.cancelEverything();

      // ✅ clearAllData() only clears user data, NOT settings
      await StorageService.to.clearAllData();

      await loadPendingNotifications();
      AppUtils.showSuccess(
        'settings_data_cleared_detail'.tr,
        title: 'settings_data_cleared'.tr,
      );
    } catch (e) {
      AppUtils.showError('settings_clear_data_failed'.tr);
    }
  }

  // ─── Export Backup ────────────────────────────────────────────────────────────
  Future<void> exportBackup() async {
    final result = await BackupService.to.exportData();
    switch (result) {
      case BackupResult.success:
        AppUtils.showSuccess('settings_export_success'.tr);
      case BackupResult.cancelled:
        break;
      case BackupResult.failed:
        AppUtils.showError('settings_export_failed'.tr);
    }
  }

  // ─── Import Backup ────────────────────────────────────────────────────────────
  Future<void> importBackup() async {
    final result = await BackupService.to.importData();
    switch (result) {
      case BackupResult.success:
        _reloadLiveControllers();
        await loadPendingNotifications();
        AppUtils.showSuccess(
          'settings_import_success'.tr,
          title: 'settings_import_complete'.tr,
        );
      case BackupResult.cancelled:
        break;
      case BackupResult.failed:
        AppUtils.showError('settings_import_failed'.tr);
    }
  }

  /// Refreshes whichever list controllers are currently alive so restored data
  /// shows immediately, instead of telling the user to restart the app.
  void _reloadLiveControllers() {
    if (Get.isRegistered<MedicineController>()) {
      MedicineController.to.loadMedicines();
    }
    if (Get.isRegistered<MealController>()) {
      MealController.to.loadMeals();
    }
    if (Get.isRegistered<ActivityController>()) {
      ActivityController.to.loadActivities();
    }
    if (Get.isRegistered<MedicalRecordsController>()) {
      MedicalRecordsController.to.loadAllRecords();
    }
    if (Get.isRegistered<HomeController>()) {
      HomeController.to.refreshCounts();
    }
  }
}