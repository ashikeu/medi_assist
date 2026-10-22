import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../../../../core/services/alarm_sound_service.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../models/prayer_reminder_model.dart';
import '../../../routes/app_pages.dart';
import '../controllers/prayer_controller.dart';

/// Per-prayer reminder configuration.
///
/// Opened either for every prayer at once, or — when a schedule row is tapped
/// and passes its id as the route argument — scrolled to that one prayer.
class PrayerRemindersView extends StatelessWidget {
  const PrayerRemindersView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusedPrayerId =
        Get.arguments is String ? Get.arguments as String : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          focusedPrayerId == null
              ? 'prayer_reminders_title'.tr
              : controller.targetName(focusedPrayerId),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Obx(() {
        // Touch both lists so the screen repaints on any reminder or custom
        // entry change.
        controller.reminders.length;
        controller.customEvents.length;

        final targets = controller.reminderTargets
            .where((entry) =>
                focusedPrayerId == null || entry.id == focusedPrayerId)
            .toList();

        if (targets.isEmpty) {
          return Center(child: Text('prayer_no_targets'.tr));
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (focusedPrayerId == null) ...[
              _buildIntro(isDark),
              const SizedBox(height: 16),
            ],
            // Eager `.map().toList()` — a lazy builder inside Obx would not be
            // registered as a dependency.
            ...targets.map(
              (entry) => _PrayerReminderGroup(
                controller: controller,
                isDark: isDark,
                prayerId: entry.id,
                title: entry.displayName,
                subtitle: controller.formatInstant(entry.start),
                isCustom: entry.isCustom,
              ),
            ),
            const SizedBox(height: 8),
            if (focusedPrayerId == null) _buildAddCustomButton(controller),
          ],
        );
      }),
    );
  }

  Widget _buildIntro(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.prayerColor.withOpacity(isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.prayerColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'prayer_reminders_intro'.tr,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCustomButton(PrayerController controller) {
    return OutlinedButton.icon(
      onPressed: () {
        controller.prepareCustomForAdd();
        Get.toNamed(Routes.addEditCustomPrayer);
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text('prayer_custom_add'.tr),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.prayerColor,
        side: const BorderSide(color: AppColors.prayerColor),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// One prayer and the reminders attached to it.
class _PrayerReminderGroup extends StatelessWidget {
  const _PrayerReminderGroup({
    required this.controller,
    required this.isDark,
    required this.prayerId,
    required this.title,
    required this.subtitle,
    required this.isCustom,
  });

  final PrayerController controller;
  final bool isDark;
  final String prayerId;
  final String title;
  final String subtitle;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final reminders = controller.remindersFor(prayerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(reminders.length),
              if (reminders.isEmpty) ...[
                const SizedBox(height: 10),
                _buildEmpty(),
              ] else ...[
                const SizedBox(height: 6),
                ...reminders.map(_buildReminderRow),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        controller.prepareReminderForAdd(prayerId);
                        Get.toNamed(Routes.addEditPrayerReminder);
                      },
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text('prayer_reminder_add'.tr),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.prayerColor,
                      ),
                    ),
                  ),
                  if (reminders.isEmpty)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () =>
                            controller.addDefaultReminderSet(prayerId),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                        label: Text('prayer_reminder_quick_set'.tr),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCustom)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'prayer_custom_badge'.tr,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        if (isCustom)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                size: 18, color: Colors.grey.shade500),
            onSelected: (value) {
              // A popup callback can fire a frame after the entry was deleted
              // elsewhere; firstWhere would throw rather than do nothing.
              final matches = controller.customEvents
                  .where((e) => e.id == prayerId)
                  .toList();
              if (matches.isEmpty) return;
              final event = matches.first;
              switch (value) {
                case 'edit':
                  controller.prepareCustomForEdit(event);
                  Get.toNamed(Routes.addEditCustomPrayer);
                case 'toggle':
                  controller.toggleCustomEvent(event);
                case 'delete':
                  controller.deleteCustomEvent(event);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
              PopupMenuItem(
                value: 'toggle',
                child: Text('prayer_custom_toggle'.tr),
              ),
              PopupMenuItem(value: 'delete', child: Text('delete'.tr)),
            ],
          )
        else
          Text(
            count.localizedDigits,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: count > 0 ? AppColors.secondary : Colors.grey.shade400,
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Text(
      'prayer_reminder_none'.tr,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade500,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildReminderRow(PrayerReminder reminder) {
    final notifColor = AppUtils.notifTypeColor(reminder.notificationType);
    final notifIcon = AppUtils.notifTypeIcon(reminder.notificationType);

    return InkWell(
      onTap: () {
        controller.prepareReminderForEdit(reminder);
        Get.toNamed(Routes.addEditPrayerReminder);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(notifIcon, size: 17, color: notifColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.usesExactTime
                        ? 'prayer_offset_exact'.trParams({
                            'time':
                                TimeUtils.formatTimeOfDay(reminder.exactTime!),
                          })
                        : offsetLabel(reminder.offsetMinutes),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: reminder.isActive ? null : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detailLine(reminder),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: reminder.isActive,
              onChanged: (_) => controller.toggleReminder(reminder),
              activeThumbColor: AppColors.prayerColor,
            ),
            IconButton(
              onPressed: () => controller.deleteReminder(reminder),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.danger,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _detailLine(PrayerReminder reminder) {
    final parts = <String>[
      AppUtils.notifTypeLabel(reminder.notificationType),
      if (reminder.playSound) 'prayer_sound_on'.tr else 'prayer_sound_off'.tr,
      if (reminder.vibrate) 'prayer_vibrate_on'.tr,
      // Only alarm-type reminders actually play this, so naming it on a
      // notification-only reminder would promise something Android will not
      // deliver.
      if (reminder.usesAlarm)
        AlarmSoundService.to.resolve(reminder.alarmSound).displayLabel,
    ];
    return parts.join(' • ');
  }
}

/// "15 minutes before Fajr" style label for an offset, in the app's language
/// and digits.
String offsetLabel(int offsetMinutes) {
  final minutes = offsetMinutes.abs().localizedDigits;
  if (offsetMinutes == 0) return 'prayer_offset_at'.tr;
  if (offsetMinutes < 0) {
    return 'prayer_offset_before'.trParams({'minutes': minutes});
  }
  return 'prayer_offset_after'.trParams({'minutes': minutes});
}

/// Icon for a prayer used by the reminder form's target picker.
IconData reminderTargetIcon(PrayerKind? kind) =>
    kind == null ? Icons.star_outline_rounded : Icons.mosque_outlined;
