import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/localization/localized_digits.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/services/reminder_scheduler.dart';
import 'package:medi_assist/core/services/storage_service.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/core/utils/id_generator.dart';
import 'package:medi_assist/models/alarm_sound_model.dart';
import 'package:medi_assist/models/medicine_model.dart';


class MedicineController extends GetxController {
  static MedicineController get to => Get.find();

  final RxList<Medicine> medicines = <Medicine>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  // ✅ RxInt — safe to use inside Obx
  final RxInt activeMedicinesCount = 0.obs;

  final nameController = TextEditingController();
  final RxList<TimeOfDay> selectedTimes = <TimeOfDay>[].obs;
  final RxString selectedNotifType = AppConstants.notifTypeNotification.obs;

  /// The alarm sound for the item being edited. `null` means the reminder
  /// follows the app-wide default, which is what an untouched form leaves it
  /// as.
  final Rx<AlarmSound?> selectedAlarmSound = Rx<AlarmSound?>(null);
  final RxBool isActive = true.obs;
  Medicine? editingMedicine;

  List<Medicine> get filteredMedicines {
    if (searchQuery.value.isEmpty) return medicines;
    return medicines
        .where((m) =>
            m.name.toLowerCase().contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadMedicines();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  void _refreshCounts() {
    activeMedicinesCount.value = medicines.where((m) => m.isActive).length;
  }

  void loadMedicines() {
    isLoading.value = true;
    try {
      final data = StorageService.to.getMedicines();
      medicines.assignAll(data);
      _refreshCounts(); // ✅
    } catch (e) {
      AppUtils.showError('failed_load_medicines'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addMedicine() async {
    if (!_validateForm()) return;
    isLoading.value = true;
    try {
      final medicine = Medicine(
        id: IdGenerator.generate(),
        name: nameController.text.trim(),
        times: List.from(selectedTimes),
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
      );
      await StorageService.to.addMedicine(medicine);
      medicines.add(medicine);
      _refreshCounts(); // ✅
      if (medicine.isActive) await ReminderScheduler.scheduleMedicine(medicine);
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'medicine_added'.tr,
        message: 'item_reminder_added'.trParams({'name': medicine.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_add_medicine'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateMedicine() async {
    if (editingMedicine == null || !_validateForm()) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelMedicine(editingMedicine!);
      final updated = editingMedicine!.copyWith(
        name: nameController.text.trim(),
        times: List.from(selectedTimes),
        notificationType: selectedNotifType.value,
        isActive: isActive.value,
        alarmSound: selectedAlarmSound.value,
        clearAlarmSound: selectedAlarmSound.value == null,
      );
      await StorageService.to.updateMedicine(updated);
      final idx = medicines.indexWhere((m) => m.id == updated.id);
      if (idx != -1) medicines[idx] = updated;
      _refreshCounts(); // ✅
      if (updated.isActive) await ReminderScheduler.scheduleMedicine(updated);
      _resetForm();
      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'medicine_updated'.tr,
        message: 'item_updated'.trParams({'name': updated.name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'failed_update_medicine'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteMedicine(Medicine medicine) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'medicine_delete_title'.tr,
      message: 'delete_confirm_message'.trParams({'name': medicine.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    isLoading.value = true;
    try {
      await ReminderScheduler.cancelMedicine(medicine);
      await StorageService.to.deleteMedicine(medicine.id);
      medicines.removeWhere((m) => m.id == medicine.id);
      _refreshCounts(); // ✅
      AppUtils.showSuccess(
        'item_deleted'.trParams({'name': medicine.name}),
        title: 'deleted'.tr,
      );
    } catch (e) {
      AppUtils.showError('failed_delete_medicine'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleActive(Medicine medicine) async {
    try {
      final updated = medicine.copyWith(isActive: !medicine.isActive);
      await StorageService.to.updateMedicine(updated);
      final idx = medicines.indexWhere((m) => m.id == medicine.id);
      if (idx != -1) medicines[idx] = updated;
      _refreshCounts(); // ✅
      if (updated.isActive) {
        await ReminderScheduler.scheduleMedicine(updated);
        AppUtils.showInfo('item_reminders_enabled'.trParams({'name': updated.name}));
      } else {
        await ReminderScheduler.cancelMedicine(updated);
        AppUtils.showInfo('item_reminders_paused'.trParams({'name': updated.name}));
      }
    } catch (e) {
      AppUtils.showError('failed_update_medicine_status'.tr);
    }
  }

  void prepareForAdd() {
    editingMedicine = null;
    _resetForm();
  }

  void prepareForEdit(Medicine medicine) {
    editingMedicine = medicine;
    nameController.text = medicine.name;
    selectedTimes.assignAll(medicine.times);
    selectedNotifType.value = medicine.notificationType;
    selectedAlarmSound.value = medicine.alarmSound;
    isActive.value = medicine.isActive;
  }

  void addTime(TimeOfDay time) {
    if (selectedTimes.length >= ReminderScheduler.maxMedicineTimes) {
      // Slot N uses reminder ID `base + N`, and bases are 10 apart — an 11th
      // time would silently overwrite another medicine's reminder.
      AppUtils.showWarning(
        'time_max_reached'.trParams({
          'count': ReminderScheduler.maxMedicineTimes.localizedDigits,
        }),
      );
      return;
    }
    final exists = selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute);
    if (!exists) {
      selectedTimes.add(time);
      selectedTimes.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    } else {
      AppUtils.showWarning('time_already_added'.tr);
    }
  }

  void removeTime(int index) {
    if (selectedTimes.length > 1) {
      selectedTimes.removeAt(index);
    } else {
      AppUtils.showWarning('time_at_least_one'.tr);
    }
  }

  void setNotifType(String type) => selectedNotifType.value = type;

  bool _validateForm() {
    if (nameController.text.trim().isEmpty) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'medicine_name_required'.tr,
      );
      return false;
    }
    if (selectedTimes.isEmpty) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'time_add_at_least_one'.tr,
      );
      return false;
    }
    return true;
  }

  void _resetForm() {
    nameController.clear();
    selectedTimes.clear();
    selectedNotifType.value = AppConstants.notifTypeNotification;
    selectedAlarmSound.value = null;
    isActive.value = true;
    editingMedicine = null;
  }

  void setSearchQuery(String query) => searchQuery.value = query;
  void clearSearch() => searchQuery.value = '';
}