import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/app/modules/home/views/widgets/home_header.dart';
import 'package:medi_assist/app/modules/home/views/widgets/module_card.dart';
import 'package:medi_assist/app/modules/home/views/widgets/permission_banner.dart';
import 'package:medi_assist/app/modules/home/views/widgets/reminder_status_card.dart';
import 'package:medi_assist/app/modules/home/views/widgets/today_summary_card.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          controller.refreshGreeting(); // already calls refreshCounts() internally
          await controller.checkPermissions();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Gradient Header ──
            SliverToBoxAdapter(child: HomeHeader(controller: controller)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Permission Banner ──
                    Obx(() {
                      if (!controller.showPermissionBanner.value) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PermissionBanner(
                          onTap: controller.requestPermissions,
                        ),
                      );
                    }),

                    // ── Today's Summary ──
                    TodaySummaryCard(controller: controller),

                    const SizedBox(height: 24),

                    // ── Section title ──
                    Text(
                      'dashboard_health_modules'.tr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'dashboard_tap_to_manage'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Module Cards Grid ──
                    _buildModuleGrid(context, controller),

                    const SizedBox(height: 24),

                    // ── Reminder Reliability Card ──
                    ReminderStatusCard(controller: controller),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context, HomeController controller) {
    return Obx(() => _buildModuleCards(
          context,
          showPrayer: controller.prayerModuleEnabled.value,
        ));
  }

  Widget _buildModuleCards(
    BuildContext context, {
    required bool showPrayer,
  }) {
    final modules = [
      _ModuleData(
        title: 'module_medicine_title'.tr,
        subtitle: 'module_medicine_subtitle'.tr,
        icon: Icons.medication_rounded,
        gradient: AppColors.medicineGradient,
        lightColor: AppColors.medicineColorLight,
        route: Routes.medicine,
        emoji: '💊',
        tag: 'medicine',
      ),
      _ModuleData(
        title: 'module_meal_title'.tr,
        subtitle: 'module_meal_subtitle'.tr,
        icon: Icons.restaurant_rounded,
        gradient: AppColors.mealGradient,
        lightColor: AppColors.mealColorLight,
        route: Routes.meal,
        emoji: '🍽️',
        tag: 'meal',
      ),
      _ModuleData(
        title: 'module_medical_title'.tr,
        subtitle: 'module_medical_subtitle'.tr,
        icon: Icons.monitor_heart_rounded,
        gradient: AppColors.medicalGradient,
        lightColor: AppColors.medicalColorLight,
        route: Routes.medicalRecords,
        emoji: '📋',
        tag: 'medical',
      ),
      _ModuleData(
        title: 'module_activity_title'.tr,
        subtitle: 'module_activity_subtitle'.tr,
        icon: Icons.directions_run_rounded,
        gradient: AppColors.activityGradient,
        lightColor: AppColors.activityColorLight,
        route: Routes.activity,
        emoji: '🏃',
        tag: 'activity',
      ),
      if (showPrayer)
        _ModuleData(
          title: 'module_prayer_title'.tr,
          subtitle: 'module_prayer_subtitle'.tr,
          icon: Icons.mosque_rounded,
          gradient: AppColors.prayerGradient,
          lightColor: AppColors.prayerColorLight,
          route: Routes.prayer,
          emoji: '🕌',
          tag: 'prayer',
        ),
    ];

    // Cell height is derived from the current text scale rather than a fixed
    // aspect ratio: the card holds a 48px icon plus four lines of text, so at
    // larger system font sizes a ratio-based cell clips its own content.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cellWidth =
        (MediaQuery.sizeOf(context).width - 32 - 12) / 2; // padding + spacing
    final cellHeight = (cellWidth / 0.88) + (textScale - 1.0) * 56;

    // Eager children, not `GridView.builder`: this grid now sits inside an
    // Obx, and a lazy itemBuilder runs after Obx has stopped recording
    // dependencies — the prayer card would never appear or disappear.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: cellHeight,
      ),
      children: [
        for (var index = 0; index < modules.length; index++)
          ModuleCard(
            title: modules[index].title,
            subtitle: modules[index].subtitle,
            icon: modules[index].icon,
            gradient: modules[index].gradient,
            lightColor: modules[index].lightColor,
            route: modules[index].route,
            emoji: modules[index].emoji,
            tag: modules[index].tag,
            animationDelay: Duration(milliseconds: 100 * index),
          ),
      ],
    );
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Color lightColor;
  final String route;
  final String emoji;
  final String tag;

  _ModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.lightColor,
    required this.route,
    required this.emoji,
    required this.tag,
  });
}
