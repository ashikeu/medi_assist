import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/localization/localized_digits.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/models/medicine_model.dart';
import '../../../routes/app_pages.dart';
import '../controllers/medicine_controller.dart';


class MedicineListView extends StatelessWidget {
  const MedicineListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicineController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, controller, isDark),
      floatingActionButton: _buildFAB(controller),
      body: Column(
        children: [
          // ── Search Bar ──
          _buildSearchBar(controller, isDark),
          // ── List ──
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.medicineColor,
                  ),
                );
              }
              if (controller.filteredMedicines.isEmpty) {
                return _buildEmptyState(controller);
              }
              return _buildList(controller, isDark);
            }),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MedicineController controller,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard
                : AppColors.lightCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
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
            'notif_medicine_title'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Obx(
            () => Text(
              'dashboard_active_reminders'.trParams({
                'count': controller.activeMedicinesCount.value.localizedDigits,
                'noun': controller.activeMedicinesCount.value == 1
                    ? 'reminder_singular'.tr
                    : 'reminder_plural'.tr,
              }),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.medicineColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Header icon
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.medicineGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.medication_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(MedicineController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: controller.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'medicine_search'.tr,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.medicineColor,
            size: 20,
          ),
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      controller.clearSearch();
                      FocusScope.of(Get.context!).unfocus();
                    },
                    child: const Icon(Icons.close_rounded, size: 18),
                  )
                : const SizedBox.shrink(),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.medicineColor,
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        ),
      ),
    );
  }

  // ─── List ────────────────────────────────────────────────────────────────────
  Widget _buildList(MedicineController controller, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: controller.filteredMedicines.length,
      itemBuilder: (context, index) {
        final medicine = controller.filteredMedicines[index];
        return _MedicineListItem(
          key: ValueKey(medicine.id),
          medicine: medicine,
          controller: controller,
          isDark: isDark,
          animationIndex: index,
        );
      },
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(MedicineController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon illustration
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.medicineColorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 52,
                color: AppColors.medicineColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.searchQuery.value.isNotEmpty
                  ? 'medicine_not_found'.tr
                  : 'medicine_empty_title'.tr,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.searchQuery.value.isNotEmpty
                  ? 'try_different_search'.tr
                  : 'medicine_empty_detail'.tr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (controller.searchQuery.value.isEmpty) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  controller.prepareForAdd();
                  Get.toNamed(Routes.addEditMedicine);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('medicine_add'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.medicineColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFAB(MedicineController controller) {
    return FloatingActionButton.extended(
      onPressed: () {
        controller.prepareForAdd();
        Get.toNamed(Routes.addEditMedicine);
      },
      backgroundColor: AppColors.medicineColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'medicine_add'.tr,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─── Medicine List Item ───────────────────────────────────────────────────────
class _MedicineListItem extends StatefulWidget {
  final Medicine medicine;
  final MedicineController controller;
  final bool isDark;
  final int animationIndex;

  const _MedicineListItem({
    super.key,
    required this.medicine,
    required this.controller,
    required this.isDark,
    required this.animationIndex,
  });

  @override
  State<_MedicineListItem> createState() => _MedicineListItemState();
}

class _MedicineListItemState extends State<_MedicineListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    // Stagger entry by index
    Future.delayed(
      Duration(milliseconds: 60 * widget.animationIndex),
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
    final medicine = widget.medicine;
    final isDark = widget.isDark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Slidable(
            key: ValueKey(medicine.id),
            // ── Swipe left → Edit + Delete ──
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.45,
              children: [
                // Edit action
                SlidableAction(
                  onPressed: (ctx) {
                    widget.controller.prepareForEdit(medicine);
                    Get.toNamed(Routes.addEditMedicine);
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
                // Delete action
                SlidableAction(
                  onPressed: (ctx) {
                    widget.controller.deleteMedicine(medicine);
                  },
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
            child: _buildCard(medicine, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Medicine medicine, bool isDark) {
    final notifColor = AppUtils.notifTypeColor(medicine.notificationType);
    final notifIcon = AppUtils.notifTypeIcon(medicine.notificationType);
    final notifLabel = AppUtils.notifTypeLabel(medicine.notificationType);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: medicine.isActive
              ? AppColors.medicineColor.withOpacity(0.25)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.medicineColor.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Left: Icon + active indicator ──
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: medicine.isActive
                        ? AppColors.medicineGradient
                        : null,
                    color: medicine.isActive
                        ? null
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: medicine.isActive
                        ? Colors.white
                        : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
                if (!medicine.isActive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // ── Center: Name + times ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: medicine.isActive
                          ? null
                          : Colors.grey.shade500,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Time chips
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: medicine.times.take(3).map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.medicineColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          medicine._formatSingleTime(t),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.medicineColor,
                          ),
                        ),
                      );
                    }).toList()
                      ..addAll(
                        medicine.times.length > 3
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${medicine.times.length - 3}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ]
                            : [],
                      ),
                  ),
                  const SizedBox(height: 6),
                  // Notification type badge
                  Row(
                    children: [
                      Icon(notifIcon, size: 12, color: notifColor),
                      const SizedBox(width: 4),
                      Text(
                        notifLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: notifColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Right: Toggle + Edit button ──
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Active toggle
                GestureDetector(
                  onTap: () => widget.controller.toggleActive(medicine),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 24,
                    decoration: BoxDecoration(
                      color: medicine.isActive
                          ? AppColors.medicineColor
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: medicine.isActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Swipe hint
                Text(
                  '← swipe',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Extension for formatting single time inside widget
extension _MedicineTimeFormat on Medicine {
  // Delegates rather than formatting here: Bangla writes a clock time
  // differently enough (day-part name first, Bengali digits) that a second
  // copy of the arithmetic would quietly stay English.
  String _formatSingleTime(TimeOfDay t) => TimeUtils.formatTimeOfDay(t);
}