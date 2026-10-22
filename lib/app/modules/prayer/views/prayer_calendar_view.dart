import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../controllers/prayer_controller.dart';

/// The weekly and monthly timetables.
///
/// A wide table of five columns does not fit a phone, so the rows scroll
/// horizontally as one unit with the header pinned above them.
class PrayerCalendarView extends StatelessWidget {
  const PrayerCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'prayer_calendar_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _buildModeToggle(controller, isDark),
          _buildNavigator(controller, isDark),
          const SizedBox(height: 4),
          Expanded(child: _buildTable(controller, isDark)),
        ],
      ),
    );
  }

  Widget _buildModeToggle(PrayerController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(() {
        final monthly = controller.calendarIsMonthly.value;
        return Row(
          children: [
            Expanded(
              child: _toggleButton(
                label: 'prayer_weekly'.tr,
                selected: !monthly,
                isDark: isDark,
                onTap: () => controller.setCalendarMonthly(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _toggleButton(
                label: 'prayer_monthly'.tr,
                selected: monthly,
                isDark: isDark,
                onTap: () => controller.setCalendarMonthly(true),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildNavigator(PrayerController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        // Read the anchor so Obx tracks it — `calendarTitle` derives from it
        // but is a plain getter, so it registers no dependency of its own.
        controller.calendarMonth.value;
        controller.calendarIsMonthly.value;
        return Row(
          children: [
            IconButton(
              onPressed: () => controller.shiftCalendar(-1),
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.prayerColor,
            ),
            Expanded(
              child: Text(
                controller.calendarTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () => controller.shiftCalendar(1),
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.prayerColor,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTable(PrayerController controller, bool isDark) {
    return Obx(() {
      final rows = controller.calendarRows.toList();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: _dateColumnWidth + _timeColumnWidth * 6,
          child: Column(
            children: [
              _buildHeaderRow(isDark),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  // Eager `.map().toList()`, not a builder — a lazy builder
                  // inside Obx would not be tracked as a dependency.
                  child: Column(
                    children: rows
                        .map((row) => _buildDayRow(row, isDark))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  static const double _dateColumnWidth = 96;
  static const double _timeColumnWidth = 86;

  Widget _buildHeaderRow(bool isDark) {
    final headers = [
      'date'.tr,
      PrayerKind.fajr.nameKey.tr,
      PrayerKind.sunrise.nameKey.tr,
      PrayerKind.dhuhr.nameKey.tr,
      PrayerKind.asr.nameKey.tr,
      PrayerKind.maghrib.nameKey.tr,
      PrayerKind.isha.nameKey.tr,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.prayerColor.withOpacity(isDark ? 0.18 : 0.08),
      child: Row(
        children: [
          for (var i = 0; i < headers.length; i++)
            SizedBox(
              width: i == 0 ? _dateColumnWidth : _timeColumnWidth,
              child: Text(
                headers[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.prayerColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayRow(PrayerDayRow row, bool isDark) {
    final cells = [
      row.times[PrayerKind.fajr.id] ?? '—',
      row.sunrise,
      row.times[PrayerKind.dhuhr.id] ?? '—',
      row.times[PrayerKind.asr.id] ?? '—',
      row.times[PrayerKind.maghrib.id] ?? '—',
      row.times[PrayerKind.isha.id] ?? '—',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: row.isToday
            ? AppColors.prayerColor.withOpacity(isDark ? 0.14 : 0.06)
            : null,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _dateColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${row.date.day.localizedDigits} '
                '${'month_short_${row.date.month}'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: row.isToday ? FontWeight.w800 : FontWeight.w600,
                  color: row.isToday ? AppColors.prayerColor : null,
                ),
              ),
            ),
          ),
          for (final cell in cells)
            SizedBox(
              width: _timeColumnWidth,
              child: Text(
                cell,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: row.isToday ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
