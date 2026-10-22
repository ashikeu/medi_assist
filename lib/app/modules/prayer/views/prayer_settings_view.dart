import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/localized_digits.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../../../../models/prayer_settings_model.dart';
import '../controllers/prayer_controller.dart';

/// Calculation method, madhab, high-latitude rule, twilight angles and the
/// per-prayer minute adjustments.
class PrayerSettingsView extends StatelessWidget {
  const PrayerSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'prayer_settings_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'prayer_settings_reset'.tr,
            onPressed: controller.resetSettings,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: Obx(() {
        // One dependency for the whole screen: every control below reads the
        // same settings object, which is replaced wholesale on each change.
        controller.methodLabel.value;
        final settings = controller.settings;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildModuleToggle(controller, isDark),
            const SizedBox(height: 20),
            _sectionTitle('prayer_calc_method'.tr),
            const SizedBox(height: 10),
            _buildMethodCard(controller, settings, isDark),
            const SizedBox(height: 20),
            _sectionTitle('prayer_madhab'.tr),
            const SizedBox(height: 10),
            _buildMadhabCard(controller, settings, isDark),
            const SizedBox(height: 20),
            _sectionTitle('prayer_high_latitude'.tr),
            const SizedBox(height: 10),
            _buildHighLatitudeCard(controller, settings, isDark),
            const SizedBox(height: 20),
            _sectionTitle('prayer_angles'.tr),
            const SizedBox(height: 10),
            _buildAnglesCard(context, controller, settings, isDark),
            const SizedBox(height: 20),
            _sectionTitle('prayer_adjustments'.tr),
            const SizedBox(height: 10),
            _buildAdjustmentsCard(controller, settings, isDark),
          ],
        );
      }),
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

  // ─── Module on/off ────────────────────────────────────────────────────────
  Widget _buildModuleToggle(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Obx(
        () => SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.moduleEnabled.value,
          onChanged: controller.setModuleEnabled,
          activeThumbColor: AppColors.prayerColor,
          title: Text(
            'prayer_module_enabled'.tr,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'prayer_module_enabled_detail'.tr,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      ),
    );
  }

  // ─── Calculation method ───────────────────────────────────────────────────
  Widget _buildMethodCard(
    PrayerController controller,
    PrayerSettings settings,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          // Eager list: CalculationMethod.values is a dozen entries, and a
          // lazy builder inside Obx would not be tracked.
          ...CalculationMethod.values.map(
            (method) => _radioRow(
              label: method.nameKey.tr,
              detail: _methodDetail(method),
              selected: settings.method == method,
              onTap: () => controller.setMethod(method),
            ),
          ),
        ],
      ),
    );
  }

  String _methodDetail(CalculationMethod method) {
    if (method.ishaInterval > 0) {
      return 'prayer_method_interval_detail'.trParams({
        'fajr': _angleText(method.fajrAngle),
        'minutes': method.ishaInterval.localizedDigits,
      });
    }
    return 'prayer_method_angle_detail'.trParams({
      'fajr': _angleText(method.fajrAngle),
      'isha': _angleText(method.ishaAngle),
    });
  }

  static String _angleText(double angle) =>
      '${angle.toStringAsFixed(angle == angle.roundToDouble() ? 0 : 1).localizedDigits}°';

  // ─── Madhab ───────────────────────────────────────────────────────────────
  Widget _buildMadhabCard(
    PrayerController controller,
    PrayerSettings settings,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Column(
        children: Madhab.values
            .map(
              (madhab) => _radioRow(
                label: madhab.nameKey.tr,
                detail: 'madhab_${madhab.id}_detail'.tr,
                selected: settings.madhab == madhab,
                onTap: () => controller.setMadhab(madhab),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── High latitude ────────────────────────────────────────────────────────
  Widget _buildHighLatitudeCard(
    PrayerController controller,
    PrayerSettings settings,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _radioRow(
            label: 'high_lat_auto'.tr,
            detail: 'high_lat_auto_detail'.tr,
            selected: settings.highLatitudeRule == null,
            onTap: () => controller.setHighLatitudeRule(null),
          ),
          ...HighLatitudeRule.values.map(
            (rule) => _radioRow(
              label: rule.nameKey.tr,
              detail: '${rule.nameKey}_detail'.tr,
              selected: settings.highLatitudeRule == rule,
              onTap: () => controller.setHighLatitudeRule(rule),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Angles ───────────────────────────────────────────────────────────────
  Widget _buildAnglesCard(
    BuildContext context,
    PrayerController controller,
    PrayerSettings settings,
    bool isDark,
  ) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _valueRow(
            label: 'prayer_fajr_angle'.tr,
            value: _angleText(settings.fajrAngle),
            isOverridden: settings.customFajrAngle != null,
            onTap: () => _editAngle(
              context: context,
              title: 'prayer_fajr_angle'.tr,
              current: settings.fajrAngle,
              onSave: controller.setFajrAngle,
            ),
          ),
          _valueRow(
            label: 'prayer_isha_angle'.tr,
            value: settings.ishaInterval > 0
                ? '—'
                : _angleText(settings.ishaAngle),
            isOverridden: settings.customIshaAngle != null,
            onTap: settings.ishaInterval > 0
                ? null
                : () => _editAngle(
                      context: context,
                      title: 'prayer_isha_angle'.tr,
                      current: settings.ishaAngle,
                      onSave: controller.setIshaAngle,
                    ),
          ),
          _valueRow(
            label: 'prayer_isha_interval'.tr,
            value: settings.ishaInterval > 0
                ? 'prayer_minutes_after_maghrib'.trParams(
                    {'minutes': settings.ishaInterval.localizedDigits})
                : 'prayer_use_angle'.tr,
            isOverridden: settings.customIshaInterval != null,
            showDivider: false,
            onTap: () => _editInterval(
              context: context,
              controller: controller,
              current: settings.ishaInterval,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAngle({
    required BuildContext context,
    required String title,
    required double current,
    required Future<void> Function(double?) onSave,
  }) async {
    final field = TextEditingController(text: current.toString());
    final result = await Get.dialog<double?>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: '°',
            helperText: 'prayer_angle_range'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(field.text.trim());
              if (parsed == null || parsed < 0 || parsed > 30) {
                Get.back(result: null);
                return;
              }
              Get.back(result: parsed);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.prayerColor),
            child: Text('ok'.tr),
          ),
        ],
      ),
    );
    field.dispose();
    if (result != null) await onSave(result);
  }

  Future<void> _editInterval({
    required BuildContext context,
    required PrayerController controller,
    required int current,
  }) async {
    final options = <int?>[null, 0, 60, 75, 90, 120];
    final result = await Get.dialog<Object?>(
      SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('prayer_isha_interval'.tr,
            style: const TextStyle(fontSize: 16)),
        children: options
            .map(
              (option) => SimpleDialogOption(
                onPressed: () => Get.back(result: option ?? 'auto'),
                child: Text(
                  option == null
                      ? 'prayer_isha_interval_auto'.tr
                      : option == 0
                          ? 'prayer_use_angle'.tr
                          : 'prayer_minutes_after_maghrib'
                              .trParams({'minutes': option.localizedDigits}),
                  style: TextStyle(
                    fontWeight: (option ?? -1) == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (result == null) return;
    await controller.setIshaInterval(result == 'auto' ? null : result as int);
  }

  // ─── Manual adjustments ───────────────────────────────────────────────────
  Widget _buildAdjustmentsCard(
    PrayerController controller,
    PrayerSettings settings,
    bool isDark,
  ) {
    const kinds = [
      PrayerKind.fajr,
      PrayerKind.sunrise,
      PrayerKind.dhuhr,
      PrayerKind.asr,
      PrayerKind.maghrib,
      PrayerKind.isha,
    ];

    return _card(
      isDark: isDark,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'prayer_adjustments_detail'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ),
          ...kinds.map((kind) {
            final minutes =
                settings.adjustments.forPrayer(kind);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      kind.nameKey.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: minutes <= -60
                        ? null
                        : () => controller.setAdjustment(kind, minutes - 1),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.prayerColor,
                    iconSize: 20,
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      _signedMinutes(minutes),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: minutes == 0 ? Colors.grey.shade500 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: minutes >= 60
                        ? null
                        : () => controller.setAdjustment(kind, minutes + 1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: AppColors.prayerColor,
                    iconSize: 20,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _signedMinutes(int minutes) {
    final value = minutes.abs().localizedDigits;
    final unit = 'unit_minute_short'.tr;
    if (minutes == 0) return '0$unit'.localizedDigits;
    return minutes > 0 ? '+$value$unit' : '-$value$unit';
  }

  // ─── Rows ─────────────────────────────────────────────────────────────────
  Widget _radioRow({
    required String label,
    required String detail,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.prayerColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.prayerColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueRow({
    required String label,
    required String value,
    required bool isOverridden,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? Colors.grey.shade500 : null,
                    ),
                  ),
                ),
                if (isOverridden)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'prayer_custom_angle'.tr,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.prayerColor,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey.shade400),
                ],
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}
