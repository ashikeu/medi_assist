import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/services/reminder_scheduler.dart';
import 'package:medi_assist/core/services/storage_service.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/core/utils/id_generator.dart';
import 'package:medi_assist/models/alarm_sound_model.dart';
import 'package:medi_assist/models/meal_model.dart';


class MealController extends GetxController {
  static MealController get to => Get.find();

  final RxList<Meal> meals = <Meal>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  // ✅ RxInt — safe inside Obx
  final RxInt activeMealsCount = 0.obs;

  final nameController = TextEditingController();
  final Rx<TimeOfDay> selectedTime = const TimeOfDay(hour: 8, minute: 0).obs;
  final RxString selectedNotifType = AppConstants.notifTypeNotification.obs;

  /// The alarm sound for the item being edited. `null` means the reminder
  /// follows the app-wide default, which is what an untouched form leaves it
  /// as.
  final Rx<AlarmSound?> selectedAlarmSound = Rx<AlarmSound?>(null);
  final RxBool isActive = true.obs;
  Meal? editingMeal;

  List<Meal> get filteredMeals {
    if (searchQuery.value.isEmpty) return meals;
    return meals
        .where((m) =>
            m.name.toLowerCase().contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadMeals();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  void _refreshCounts() {
    activeMealsCount.value = meals.where((m) => m.isActive).length;
  }

  void loadMeals() {
    isLoading.value = true;
    try {
      final data = StorageService.to.getMeals();
      meals.assignAll(data);
      _refreshCounts();
    } catch (e) {
      AppUtils.showError('failed_load_meals'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addMeal() async {
    if (!_validateForm()) return;
    isLoading.value = true;
    try {
      final meal = Meal(
        id: IdGenerator.generate(),
        name: nameController.text.trim(),
        time: selectedTime.value,
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
      );
      await StorageService.to.addMeal(meal);
      meals.add(meal);
      _refreshCounts();
      if (meal.isActive) await ReminderScheduler.scheduleMeal(meal);
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'meal_added'.tr,
        message: 'item_reminder_added'.trParams({'name': meal.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_add_meal'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateMeal() async {
    if (editingMeal == null || !_validateForm()) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelMeal(editingMeal!);
      final updated = editingMeal!.copyWith(
        name: nameController.text.trim(),
        time: selectedTime.value,
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
        clearAlarmSound: selectedAlarmSound.value == null,
      );
      await StorageService.to.updateMeal(updated);
      final idx = meals.indexWhere((m) => m.id == updated.id);
      if (idx != -1) meals[idx] = updated;
      _refreshCounts();
      if (updated.isActive) await ReminderScheduler.scheduleMeal(updated);
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'meal_updated'.tr,
        message: 'item_updated'.trParams({'name': updated.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_update_meal'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteMeal(Meal meal) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'meal_delete_title'.tr,
      message: 'delete_confirm_message'.trParams({'name': meal.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelMeal(meal);
      await StorageService.to.deleteMeal(meal.id);
      meals.removeWhere((m) => m.id == meal.id);
      _refreshCounts();
      AppUtils.showSuccess(
        'item_deleted'.trParams({'name': meal.name}),
        title: 'deleted'.tr,
      );
    } catch (e) {
      AppUtils.showError('failed_delete_meal'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleActive(Meal meal) async {
    try {
      final updated = meal.copyWith(isActive: !meal.isActive);
      await StorageService.to.updateMeal(updated);
      final idx = meals.indexWhere((m) => m.id == meal.id);
      if (idx != -1) meals[idx] = updated;
      _refreshCounts();
      if (updated.isActive) {
        await ReminderScheduler.scheduleMeal(updated);
        AppUtils.showInfo('item_reminders_enabled'.trParams({'name': updated.name}));
      } else {
        await ReminderScheduler.cancelMeal(updated);
        AppUtils.showInfo('item_reminders_paused'.trParams({'name': updated.name}));
      }
    } catch (e) {
      AppUtils.showError('failed_update_meal_status'.tr);
    }
  }

  void prepareForAdd() {
    editingMeal = null;
    _resetForm();
  }

  void prepareForEdit(Meal meal) {
    editingMeal = meal;
    nameController.text = meal.name;
    selectedTime.value = meal.time;
    selectedNotifType.value = meal.notificationType;
    selectedAlarmSound.value = meal.alarmSound;
    isActive.value = meal.isActive;
  }

  void setTime(TimeOfDay time) => selectedTime.value = time;
  void setNotifType(String type) => selectedNotifType.value = type;

  bool _validateForm() {
    if (nameController.text.trim().isEmpty) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'meal_name_required'.tr,
      );
      return false;
    }
    if (nameController.text.trim().length < 2) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'meal_name_too_short'.tr,
      );
      return false;
    }
    return true;
  }

  void _resetForm() {
    nameController.clear();
    selectedTime.value = const TimeOfDay(hour: 8, minute: 0);
    selectedNotifType.value = AppConstants.notifTypeNotification;
    selectedAlarmSound.value = null;
    isActive.value = true;
    editingMeal = null;
  }

  void setSearchQuery(String query) => searchQuery.value = query;
  void clearSearch() => searchQuery.value = '';
}