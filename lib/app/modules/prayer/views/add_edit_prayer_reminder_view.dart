import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/alarm_sound_picker.dart';
import '../../../../core/widgets/notif_type_selector.dart';
import '../controllers/prayer_controller.dart';
import 'prayer_reminders_view.dart';

/// Add or edit one reminder: which prayer, how far before or after it, how it
/// should announce itself, and what it should say.
class AddEditPrayerReminderView extends StatelessWidget {
  const AddEditPrayerReminderView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = controller.editingReminder != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          isEditing ? 'prayer_reminder_edit'.tr : 'prayer_reminder_add'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle('prayer_reminder_for'.tr),
          const SizedBox(height: 10),
          _buildTargetPicker(controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('prayer_reminder_timing'.tr),
          const SizedBox(height: 10),
          _buildTimingCard(context, controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('notif_type_label'.tr),
          const SizedBox(height: 10),
          NotifTypeSelector(
            selectedNotifType: controller.formNotifType,
            onChanged: (type) => controller.formNotifType.value = type,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _sectionTitle('prayer_reminder_behaviour'.tr),
          const SizedBox(height: 10),
          _buildBehaviourCard(controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('alarm_sound'.tr),
          const SizedBox(height: 10),
          AlarmSoundRow(
            selected: controller.formAlarmSound,
            onChanged: (sound) => controller.formAlarmSound.value = sound,
            isDark: isDark,
            accent: AppColors.prayerColor,
          ),
          const SizedBox(height: 20),
          _sectionTitle('prayer_reminder_wording'.tr),
          const SizedBox(height: 10),
          _buildWordingCard(controller, isDark),
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

  // ─── Which prayer ─────────────────────────────────────────────────────────
  Widget _buildTargetPicker(PrayerController controller, bool isDark) {
    final targets = controller.reminderTargets;

    return _card(
      isDark: isDark,
      child: Obx(() {
        final selected = controller.formPrayerId.value;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: targets.map((entry) {
            final isSelected = entry.id == selected;
            return GestureDetector(
              onTap: () => controller.formPrayerId.value = entry.id,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.prayerColor
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          .withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reminderTargetIcon(entry.kind),
                      size: 14,
                      color: isSelected ? Colors.white : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  // ─── Timing ───────────────────────────────────────────────────────────────
  /// Either an offset from the prayer, or a clock time the user picks.
  ///
  /// The offset mode is what most people want — it tracks the sun through the
  /// year. The exact-time mode exists for a fixed personal routine, or a mosque
  /// whose jamaat runs to the clock rather than to the calculated time.
  Widget _buildTimingCard(
    BuildContext context,
    PrayerController controller,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Obx(() {
        final usesExact = controller.formUsesExactTime.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: 'prayer_timing_relative'.tr,
                    selected: !usesExact,
                    isDark: isDark,
                    onTap: () => controller.formUsesExactTime.value = false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _modeButton(
                    label: 'prayer_timing_exact'.tr,
                    selected: usesExact,
                    isDark: isDark,
                    onTap: () => controller.formUsesExactTime.value = true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (usesExact)
              _buildExactTimePicker(context, controller, isDark)
            else
              _buildOffsetPicker(controller),
          ],
        );
      }),
    );
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

  Widget _buildExactTimePicker(
    BuildContext context,
    PrayerController controller,
    bool isDark,
  ) {
    final time = controller.formExactTime.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              helpText: 'prayer_timing_exact'.tr,
            );
            if (picked != null) controller.formExactTime.value = picked;
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.prayerColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.prayerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 20, color: AppColors.prayerColor),
                const SizedBox(width: 12),
                Text(
                  TimeUtils.formatTimeOfDay(time),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                Icon(Icons.edit_outlined,
                    size: 16, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          controller.usesForeignTimeZone
              ? 'prayer_timing_exact_detail_zone'
                  .trParams({'zone': controller.timeZoneLabel})
              : 'prayer_timing_exact_detail'.tr,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Offset ───────────────────────────────────────────────────────────────
  Widget _buildOffsetPicker(PrayerController controller) {
    final offset = controller.formOffsetMinutes.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offsetLabel(offset),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.prayerColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'prayer_offset_detail'.tr,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.prayerOffsetPresets.map((preset) {
            final isSelected = preset == offset;
            return GestureDetector(
              onTap: () => controller.formOffsetMinutes.value = preset,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.prayerColor
                      : Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _presetLabel(preset),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        // The presets cover the usual choices; the slider is there for
        // anyone whose mosque runs to an unusual gap.
        Slider(
          value: offset.toDouble().clamp(-60, 60),
          min: -60,
          max: 60,
          divisions: 120,
          activeColor: AppColors.prayerColor,
          label: offsetLabel(offset),
          onChanged: (value) =>
              controller.formOffsetMinutes.value = value.round(),
        ),
      ],
    );
  }

  static String _presetLabel(int minutes) {
    if (minutes == 0) return 'prayer_offset_at_short'.tr;
    final value = minutes.abs().localizedDigits;
    return minutes < 0 ? '-$value' : '+$value';
  }

  // ─── Sound, vibration, ringing ────────────────────────────────────────────
  Widget _buildBehaviourCard(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Obx(() {
        final usesAlarm =
            controller.formNotifType.value == AppConstants.notifTypeAlarm ||
                controller.formNotifType.value == AppConstants.notifTypeBoth;

        return Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.formPlaySound.value,
              onChanged: (value) => controller.formPlaySound.value = value,
              activeThumbColor: AppColors.prayerColor,
              title: Text('prayer_play_sound'.tr,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'prayer_play_sound_detail'.tr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.formVibrate.value,
              onChanged: (value) => controller.formVibrate.value = value,
              activeThumbColor: AppColors.prayerColor,
              title: Text('prayer_vibrate'.tr,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'prayer_vibrate_detail'.tr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: usesAlarm && controller.formLoopAudio.value,
              // Looping is a property of the ringing alarm, so it means
              // nothing for a plain notification — disabled rather than hidden
              // so it is clear what switching to an alarm would give you.
              onChanged: usesAlarm
                  ? (value) => controller.formLoopAudio.value = value
                  : null,
              activeThumbColor: AppColors.prayerColor,
              title: Text('prayer_loop_audio'.tr,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                usesAlarm
                    ? 'prayer_loop_audio_detail'.tr
                    : 'prayer_loop_audio_alarm_only'.tr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.formActive.value,
              onChanged: (value) => controller.formActive.value = value,
              activeThumbColor: AppColors.secondary,
              title: Text('prayer_reminder_active'.tr,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'prayer_reminder_active_detail'.tr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── Custom wording ───────────────────────────────────────────────────────
  Widget _buildWordingCard(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller.reminderTitleController,
            decoration: InputDecoration(
              labelText: 'prayer_notification_title'.tr,
              hintText: 'prayer_notification_title_hint'.tr,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.reminderMessageController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'prayer_notification_message'.tr,
              hintText: 'prayer_notification_message_hint'.tr,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'prayer_wording_detail'.tr,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(PrayerController controller, bool isEditing) {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: controller.isBusy.value ? null : controller.saveReminder,
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
                  isEditing ? 'save_changes'.tr : 'prayer_reminder_add'.tr,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
