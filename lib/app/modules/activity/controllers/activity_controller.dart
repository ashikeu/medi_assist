import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/services/reminder_scheduler.dart';
import 'package:medi_assist/core/services/storage_service.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/core/utils/id_generator.dart';
import 'package:medi_assist/models/alarm_sound_model.dart';
import 'package:medi_assist/models/activity_model.dart';


class ActivityController extends GetxController {
  static ActivityController get to => Get.find();

  final RxList<Activity> activities = <Activity>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  // ✅ RxInt — safe inside Obx
  final RxInt activeActivitiesCount = 0.obs;
  // ✅ RxString mirror of nameController — used in suggestion chips Obx
  final RxString nameInputRx = ''.obs;

  final nameController = TextEditingController();
  final Rx<TimeOfDay> selectedTime = const TimeOfDay(hour: 7, minute: 0).obs;
  final RxString selectedNotifType = AppConstants.notifTypeNotification.obs;

  /// The alarm sound for the item being edited. `null` means the reminder
  /// follows the app-wide default, which is what an untouched form leaves it
  /// as.
  final Rx<AlarmSound?> selectedAlarmSound = Rx<AlarmSound?>(null);
  final RxBool isActive = true.obs;
  Activity? editingActivity;

  List<Activity> get filteredActivities {
    if (searchQuery.value.isEmpty) return activities;
    return activities
        .where((a) =>
            a.name.toLowerCase().contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    // ✅ Mirror TextEditingController changes to RxString
    nameController.addListener(() {
      nameInputRx.value = nameController.text;
    });
    loadActivities();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  void _refreshCounts() {
    activeActivitiesCount.value =
        activities.where((a) => a.isActive).length;
  }

  void loadActivities() {
    isLoading.value = true;
    try {
      final data = StorageService.to.getActivities();
      activities.assignAll(data);
      _refreshCounts();
    } catch (e) {
      AppUtils.showError('failed_load_activities'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addActivity() async {
    if (!_validateForm()) return;
    isLoading.value = true;
    try {
      final activity = Activity(
        id: IdGenerator.generate(),
        name: nameController.text.trim(),
        time: selectedTime.value,
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
      );
      await StorageService.to.addActivity(activity);
      activities.add(activity);
      _refreshCounts();
      if (activity.isActive) {
        await ReminderScheduler.scheduleActivity(activity);
      }
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'activity_added'.tr,
        message: 'item_reminder_added'.trParams({'name': activity.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_add_activity'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateActivity() async {
    if (editingActivity == null || !_validateForm()) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelActivity(editingActivity!);
      final updated = editingActivity!.copyWith(
        name: nameController.text.trim(),
        time: selectedTime.value,
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
        clearAlarmSound: selectedAlarmSound.value == null,
      );
      await StorageService.to.updateActivity(updated);
      final idx = activities.indexWhere((a) => a.id == updated.id);
      if (idx != -1) activities[idx] = updated;
      _refreshCounts();
      if (updated.isActive) {
        await ReminderScheduler.scheduleActivity(updated);
      }
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'activity_updated'.tr,
        message: 'item_updated'.trParams({'name': updated.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_update_activity'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteActivity(Activity activity) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'activity_delete_title'.tr,
      message: 'delete_confirm_message'.trParams({'name': activity.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelActivity(activity);
      await StorageService.to.deleteActivity(activity.id);
      activities.removeWhere((a) => a.id == activity.id);
      _refreshCounts();
      AppUtils.showSuccess(
        'item_deleted'.trParams({'name': activity.name}),
        title: 'deleted'.tr,
      );
    } catch (e) {
      AppUtils.showError('failed_delete_activity'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleActive(Activity activity) async {
    try {
      final updated = activity.copyWith(isActive: !activity.isActive);
      await StorageService.to.updateActivity(updated);
      final idx = activities.indexWhere((a) => a.id == activity.id);
      if (idx != -1) activities[idx] = updated;
      _refreshCounts();
      if (updated.isActive) {
        await ReminderScheduler.scheduleActivity(updated);
        AppUtils.showInfo('item_reminders_enabled'.trParams({'name': updated.name}));
      } else {
        await ReminderScheduler.cancelActivity(updated);
        AppUtils.showInfo('item_reminders_paused'.trParams({'name': updated.name}));
      }
    } catch (e) {
      AppUtils.showError('failed_update_activity_status'.tr);
    }
  }

  void prepareForAdd() {
    editingActivity = null;
    _resetForm();
  }

  void prepareForEdit(Activity activity) {
    editingActivity = activity;
    nameController.text = activity.name;
    nameInputRx.value = activity.name;
    selectedTime.value = activity.time;
    selectedNotifType.value = activity.notificationType;
    selectedAlarmSound.value = activity.alarmSound;
    isActive.value = activity.isActive;
  }

  void setTime(TimeOfDay time) => selectedTime.value = time;
  void setNotifType(String type) => selectedNotifType.value = type;

  bool _validateForm() {
    if (nameController.text.trim().isEmpty) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'activity_name_required'.tr,
      );
      return false;
    }
    if (nameController.text.trim().length < 2) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'activity_name_too_short'.tr,
      );
      return false;
    }
    return true;
  }

  void _resetForm() {
    nameController.clear();
    nameInputRx.value = '';
    selectedTime.value = const TimeOfDay(hour: 7, minute: 0);
    selectedNotifType.value = AppConstants.notifTypeNotification;
    selectedAlarmSound.value = null;
    isActive.value = true;
    editingActivity = null;
  }

  void setSearchQuery(String query) => searchQuery.value = query;
  void clearSearch() => searchQuery.value = '';
}