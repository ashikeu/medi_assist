import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/location_catalog.dart';
import '../controllers/prayer_controller.dart';

/// Where the user chooses the place prayer times are calculated for: GPS,
/// the bundled country → division → district → area catalogue, or a
/// hand-entered coordinate.
class PrayerLocationView extends StatelessWidget {
  const PrayerLocationView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'prayer_location_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildCurrentCard(controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('prayer_location_gps'.tr),
          const SizedBox(height: 10),
          _buildGpsCard(controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('prayer_location_browse'.tr),
          const SizedBox(height: 10),
          _buildCatalogCard(controller, isDark),
          const SizedBox(height: 20),
          _sectionTitle('prayer_location_manual'.tr),
          const SizedBox(height: 10),
          _buildManualCard(controller, isDark),
        ],
      ),
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

  // ─── Current selection ────────────────────────────────────────────────────
  Widget _buildCurrentCard(PrayerController controller, bool isDark) {
    return Obx(() {
      // Depend on the label so the card repaints as soon as a new place is
      // applied, rather than only on the next push of this route.
      final label = controller.locationLabel.value;
      final location = controller.location;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.prayerGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  location.source.nameKey.tr,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              location.coordinateLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'prayer_timezone_label'
                  .trParams({'zone': controller.timeZoneLabel}),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    });
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────
  Widget _buildGpsCard(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'prayer_location_gps_detail'.tr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isLocating.value
                    ? null
                    : controller.useCurrentLocation,
                icon: controller.isLocating.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(controller.isLocating.value
                    ? 'prayer_location_locating'.tr
                    : 'prayer_location_use_gps'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.prayerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'prayer_location_gps_override'.tr,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Catalogue ────────────────────────────────────────────────────────────
  Widget _buildCatalogCard(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Obx(() {
        // Every dropdown below reads these, so touching them here registers
        // the whole card as a dependency in one place.
        final countryCode = controller.pickerCountryCode.value;
        final division = controller.pickerDivision.value;
        final district = controller.pickerDistrict.value;
        final area = controller.pickerArea.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dropdown<String>(
              label: 'prayer_country'.tr,
              value: countryCode.isEmpty ? null : countryCode,
              isDark: isDark,
              items: [
                for (final country in controller.countries)
                  DropdownMenuItem(
                    value: country.code,
                    child: Text(country.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.setPickerCountry(value);
              },
            ),
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'prayer_division'.tr,
              value: division.isEmpty ? null : division,
              isDark: isDark,
              items: [
                for (final CatalogDivision item in controller.divisions)
                  DropdownMenuItem(value: item.name, child: Text(item.name)),
              ],
              onChanged: (value) {
                if (value != null) controller.setPickerDivision(value);
              },
            ),
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'prayer_district'.tr,
              value: district.isEmpty ? null : district,
              isDark: isDark,
              items: [
                for (final CatalogDistrict item in controller.districts)
                  DropdownMenuItem(value: item.name, child: Text(item.name)),
              ],
              onChanged: (value) {
                if (value != null) controller.setPickerDistrict(value);
              },
            ),
            if (controller.areas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'prayer_area'.tr,
                value: area.isEmpty ? null : area,
                isDark: isDark,
                items: [
                  for (final CatalogArea item in controller.areas)
                    DropdownMenuItem(value: item.name, child: Text(item.name)),
                ],
                onChanged: (value) {
                  if (value != null) controller.setPickerArea(value);
                },
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.applyCatalogSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.prayerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('prayer_location_apply'.tr),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'prayer_location_regional_note'.tr,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── Manual coordinates ───────────────────────────────────────────────────
  Widget _buildManualCard(PrayerController controller, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: controller.latitudeController,
                  label: 'prayer_latitude'.tr,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: controller.longitudeController,
                  label: 'prayer_longitude'.tr,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: controller.offsetController,
            label: 'prayer_utc_offset'.tr,
            isDark: isDark,
            hint: 'prayer_utc_offset_hint'.tr,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: controller.applyManualCoordinates,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.prayerColor,
                side: const BorderSide(color: AppColors.prayerColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('prayer_location_apply_manual'.tr),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared bits ──────────────────────────────────────────────────────────
  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: child,
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      // Coordinates the user types stay in ASCII digits — they are parsed back
      // into numbers, so Bengali digits would not round-trip.
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
