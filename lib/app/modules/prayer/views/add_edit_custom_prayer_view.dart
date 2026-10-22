import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../../../../core/utils/time_utils.dart';
import '../controllers/prayer_controller.dart';

/// Add or edit a custom prayer or event — Ishraq, Duha, a nightly wird, or a
/// mosque's own jamaat time.
///
/// It is either anchored to a calculated prayer with an offset, so it moves
/// with the sun through the year, or pinned to a wall-clock time.
class AddEditCustomPrayerView extends StatelessWidget {
  const AddEditCustomPrayerView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = controller.editingCustomEvent != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          isEditing ? 'prayer_custom_edit'.tr : 'prayer_custom_add'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _card(
            isDark: isDark,
            child: TextField(
              controller: controller.customNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'prayer_custom_name'.tr,
                hintText: 'prayer_custom_name_hint'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('prayer_custom_when'.tr),
          const SizedBox(height: 10),
          _buildModeCard(context, controller, isDark),
          const SizedBox(height: 24),
          _buildSaveButton(controller, isEditing),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      );

  Widget _card({required bool isDark, required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: child,
      );

  Widget _buildModeCard(
    BuildContext context,
    PrayerController controller,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Obx(() {
        final anchored = controller.customIsAnchored.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: 'prayer_custom_anchored'.tr,
                    selected: anchored,
                    isDark: isDark,
                    onTap: () => controller.customIsAnchored.value = true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _modeButton(
                    label: 'prayer_custom_fixed'.tr,
                    selected: !anchored,
                    isDark: isDark,
                    onTap: () => controller.customIsAnchored.value = false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (anchored) ...[
              Text(
                'prayer_custom_anchor_prayer'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PrayerKind.schedule.map((kind) {
                  final isSelected = controller.customAnchorId.value == kind.id;
                  return GestureDetector(
                    onTap: () => controller.customAnchorId.value = kind.id,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.prayerColor
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        kind.nameKey.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'prayer_custom_offset'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _offsetSummary(controller),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.prayerColor,
                ),
              ),
              Slider(
                value: controller.customOffsetMinutes.value
                    .toDouble()
                    .clamp(-180, 180),
                min: -180,
                max: 180,
                divisions: 72,
                activeColor: AppColors.prayerColor,
                onChanged: (value) => controller.customOffsetMinutes.value =
                    (value / 5).round() * 5,
              ),
            ] else ...[
              Text(
                'prayer_custom_fixed_time'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: controller.customFixedTime.value,
                  );
                  if (picked != null) {
                    controller.customFixedTime.value = picked;
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 18, color: AppColors.prayerColor),
                      const SizedBox(width: 10),
                      Text(
                        TimeUtils.formatTimeOfDay(
                            controller.customFixedTime.value),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'prayer_custom_fixed_detail'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  String _offsetSummary(PrayerController controller) {
    final minutes = controller.customOffsetMinutes.value;
    final anchor = 'prayer_${controller.customAnchorId.value}'.tr;
    final value = minutes.abs().localizedDigits;
    if (minutes == 0) return 'prayer_custom_offset_at'.trParams({'prayer': anchor});
    if (minutes < 0) {
      return 'prayer_custom_offset_before'
          .trParams({'minutes': value, 'prayer': anchor});
    }
    return 'prayer_custom_offset_after'
        .trParams({'minutes': value, 'prayer': anchor});
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.prayerColor
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.prayerColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(PrayerController controller, bool isEditing) {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed:
              controller.isBusy.value ? null : controller.saveCustomEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.prayerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: controller.isBusy.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEditing ? 'save_changes'.tr : 'prayer_custom_add'.tr,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
