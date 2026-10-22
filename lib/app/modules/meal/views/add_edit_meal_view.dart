import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/widgets/alarm_sound_picker.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/core/widgets/notif_type_selector.dart';
import '../controllers/meal_controller.dart';

class AddEditMealView extends StatelessWidget {
  const AddEditMealView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MealController>();
    final isEditing = controller.editingMeal != null;
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

              _buildSectionLabel('meal_name'.tr, Icons.restaurant_rounded),
              const SizedBox(height: 10),
              _buildNameField(controller, isDark),
              const SizedBox(height: 24),

              _buildSectionLabel('meal_time'.tr, Icons.access_time_rounded),
              const SizedBox(height: 4),
              Text('meal_set_time'.tr,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              _buildTimePickerCard(controller, context, isDark),
              const SizedBox(height: 24),

              _buildSectionLabel('quick_presets'.tr, Icons.bolt_rounded),
              const SizedBox(height: 10),
              _buildQuickPresets(controller),
              const SizedBox(height: 24),

              _buildSectionLabel(
                  'reminder_type'.tr, Icons.notifications_rounded),
              const SizedBox(height: 4),
              Text('notif_type_question'.tr,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),

              // ✅ Shared reusable widget
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
                accent: AppColors.mealColor,
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
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: const Icon(Icons.close_rounded, size: 20),
        ),
      ),
      title: Text(
        isEditing ? 'meal_edit'.tr : 'meal_add'.tr,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
    );
  }

  Widget _buildHeaderCard(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.mealGradient,
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
            child: const Icon(Icons.restaurant_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'meal_update_button'.tr : 'meal_new_reminder'.tr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  isEditing
                      ? 'meal_modify_details'.tr
                      : 'meal_subtitle'.tr,
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
        Icon(icon, size: 18, color: AppColors.mealColor),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildNameField(MealController controller, bool isDark) {
    return TextField(
      controller: controller.nameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'meal_name_hint'.tr,
        prefixIcon: const Icon(Icons.restaurant_outlined,
            color: AppColors.mealColor, size: 20),
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
              const BorderSide(color: AppColors.mealColor, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard(
      MealController controller, BuildContext context, bool isDark) {
    return Obx(() {
      final t = controller.selectedTime.value;
      return GestureDetector(
        onTap: () => _pickTime(controller, context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.mealColor.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.mealGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod)
                          .toString()
                          .padLeft(2, '0'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.0),
                    ),
                    Text(
                      t.minute.toString().padLeft(2, '0'),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TimeUtils.formatTimeOfDay(t),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMealSuggestion(t.hour),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: AppColors.mealColor, size: 18),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _getMealSuggestion(int hour) {
    if (hour >= 5 && hour < 11) return 'meal_suggest_breakfast'.tr;
    if (hour >= 11 && hour < 15) return 'meal_suggest_lunch'.tr;
    if (hour >= 15 && hour < 18) return 'meal_suggest_snack'.tr;
    if (hour >= 18 && hour < 22) return 'meal_suggest_dinner'.tr;
    return 'meal_suggest_default'.tr;
  }

  Future<void> _pickTime(
      MealController controller, BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.selectedTime.value,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.mealColor, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) controller.setTime(picked);
  }

  Widget _buildQuickPresets(MealController controller) {
    final presets = [
      ('🌅', 'preset_breakfast'.tr, const TimeOfDay(hour: 8, minute: 0)),
      ('☀️', 'preset_lunch'.tr, const TimeOfDay(hour: 13, minute: 0)),
      ('☕', 'preset_snack'.tr, const TimeOfDay(hour: 16, minute: 0)),
      ('🌙', 'preset_dinner'.tr, const TimeOfDay(hour: 19, minute: 30)),
    ];
    return Obx(() {
      // ✅ Extract Rx value in direct Obx scope before any lazy widget
      final currentHour = controller.selectedTime.value.hour;
      final currentMinute = controller.selectedTime.value.minute;
      return Row(
        children: presets.map((preset) {
          final isSelected = currentHour == preset.$3.hour &&
              currentMinute == preset.$3.minute;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.setTime(preset.$3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.mealColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.mealColor
                        : Colors.grey.withOpacity(0.25),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(preset.$1,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      preset.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.mealColor
                            : Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      TimeUtils.formatTimeOfDay(preset.$3),
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.mealColor
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildActiveToggle(MealController controller, bool isDark) {
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
                          ? 'meal_reminders_active'.tr
                          : 'meal_reminders_paused'.tr,
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

  Widget _buildSaveButton(MealController controller, bool isEditing) {
    return Obx(() => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: controller.isLoading.value
                ? null
                : () => isEditing
                    ? controller.updateMeal()
                    : controller.addMeal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mealColor,
              disabledBackgroundColor: AppColors.mealColor.withOpacity(0.5),
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
                        isEditing ? 'save_changes'.tr : 'meal_add'.tr,
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