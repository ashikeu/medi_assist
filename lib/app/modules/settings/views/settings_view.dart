import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import '../../../../core/localization/app_locales.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/widgets/alarm_sound_picker.dart';
import '../../../routes/app_pages.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDark),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── App Info Header ──
          _buildAppInfoCard(isDark),
          const SizedBox(height: 24),

          // ── Language ──
          // First section deliberately: someone who cannot read the rest of
          // this screen needs to reach it without understanding any of it.
          _buildSectionTitle('settings_language'.tr),
          const SizedBox(height: 10),
          _buildLanguageCard(controller, isDark),
          const SizedBox(height: 24),

          // ── Permissions ──
          _buildSectionTitle('settings_permissions'.tr),
          const SizedBox(height: 10),
          _buildPermissionsCard(controller, isDark),
          const SizedBox(height: 24),

          // ── Reminders ──
          _buildSectionTitle('settings_reminders'.tr),
          const SizedBox(height: 10),
          _buildRemindersCard(controller, isDark),
          const SizedBox(height: 12),
          // The default every reminder inherits unless it names its own sound.
          AlarmSoundRow(
            selected: controller.defaultAlarmSound,
            onChanged: controller.setDefaultAlarmSound,
            isDark: isDark,
            allowInherit: false,
          ),
          const SizedBox(height: 24),

          // ── Prayer ──
          // Location lives here as well as inside the module, because
          // "change my prayer location" is the kind of thing people look for
          // in Settings rather than by navigating back into the feature.
          _buildSectionTitle('module_prayer_title'.tr),
          const SizedBox(height: 10),
          _buildPrayerCard(controller, isDark),
          const SizedBox(height: 24),

          // ── Diagnostics ──
          _buildSectionTitle('settings_diagnostics'.tr),
          const SizedBox(height: 10),
          _buildDiagnosticsCard(controller, isDark),
          const SizedBox(height: 24),

          // ── Data ──
          _buildSectionTitle('settings_data_management'.tr),
          const SizedBox(height: 10),
          _buildDataCard(controller, isDark),
          const SizedBox(height: 24),

          // ── Backup & Restore ──
          _buildSectionTitle('settings_backup_restore'.tr),
          const SizedBox(height: 10),
          _buildBackupCard(controller, isDark),
          const SizedBox(height: 24),

          // ── About ──
          _buildAboutCard(isDark),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────
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
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      title: Text(
        'settings_title'.tr,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── Section Title ────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }

  // ─── App Info Card ────────────────────────────────────────────────────────────
  Widget _buildAppInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app_name'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'settings_version'.trParams({
                    'version': AppConstants.appVersion.localizedDigits,
                  }),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'app_tagline'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Language Card ────────────────────────────────────────────────────────────
  /// Every supported language, laid out flat rather than behind a dropdown.
  ///
  /// Each row is labelled in its own language, so it is recognisable to the
  /// person who needs it regardless of what the app is currently showing.
  Widget _buildLanguageCard(SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        Obx(() {
          final selectedTag = controller.languageTag.value;
          final languages = AppLocales.supported;
          return Column(
            children: languages
                .map(
                  (language) => _LanguageTile(
                    isDark: isDark,
                    language: language,
                    isSelected: language.tag == selectedTag,
                    onTap: () => controller.changeLanguage(language),
                    showDivider: language != languages.last,
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  // ─── Permissions Card ─────────────────────────────────────────────────────────
  Widget _buildPermissionsCard(
      SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        Obx(() {
          final status = controller.permissionStatus;

          return Column(
            children: [
              // Notification permission
              _PermissionTile(
                isDark: isDark,
                icon: Icons.notifications_outlined,
                title: 'settings_notifications'.tr,
                subtitle: 'settings_notifications_detail'.tr,
                isGranted: status['notification'] ?? false,
                onTap: controller.requestAllPermissions,
                showDivider: true,
              ),

              // Exact alarm permission
              _PermissionTile(
                isDark: isDark,
                icon: Icons.alarm_outlined,
                title: 'settings_exact_alarms'.tr,
                subtitle: 'settings_exact_alarms_detail'.tr,
                isGranted: status['exactAlarm'] ?? false,
                onTap: controller.openAlarmSettings,
                showDivider: true,
              ),

              // Battery optimization
              _PermissionTile(
                isDark: isDark,
                icon: Icons.battery_saver_outlined,
                title: 'settings_battery'.tr,
                subtitle: 'settings_disable_to_keep'.tr,
                isGranted: status['batteryOptimization'] ?? false,
                onTap: controller.openBatterySettings,
                showDivider: false,
              ),
            ],
          );
        }),

        // Refresh permissions button
        const SizedBox(height: 4),
        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.refresh_rounded,
          iconColor: AppColors.primary,
          title: 'settings_refresh_permissions'.tr,
          subtitle: 'settings_refresh_permissions_detail'.tr,
          onTap: controller.refreshPermissions,
          showDivider: false,
        ),
      ],
    );
  }

  // ─── Reminders Card ───────────────────────────────────────────────────────────
  Widget _buildRemindersCard(
      SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        _SettingsTile(
          isDark: isDark,
          icon: Icons.restart_alt_rounded,
          iconColor: AppColors.primary,
          title: 'settings_reschedule_all'.tr,
          subtitle: 'settings_reschedule_all_detail'.tr,
          onTap: controller.rescheduleAll,
          showDivider: true,
        ),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.notifications_active_rounded,
          iconColor: AppColors.secondary,
          title: 'settings_test_notification'.tr,
          subtitle: 'settings_test_notification_detail'.tr,
          onTap: controller.sendTestNotification,
          showDivider: false,
        ),
      ],
    );
  }

  // ─── Diagnostics Card ─────────────────────────────────────────────────────────
  // ─── Prayer ──────────────────────────────────────────────────────────────────
  Widget _buildPrayerCard(SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        Obx(
          () => _SettingsTile(
            isDark: isDark,
            icon: Icons.place_outlined,
            iconColor: AppColors.prayerColor,
            title: 'prayer_location_title'.tr,
            subtitle: controller.prayerLocationLabel.value,
            onTap: () => Get.toNamed(Routes.prayerLocation),
            showDivider: true,
          ),
        ),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.tune_rounded,
          iconColor: AppColors.prayerColor,
          title: 'prayer_settings_title'.tr,
          subtitle: 'prayer_settings_subtitle'.tr,
          onTap: () => Get.toNamed(Routes.prayerSettings),
          showDivider: true,
        ),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.notifications_active_outlined,
          iconColor: AppColors.prayerColor,
          title: 'prayer_reminders_title'.tr,
          subtitle: 'prayer_reminders_subtitle'.tr,
          onTap: () => Get.toNamed(Routes.prayerReminders),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildDiagnosticsCard(
      SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        Obx(() {
          return _SettingsTile(
            isDark: isDark,
            icon: Icons.pending_outlined,
            iconColor: AppColors.primary,
            title: 'settings_pending_notifications'.tr,
            subtitle: 'settings_pending_count'.trParams({
              'count': controller.pendingNotifCount.value.localizedDigits,
            }),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.pendingNotifCount.value.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            onTap: controller.loadPendingNotifications,
            showDivider: false,
          );
        }),
      ],
    );
  }

  // ─── Data Card ────────────────────────────────────────────────────────────────
  Widget _buildDataCard(SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        _SettingsTile(
          isDark: isDark,
          icon: Icons.delete_forever_rounded,
          iconColor: AppColors.danger,
          title: 'settings_clear_data'.tr,
          subtitle: 'settings_clear_data_detail'.tr,
          titleColor: AppColors.danger,
          onTap: controller.clearAllData,
          showDivider: false,
        ),
      ],
    );
  }

  // ─── Backup & Restore Card ────────────────────────────────────────────────────
  Widget _buildBackupCard(SettingsController controller, bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        _SettingsTile(
          isDark: isDark,
          icon: Icons.backup_rounded,
          iconColor: AppColors.primary,
          title: 'settings_export'.tr,
          subtitle: 'settings_export_detail'.tr,
          onTap: controller.exportBackup,
          showDivider: true,
        ),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.restore_from_trash_rounded,
          iconColor: AppColors.secondary,
          title: 'settings_import'.tr,
          subtitle: 'settings_import_detail'.tr,
          onTap: controller.importBackup,
          showDivider: false,
        ),
      ],
    );
  }

  // ─── About Card ───────────────────────────────────────────────────────────────
  Widget _buildAboutCard(bool isDark) {
    return _SettingsCard(
      isDark: isDark,
      children: [
        _SettingsTile(
          isDark: isDark,
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.primary,
          title: 'settings_about'.tr,
          subtitle: 'settings_health_reminder_version'.trParams({
            'version': AppConstants.appVersion.localizedDigits,
          }),
          showDivider: true,
        ),
        _SettingsTile(
          isDark: isDark,
          icon: Icons.privacy_tip_outlined,
          iconColor: AppColors.secondary,
          title: 'settings_privacy'.tr,
          subtitle: 'settings_privacy_detail'.tr,
          showDivider: false,
        ),
      ],
    );
  }
}

// ─── Reusable Settings Card ───────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ─── Reusable Settings Tile ───────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? titleColor;

  const _SettingsTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    required this.showDivider,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }
}

// ─── Permission Tile ──────────────────────────────────────────────────────────
class _PermissionTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback? onTap;
  final bool showDivider;

  const _PermissionTile({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: isGranted ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isGranted
                        ? AppColors.secondary.withOpacity(0.1)
                        : AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: isGranted
                        ? AppColors.secondary
                        : AppColors.danger,
                    size: 20,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                isGranted
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'granted'.tr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'fix'.tr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }
}
// ─── Language Row ─────────────────────────────────────────────────────────────
class _LanguageTile extends StatelessWidget {
  final bool isDark;
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDivider;

  const _LanguageTile({
    required this.isDark,
    required this.language,
    required this.isSelected,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    language.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.englishName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // A check rather than a radio: this takes effect the moment it
                // is tapped, so there is nothing left to confirm.
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }
}
