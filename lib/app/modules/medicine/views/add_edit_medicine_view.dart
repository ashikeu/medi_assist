import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/widgets/alarm_sound_picker.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/core/widgets/notif_type_selector.dart';
import '../controllers/medicine_controller.dart';

class AddEditMedicineView extends StatelessWidget {
  const AddEditMedicineView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicineController>();
    final isEditing = controller.editingMedicine != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isEditing, isDark),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(isEditing),
              const SizedBox(height: 24),

              _buildSectionLabel('medicine_name'.tr, Icons.medication_rounded),
              const SizedBox(height: 10),
              _buildNameField(controller, isDark),
              const SizedBox(height: 24),

              _buildSectionLabel('reminder_times'.tr, Icons.access_time_rounded),
              const SizedBox(height: 4),
              Text(
                'reminder_times_hint'.tr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              _buildTimesSection(controller, context, isDark),
              const SizedBox(height: 24),

              _buildSectionLabel('reminder_type'.tr, Icons.notifications_rounded),
              const SizedBox(height: 4),
              Text(
                'notif_type_question'.tr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),

              // ✅ Shared reusable widget — no more GridView.builder Obx bug
              NotifTypeSelector(
                selectedNotifType: controller.selectedNotifType,
                onChanged: controller.setNotifType,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              _buildSectionLabel('alarm_sound'.tr, Icons.music_note_rounded),
              const SizedBox(height: 4),
              Text('alarm_sound_form_hint'.tr,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              AlarmSoundRow(
                selected: controller.selectedAlarmSound,
                onChanged: (sound) =>
                    controller.selectedAlarmSound.value = sound,
                isDark: isDark,
                accent: AppColors.medicineColor,
              ),
              const SizedBox(height: 24),

              _buildActiveToggle(controller, isDark),
              const SizedBox(height: 32),

              _buildSaveButton(controller, isEditing),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isEditing, bool isDark) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: const Icon(Icons.close_rounded, size: 20),
        ),
      ),
      title: Text(
        isEditing ? 'medicine_edit'.tr : 'medicine_add'.tr,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
    );
  }

  Widget _buildHeaderCard(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.medicineGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medication_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'medicine_update_button'.tr
                      : 'medicine_new_reminder'.tr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  isEditing
                      ? 'medicine_modify_details'.tr
                      : 'medicine_setup_schedule'.tr,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.medicineColor),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildNameField(MedicineController controller, bool isDark) {
    return TextField(
      controller: controller.nameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'medicine_name_hint'.tr,
        prefixIcon: const Icon(Icons.medication_outlined,
            color: AppColors.medicineColor, size: 20),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.medicineColor, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildTimesSection(
      MedicineController controller, BuildContext context, bool isDark) {
    return Obx(() {
      return Column(
        children: [
          if (controller.selectedTimes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  controller.selectedTimes.length,
                  (i) {
                    final t = controller.selectedTimes[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.medicineGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            TimeUtils.formatTimeOfDay(t),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => controller.removeTime(i),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          GestureDetector(
            onTap: () => _pickTime(controller, context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.medicineColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.medicineColor.withOpacity(0.3),
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                        color: AppColors.medicineColor,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    controller.selectedTimes.isEmpty
                        ? 'add_reminder_time'.tr
                        : 'add_another_time'.tr,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.medicineColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _pickTime(
      MedicineController controller, BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.medicineColor,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) controller.addTime(picked);
  }

  Widget _buildActiveToggle(MedicineController controller, bool isDark) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: controller.isActive.value
                      ? AppColors.secondary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  controller.isActive.value
                      ? Icons.check_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: controller.isActive.value
                      ? AppColors.secondary
                      : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('enable_reminders'.tr,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                      controller.isActive.value
                          ? 'reminders_are_active'.tr
                          : 'reminders_are_paused'.tr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.isActive.value,
                onChanged: (v) => controller.isActive.value = v,
                activeColor: AppColors.secondary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ));
  }

  Widget _buildSaveButton(MedicineController controller, bool isEditing) {
    return Obx(() => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: controller.isLoading.value
                ? null
                : () => isEditing
                    ? controller.updateMedicine()
                    : controller.addMedicine(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.medicineColor,
              disabledBackgroundColor:
                  AppColors.medicineColor.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          isEditing
                              ? Icons.save_rounded
                              : Icons.add_circle_rounded,
                          color: Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'save_changes'.tr : 'medicine_add'.tr,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ));
  }
}