import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../controllers/home_controller.dart';

/// Surfaces whether reminders can actually fire on time.
///
/// Delivery now rests entirely on OS-level exact alarms, so the things worth
/// showing the user are the two grants that silently degrade them: the exact
/// alarm permission and battery optimization.
class ReminderStatusCard extends StatelessWidget {
  const ReminderStatusCard({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final status = controller.permissionStatus;
      final exactAlarm = status['exactAlarm'] ?? false;
      final notifications = status['notification'] ?? false;
      final batteryFree = status['batteryOptimization'] ?? false;

      final protected = exactAlarm && notifications;
      final accent = protected
          ? (batteryFree ? AppColors.secondary : AppColors.warning)
          : AppColors.danger;

      final String title;
      final String subtitle;
      if (!notifications) {
        title = 'reminders_notifications_blocked'.tr;
        subtitle = 'reminders_notifications_blocked_detail'.tr;
      } else if (!exactAlarm) {
        title = 'reminders_exact_alarms_off'.tr;
        subtitle = 'reminders_exact_alarms_off_detail'.tr;
      } else if (!batteryFree) {
        title = 'reminders_active'.tr;
        subtitle = 'reminders_battery_detail'.tr;
      } else {
        title = 'reminders_protected'.tr;
        subtitle = 'reminders_active_detail'.tr;
      }

      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  protected && batteryFree
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!(protected && batteryFree)) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: controller.requestPermissions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'fix'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
