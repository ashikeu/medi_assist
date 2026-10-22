import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/localization/localized_digits.dart';
import 'package:medi_assist/core/localization/medical_labels.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import '../../../routes/app_pages.dart';
import '../controllers/medical_records_controller.dart';

class MedicalRecordsView extends StatelessWidget {
  const MedicalRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicalRecordsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDark),
      body: RefreshIndicator(
        onRefresh: () async => controller.loadAllRecords(),
        color: AppColors.medicalColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Summary Header ──
            SliverToBoxAdapter(
              child: _buildSummaryHeader(controller, isDark),
            ),

            // AI_Assisted: Month/Year Filter Row
            SliverToBoxAdapter(
              child: _buildMonthYearFilter(controller, isDark),
            ),

            // ── Section Title ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                   const Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: AppColors.medicalColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'medical_health_metrics'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    Obx(() => Text(
                          'medical_entry_count'.trParams({'count': controller.filteredRecords.length.localizedDigits}),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // ── Record Type Cards Grid ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final type = AppConstants.medicalRecordTypes[index];
                    return _RecordTypeCard(
                      type: type,
                      controller: controller,
                      isDark: isDark,
                      animIndex: index,
                    );
                  },
                  childCount: AppConstants.medicalRecordTypes.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
              ),
            ),

            // ── Recent Entries ──
            SliverToBoxAdapter(
              child: _buildRecentEntries(controller, isDark),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'medical_title'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'medical_subtitle'.tr,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.medicalColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.medicalGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── Summary Header ───────────────────────────────────────────────────────────
  Widget _buildSummaryHeader(
      MedicalRecordsController controller, bool isDark) {
    return Obx(() {
      final total = controller.allRecords.length;
      final countByType = controller.recordCountByType;
      final mostTracked = countByType.entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.medicalGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.medicalColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Total entries
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total.localizedDigits,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'total_entries'.tr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.category_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'medical_metrics_tracked'.trParams({'count': countByType.values.where((v) => v > 0).length.localizedDigits}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mostTracked.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'medical_most_tracked'.trParams({'name': MedicalLabels.type(mostTracked.first.key)}),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (total == 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'medical_start_logging'.tr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // AI_Assisted: Month/Year Filter Widget
  Widget _buildMonthYearFilter(
      MedicalRecordsController controller, bool isDark) {
    final months = [
      for (var m = 1; m <= 12; m++) 'month_short_$m'.tr,
    ];
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: AppColors.medicalColor,
          ),
          const SizedBox(width: 8),
          Text(
            'medical_filter_by_month'.tr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Month Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Obx(() => DropdownButton<int>(
                  value: controller.selectedMonth.value,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        months[index],
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) controller.setMonth(value);
                  },
                )),
          ),
          const SizedBox(width: 8),
          // Year Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Obx(() => DropdownButton<int>(
                  value: controller.selectedYear.value,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: years.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) controller.setYear(value);
                  },
                )),
          ),
        ],
      ),
    );
  }

  // ─── Recent Entries ───────────────────────────────────────────────────────────
  Widget _buildRecentEntries(
      MedicalRecordsController controller, bool isDark) {
    return Obx(() {
      // Use filteredRecords which already has month/year filtering applied
      final top5 = controller.filteredRecords.take(5).toList();

      if (top5.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.medicalColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'medical_recent_entries'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top5.map((record) {
              final label =
                  MedicalLabels.type(record.type);
              final icon =
                  AppConstants.medicalRecordIcons[record.type] ??
                      Icons.monitor_heart_rounded;
              final unit =
                  MedicalLabels.unit(record.type);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.medicalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          color: AppColors.medicalColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            TimeUtils.formatFull(record.dateTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${record.result.localizedDigits} $unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.medicalColor,
                          ),
                        ),
                        if (record.category != null)
                          Text(
                            MedicalLabels.category(record.category!),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

// ─── Record Type Card ─────────────────────────────────────────────────────────
class _RecordTypeCard extends StatefulWidget {
  final String type;
  final MedicalRecordsController controller;
  final bool isDark;
  final int animIndex;

  const _RecordTypeCard({
    required this.type,
    required this.controller,
    required this.isDark,
    required this.animIndex,
  });

  @override
  State<_RecordTypeCard> createState() => _RecordTypeCardState();
}

class _RecordTypeCardState extends State<_RecordTypeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    Future.delayed(
      Duration(milliseconds: 80 * widget.animIndex),
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
    final type = widget.type;
    final label = MedicalLabels.type(type);
    final icon = AppConstants.medicalRecordIcons[type] ??
        Icons.monitor_heart_rounded;
    final unit = MedicalLabels.unit(type);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Obx(() {
          final count = widget.controller.recordCountByType[type] ?? 0;
          final latest = widget.controller.latestRecordOfType(type);

          return GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              widget.controller.loadRecordsByType(type);
              Get.toNamed(
                Routes.medicalRecordDetail,
                arguments: {'type': type},
              );
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: count > 0
                        ? AppColors.medicalColor.withOpacity(0.3)
                        : (widget.isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    width: count > 0 ? 1.5 : 1,
                  ),
                  boxShadow: widget.isDark
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.medicalColor.withOpacity(0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: icon + count badge ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: count > 0
                                  ? AppColors.medicalGradient
                                  : null,
                              color: count > 0
                                  ? null
                                  : AppColors.medicalColor
                                      .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: count > 0
                                  ? Colors.white
                                  : AppColors.medicalColor,
                              size: 22,
                            ),
                          ),
                          if (count > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.medicalColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.medicalColor,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // ── Label ──
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // ── Latest value or "No data" ──
                      latest != null
                          ? Row(
                              children: [
                                Text(
                                  '${latest.result.localizedDigits} $unit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.medicalColor,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'medical_no_entries'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),

                      const SizedBox(height: 4),

                      // ── Date or unit ──
                      Text(
                        latest != null
                            ? latest.formattedDate
                            : 'medical_tap_to_add'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}