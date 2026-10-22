import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/localization/medical_labels.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import '../controllers/medical_records_controller.dart';

class AddEditMedicalRecordView extends StatelessWidget {
  const AddEditMedicalRecordView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicalRecordsController>();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final type = args['type'] as String? ?? controller.currentType.value;
    final isEditing = controller.editingRecord != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final label = MedicalLabels.type(type);
    final icon =
        AppConstants.medicalRecordIcons[type] ?? Icons.monitor_heart_rounded;
    final unit = MedicalLabels.unit(type);
    final categories = controller.getCategoriesForType(type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isEditing, label, isDark),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              _buildHeaderCard(label, icon, isEditing, unit),
              const SizedBox(height: 24),

              // ── Category Dropdown (if applicable) ──
              if (categories.isNotEmpty) ...[
                _buildSectionLabel('category'.tr, Icons.category_rounded),
                const SizedBox(height: 10),
                _buildCategoryDropdown(
                    controller, categories, isDark),
                const SizedBox(height: 24),
              ],

              // ── Result Input ──
              _buildSectionLabel(
                  'medical_result_value'.tr, Icons.numbers_rounded),
              const SizedBox(height: 4),
              Text(
                _getResultHint(type),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 10),
              _buildResultField(controller, unit, type, isDark),
              const SizedBox(height: 24),

              // ── Date & Time ──
              _buildSectionLabel(
                  'date_and_time'.tr, Icons.calendar_today_rounded),
              const SizedBox(height: 10),
              _buildDateTimeCard(controller, context, isDark),
              const SizedBox(height: 24),

              // ── Notes ──
              _buildSectionLabel('notes_optional'.tr, Icons.notes_rounded),
              const SizedBox(height: 10),
              _buildNotesField(controller, isDark),
              const SizedBox(height: 32),

              // ── Save Button ──
              _buildSaveButton(controller, isEditing, type, label),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isEditing,
    String label,
    bool isDark,
  ) {
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
          child: const Icon(Icons.close_rounded, size: 20),
        ),
      ),
      title: Text(
        isEditing
            ? 'medical_edit_for'.trParams({'label': label})
            : 'medical_add_for'.trParams({'label': label}),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ─── Header Card ─────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(
      String label, IconData icon, bool isEditing, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.medicalGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'medical_update_for'.trParams({'label': label})
                      : 'medical_log_for'.trParams({'label': label}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'medical_unit'.trParams({'unit': unit}),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.medicalColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ─── Category Dropdown ────────────────────────────────────────────────────────
  Widget _buildCategoryDropdown(
    MedicalRecordsController controller,
    List<String> categories,
    bool isDark,
  ) {
    return Obx(() {
      // Ensure selected value is valid
      final currentVal = controller.selectedCategory.value.isEmpty
          ? categories.first
          : (categories.contains(controller.selectedCategory.value)
              ? controller.selectedCategory.value
              : categories.first);

      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentVal,
            isExpanded: true,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.medicalColor,
            ),
            dropdownColor:
                isDark ? AppColors.darkCard : AppColors.lightCard,
            items: categories
                .map(
                  (cat) => DropdownMenuItem<String>(
                    // The English string stays the value — it is what gets
                    // saved — while the label follows the current language.
                    value: cat,
                    child: Text(
                      MedicalLabels.category(cat),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) controller.setCategory(val);
            },
          ),
        ),
      );
    });
  }

  // ─── Result Field ─────────────────────────────────────────────────────────────
  Widget _buildResultField(
    MedicalRecordsController controller,
    String unit,
    String type,
    bool isDark,
  ) {
    final isNumeric = type != AppConstants.recordBloodPressure;

    return TextField(
      controller: controller.resultController,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: _getResultPlaceholder(type),
        prefixIcon: Icon(
          Icons.edit_outlined,
          color: AppColors.medicalColor,
          size: 20,
        ),
        suffixText: unit,
        suffixStyle: TextStyle(
          fontSize: 14,
          color: AppColors.medicalColor,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.medicalColor, width: 1.8),
        ),
      ),
    );
  }

  // ─── Date Time Card ───────────────────────────────────────────────────────────
  Widget _buildDateTimeCard(
    MedicalRecordsController controller,
    BuildContext context,
    bool isDark,
  ) {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.medicalColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // ── Date picker row ──
            InkWell(
              onTap: () => _pickDate(controller, context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.medicalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.medicalColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'date'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            TimeUtils.formatDate(
                                controller.selectedDateTime.value),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),

            Divider(
              height: 1,
              color: AppColors.medicalColor.withOpacity(0.15),
            ),

            // ── Time picker row ──
            InkWell(
              onTap: () => _pickTime(controller, context),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.medicalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.medicalColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'time'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            TimeUtils.formatDateTime(
                                controller.selectedDateTime.value),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickDate(
    MedicalRecordsController controller,
    BuildContext context,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDateTime.value,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: AppColors.medicalColor,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final current = controller.selectedDateTime.value;
      controller.setDateTime(DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      ));
    }
  }

  Future<void> _pickTime(
    MedicalRecordsController controller,
    BuildContext context,
  ) async {
    final current = controller.selectedDateTime.value;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: AppColors.medicalColor,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.setDateTime(DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ));
    }
  }

  // ─── Notes Field ──────────────────────────────────────────────────────────────
  Widget _buildNotesField(
      MedicalRecordsController controller, bool isDark) {
    return TextField(
      controller: controller.notesController,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'medical_notes_hint'.tr,
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(
            Icons.notes_rounded,
            color: AppColors.medicalColor,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.medicalColor, width: 1.8),
        ),
      ),
    );
  }

  // ─── Save Button ──────────────────────────────────────────────────────────────
  Widget _buildSaveButton(
    MedicalRecordsController controller,
    bool isEditing,
    String type,
    String label,
  ) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: controller.isLoading.value
              ? null
              : () => isEditing
                  ? controller.updateRecord(type)
                  : controller.addRecord(type),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.medicalColor,
            disabledBackgroundColor:
                AppColors.medicalColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: controller.isLoading.value
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEditing
                          ? Icons.save_rounded
                          : Icons.add_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing
                          ? 'save_changes'.tr
                          : 'medical_save_entry_for'.trParams({'label': label}),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _getResultHint(String type) => MedicalLabels.hint(type);

  String _getResultPlaceholder(String type) {
    switch (type) {
      case AppConstants.recordBloodPressure:
        return '120/80';
      case AppConstants.recordHeartRate:
        return '72';
      case AppConstants.recordOxygenLevel:
        return '98';
      case AppConstants.recordDiabetesLevel:
        return '95';
      case AppConstants.recordTemperature:
        return '36.6';
      case AppConstants.recordWeight:
        return '70.5';
      default:
        return '0';
    }
  }
}