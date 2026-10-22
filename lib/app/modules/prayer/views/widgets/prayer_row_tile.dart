import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/localization/localized_digits.dart';
import '../../../../../core/services/prayer_service.dart';
import '../prayer_times_view.dart';

/// One row of the day's schedule.
///
/// Shows the start time, the end of the window where the prayer has one, and
/// how many reminders are attached — tapping opens that prayer's reminders.
class PrayerRowTile extends StatelessWidget {
  const PrayerRowTile({
    super.key,
    required this.entry,
    required this.isDark,
    required this.isCurrent,
    required this.isNext,
    required this.startLabel,
    required this.endLabel,
    required this.reminderCount,
    required this.onTap,
  });

  final PrayerScheduleEntry entry;
  final bool isDark;
  final bool isCurrent;
  final bool isNext;
  final String startLabel;
  final String? endLabel;
  final int reminderCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = isCurrent || isNext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.prayerColor.withOpacity(isDark ? 0.16 : 0.07)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? AppColors.prayerColor.withOpacity(0.55)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.prayerColor
                      .withOpacity(entry.isObligatory ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  prayerIconFor(entry),
                  size: 19,
                  color: entry.isObligatory
                      ? AppColors.prayerColor
                      : AppColors.prayerColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: entry.isObligatory
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: entry.isObligatory
                                  ? null
                                  : Colors.grey.shade500,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) _badge('prayer_now'.tr),
                        if (!isCurrent && isNext) _badge('prayer_next'.tr),
                      ],
                    ),
                    if (endLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'prayer_ends_at'.trParams({'time': endLabel!}),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    startLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: highlighted ? AppColors.prayerColor : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reminderCount > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        size: 12,
                        color: reminderCount > 0
                            ? AppColors.secondary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        reminderCount.localizedDigits,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: reminderCount > 0
                              ? AppColors.secondary
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.prayerColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
