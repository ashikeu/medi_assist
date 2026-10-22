import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../../../../core/services/prayer_service.dart';
import '../../../routes/app_pages.dart';
import '../controllers/prayer_controller.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/prayer_row_tile.dart';

/// The prayer module's home: today's schedule, the countdown to the next
/// prayer, and the way in to everything else.
class PrayerTimesView extends StatelessWidget {
  const PrayerTimesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDark),
      body: RefreshIndicator(
        onRefresh: () async => controller.refreshAll(),
        color: AppColors.prayerColor,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            NextPrayerCard(controller: controller),
            const SizedBox(height: 16),
            _buildLocationCard(controller, isDark),
            const SizedBox(height: 16),
            _buildDateBar(context, controller, isDark),
            const SizedBox(height: 12),
            _buildScheduleList(controller, isDark),
            const SizedBox(height: 20),
            _buildActions(controller, isDark),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
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
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      title: Text(
        'module_prayer_title'.tr,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'prayer_calendar_title'.tr,
          onPressed: () => Get.toNamed(Routes.prayerCalendar),
          icon: const Icon(Icons.calendar_month_rounded,
              color: AppColors.prayerColor),
        ),
        IconButton(
          tooltip: 'prayer_settings_title'.tr,
          onPressed: () => Get.toNamed(Routes.prayerSettings),
          icon: const Icon(Icons.tune_rounded, color: AppColors.prayerColor),
        ),
      ],
    );
  }

  // ─── Location ─────────────────────────────────────────────────────────────
  Widget _buildLocationCard(PrayerController controller, bool isDark) {
    return InkWell(
      onTap: () => Get.toNamed(Routes.prayerLocation),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.prayerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.place_outlined,
                  color: AppColors.prayerColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.locationLabel.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.usesForeignTimeZone
                          ? '${controller.methodLabel.value} • ${controller.timeZoneLabel}'
                          : controller.methodLabel.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ─── Date selector ────────────────────────────────────────────────────────
  Widget _buildDateBar(
    BuildContext context,
    PrayerController controller,
    bool isDark,
  ) {
    return Obx(() {
      final date = controller.selectedDate.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => controller.shiftDay(-1),
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.prayerColor,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(context, controller),
                child: Column(
                  children: [
                    Text(
                      controller.isShowingToday
                          ? 'prayer_today'.tr
                          : controller.isShowingTomorrow
                              ? 'prayer_tomorrow'.tr
                              : 'prayer_selected_date'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.prayerColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.formatDateLabel(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => controller.shiftDay(1),
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.prayerColor,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickDate(
      BuildContext context, PrayerController controller) async {
    final current = controller.selectedDate.value;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 5),
    );
    if (picked != null) controller.selectDate(picked);
  }

  // ─── Schedule ─────────────────────────────────────────────────────────────
  Widget _buildScheduleList(PrayerController controller, bool isDark) {
    return Obx(() {
      // Eager `.map().toList()` rather than a ListView.builder: a lazy
      // itemBuilder runs after Obx has stopped recording dependencies, so the
      // list would never rebuild when the schedule changes.
      final rows = controller.schedule.toList();
      final currentId = controller.currentPrayerId.value;
      final nextId = controller.nextPrayerId.value;

      return Column(
        children: rows
            .map((entry) => PrayerRowTile(
                  entry: entry,
                  isDark: isDark,
                  isCurrent: entry.id == currentId,
                  isNext: entry.id == nextId,
                  startLabel: controller.formatInstant(entry.start),
                  endLabel: entry.end == null
                      ? null
                      : controller.formatInstant(entry.end),
                  reminderCount: controller.activeReminderCountFor(entry.id),
                  onTap: () => Get.toNamed(
                    Routes.prayerReminders,
                    arguments: entry.id,
                  ),
                ))
            .toList(),
      );
    });
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Widget _buildActions(PrayerController controller, bool isDark) {
    return Column(
      children: [
        _ActionTile(
          isDark: isDark,
          icon: Icons.notifications_active_outlined,
          title: 'prayer_reminders_title'.tr,
          subtitle: 'prayer_reminders_subtitle'.tr,
          onTap: () => Get.toNamed(Routes.prayerReminders),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          isDark: isDark,
          icon: Icons.add_circle_outline_rounded,
          title: 'prayer_custom_add'.tr,
          subtitle: 'prayer_custom_subtitle'.tr,
          onTap: () {
            controller.prepareCustomForAdd();
            Get.toNamed(Routes.addEditCustomPrayer);
          },
        ),
        const SizedBox(height: 10),
        _ActionTile(
          isDark: isDark,
          icon: Icons.explore_outlined,
          title: 'prayer_settings_title'.tr,
          subtitle: 'prayer_settings_subtitle'.tr,
          onTap: () => Get.toNamed(Routes.prayerSettings),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.prayerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// Icon for each prayer, shared by the schedule and the reminder screens.
IconData prayerIconFor(PrayerScheduleEntry entry) {
  switch (entry.kind) {
    case PrayerKind.fajr:
      return Icons.wb_twilight_rounded;
    case PrayerKind.sunrise:
      return Icons.wb_sunny_outlined;
    case PrayerKind.dhuhr:
      return Icons.light_mode_rounded;
    case PrayerKind.asr:
      return Icons.wb_cloudy_outlined;
    case PrayerKind.maghrib:
      return Icons.nights_stay_outlined;
    case PrayerKind.sunset:
      return Icons.wb_twilight_rounded;
    case PrayerKind.isha:
      return Icons.dark_mode_rounded;
    case PrayerKind.midnight:
      return Icons.bedtime_outlined;
    case PrayerKind.tahajjud:
      return Icons.auto_awesome_outlined;
    case null:
      return Icons.star_outline_rounded;
  }
}
