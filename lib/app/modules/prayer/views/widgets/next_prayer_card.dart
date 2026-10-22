import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../controllers/prayer_controller.dart';

/// The gradient hero card: which prayer is next, when it is, and how long
/// there is left.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({super.key, required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.prayerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.prayerColor.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Obx(() {
        final name = controller.nextPrayerName.value;
        final hasNext = name.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'prayer_next_up'.tr,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              hasNext ? name : 'prayer_no_times'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            if (hasNext) ...[
              const SizedBox(height: 4),
              Text(
                controller.nextPrayerTime.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      controller.countdown.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        // Tabular-ish: a proportional font makes a ticking
                        // countdown jitter as the digits change width.
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'prayer_no_times_detail'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        );
      }),
    );
  }
}
