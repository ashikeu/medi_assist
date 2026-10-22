import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/localization/localized_digits.dart';
import 'package:medi_assist/core/localization/medical_labels.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/models/medical_record_model.dart';
import '../../../routes/app_pages.dart';
import '../controllers/medical_records_controller.dart';


class MedicalRecordDetailView extends StatelessWidget {
  const MedicalRecordDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicalRecordsController>();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final type = args['type'] as String? ?? controller.currentType.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final label = MedicalLabels.type(type);
    final icon =
        AppConstants.medicalRecordIcons[type] ?? Icons.monitor_heart_rounded;
    final unit = MedicalLabels.unit(type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, label, icon, isDark),
      floatingActionButton: _buildFAB(controller, type),
      body: Column(
        children: [
          // ── Stats strip ──
          _buildStatsStrip(controller, unit, isDark),
          // ── Records list ──
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.medicalColor,
                  ),
                );
              }
              if (controller.filteredRecords.isEmpty) {
                return _buildEmptyState(controller, type, label);
              }
              return _buildList(
                  controller, isDark, label, icon, unit);
            }),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String label,
    IconData icon,
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
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.medicalGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Strip ──────────────────────────────────────────────────────────────
  Widget _buildStatsStrip(
    MedicalRecordsController controller,
    String unit,
    bool isDark,
  ) {
    return Obx(() {
      final records = controller.filteredRecords;
      if (records.isEmpty) return const SizedBox.shrink();

      // Try parsing numeric values
      double? avg;
      double? min;
      double? max;

      try {
        // Only for single-value results (not blood pressure like "120/80")
        final nums = records
            .map((r) => double.tryParse(r.result.split('/').first.trim()))
            .whereType<double>()
            .toList();

        if (nums.isNotEmpty) {
          avg = nums.reduce((a, b) => a + b) / nums.length;
          min = nums.reduce((a, b) => a < b ? a : b);
          max = nums.reduce((a, b) => a > b ? a : b);
        }
      } catch (_) {}

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.medicalColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            _StatItem(
              label: 'entries'.tr,
              value: records.length.localizedDigits,
              color: AppColors.medicalColor,
            ),
            _StatDivider(),
            _StatItem(
              label: 'latest'.tr,
              value: '${records.first.result.localizedDigits} $unit',
              color: AppColors.primary,
            ),
            if (avg != null) ...[
              _StatDivider(),
              _StatItem(
                label: 'average'.tr,
                value:
                    '${avg.toStringAsFixed(1).localizedDigits} $unit',
                color: AppColors.secondary,
              ),
            ],
            if (max != null && min != null) ...[
              _StatDivider(),
              _StatItem(
                label: 'range'.tr,
                value: '${min.toStringAsFixed(0).localizedDigits}–'
                    '${max.toStringAsFixed(0).localizedDigits}',
                color: AppColors.accentDark,
              ),
            ],
          ],
        ),
      );
    });
  }

  // ─── List ────────────────────────────────────────────────────────────────────
  Widget _buildList(
    MedicalRecordsController controller,
    bool isDark,
    String label,
    IconData icon,
    String unit,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: controller.filteredRecords.length,
      itemBuilder: (context, index) {
        final record = controller.filteredRecords[index];
        return _RecordListItem(
          key: ValueKey(record.id),
          record: record,
          controller: controller,
          isDark: isDark,
          unit: unit,
          animationIndex: index,
        );
      },
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(
    MedicalRecordsController controller,
    String type,
    String label,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.medicalColorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppConstants.medicalRecordIcons[type] ??
                    Icons.monitor_heart_rounded,
                size: 52,
                color: AppColors.medicalColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'medical_empty_for'.trParams({'label': label}),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'medical_start_tracking_for'.trParams({'label': label}),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                controller.prepareForAdd(type);
                Get.toNamed(
                  Routes.addEditMedicalRecord,
                  arguments: {'type': type},
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'medical_add_entry_for'.trParams({'label': label}),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.medicalColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFAB(MedicalRecordsController controller, String type) {
    return FloatingActionButton.extended(
      onPressed: () {
        controller.prepareForAdd(type);
        Get.toNamed(
          Routes.addEditMedicalRecord,
          arguments: {'type': type},
        );
      },
      backgroundColor: AppColors.medicalColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'medical_add_entry'.tr,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─── Record List Item ─────────────────────────────────────────────────────────
class _RecordListItem extends StatefulWidget {
  final MedicalRecord record;
  final MedicalRecordsController controller;
  final bool isDark;
  final String unit;
  final int animationIndex;

  const _RecordListItem({
    super.key,
    required this.record,
    required this.controller,
    required this.isDark,
    required this.unit,
    required this.animationIndex,
  });

  @override
  State<_RecordListItem> createState() => _RecordListItemState();
}

class _RecordListItemState extends State<_RecordListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    Future.delayed(
      Duration(milliseconds: 55 * widget.animationIndex),
      () {
        if (mounted) _animController.forward();
      },
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isDark = widget.isDark;
    final type = record.type;
    final icon = AppConstants.medicalRecordIcons[type] ??
        Icons.monitor_heart_rounded;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Slidable(
            key: ValueKey(record.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.45,
              children: [
                SlidableAction(
                  onPressed: (ctx) {
                    widget.controller.prepareForEdit(record);
                    Get.toNamed(
                      Routes.addEditMedicalRecord,
                      arguments: {'type': record.type},
                    );
                  },
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'edit'.tr,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                SlidableAction(
                  onPressed: (ctx) =>
                      widget.controller.deleteRecord(record),
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'delete'.tr,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.medicalColor.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ── Icon ──
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.medicalGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // ── Center ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DateTime
                          Text(
                            TimeUtils.formatFull(record.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Category
                          if (record.category != null &&
                              record.category!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.medicalColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                MedicalLabels.category(record.category!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.medicalColor,
                                ),
                              ),
                            ),
                          // Notes preview
                          if (record.notes != null &&
                              record.notes!.isNotEmpty)
                            Text(
                              record.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // ── Right: Result value ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          record.result,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.medicalColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          widget.unit,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat helpers ─────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withOpacity(0.15),
    );
  }
}