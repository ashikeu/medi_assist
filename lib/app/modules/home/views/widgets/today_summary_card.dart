import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import '../../../../../core/localization/localized_digits.dart';
import '../../controllers/home_controller.dart';

class TodaySummaryCard extends StatelessWidget {
  final HomeController controller;
  const TodaySummaryCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.today_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'dashboard_todays_overview'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Obx now reads actual Rx observables — no more GetX error
            Obx(() => Row(
                  children: [
                    _SummaryItem(
                      label: 'summary_medicines'.tr,
                      count: controller.activeMedicineCount.value,
                      icon: Icons.medication_rounded,
                      color: AppColors.medicineColor,
                    ),
                    _SummaryDivider(),
                    _SummaryItem(
                      label: 'summary_meals'.tr,
                      count: controller.activeMealCount.value,
                      icon: Icons.restaurant_rounded,
                      color: AppColors.mealColor,
                    ),
                    _SummaryDivider(),
                    _SummaryItem(
                      label: 'summary_activities'.tr,
                      count: controller.activeActivityCount.value,
                      icon: Icons.directions_run_rounded,
                      color: AppColors.activityColor,
                    ),
                    _SummaryDivider(),
                    _SummaryItem(
                      label: 'summary_records'.tr,
                      count: controller.totalRecordsCount.value,
                      icon: Icons.monitor_heart_rounded,
                      color: AppColors.medicalColor,
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            count.localizedDigits,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      color: Colors.grey.withOpacity(0.15),
    );
  }
}