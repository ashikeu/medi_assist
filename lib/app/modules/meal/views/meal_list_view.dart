import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/models/meal_model.dart';
import '../../../routes/app_pages.dart';
import '../controllers/meal_controller.dart';


class MealListView extends StatelessWidget {
  const MealListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MealController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, controller, isDark),
      floatingActionButton: _buildFAB(controller),
      body: Column(
        children: [
          _buildSearchBar(controller, isDark),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.mealColor),
                );
              }
              if (controller.filteredMeals.isEmpty) {
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
      BuildContext context, MealController controller, bool isDark) {
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
            'notif_meal_title'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Obx(
            () => Text(
              '${controller.activeMealsCount} active reminder${controller.activeMealsCount != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mealColor,
                fontWeight: FontWeight.w500,
              ),
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
            gradient: AppColors.mealGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(MealController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: controller.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'meal_search'.tr,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.mealColor,
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
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.mealColor, width: 1.5),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        ),
      ),
    );
  }

  // ─── List ────────────────────────────────────────────────────────────────────
  Widget _buildList(MealController controller, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: controller.filteredMeals.length,
      itemBuilder: (context, index) {
        final meal = controller.filteredMeals[index];
        return _MealListItem(
          key: ValueKey(meal.id),
          meal: meal,
          controller: controller,
          isDark: isDark,
          animationIndex: index,
        );
      },
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(MealController controller) {
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
                color: AppColors.mealColorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                size: 52,
                color: AppColors.mealColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.searchQuery.value.isNotEmpty
                  ? 'meal_not_found'.tr
                  : 'meal_empty_title'.tr,
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
                  : 'meal_empty_detail'.tr,
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
                  Get.toNamed(Routes.addEditMeal);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('meal_add'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mealColor,
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
  Widget _buildFAB(MealController controller) {
    return FloatingActionButton.extended(
      onPressed: () {
        controller.prepareForAdd();
        Get.toNamed(Routes.addEditMeal);
      },
      backgroundColor: AppColors.mealColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'meal_add'.tr,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─── Meal List Item ───────────────────────────────────────────────────────────
class _MealListItem extends StatefulWidget {
  final Meal meal;
  final MealController controller;
  final bool isDark;
  final int animationIndex;

  const _MealListItem({
    super.key,
    required this.meal,
    required this.controller,
    required this.isDark,
    required this.animationIndex,
  });

  @override
  State<_MealListItem> createState() => _MealListItemState();
}

class _MealListItemState extends State<_MealListItem>
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
    final meal = widget.meal;
    final isDark = widget.isDark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Slidable(
            key: ValueKey(meal.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.45,
              children: [
                SlidableAction(
                  onPressed: (ctx) {
                    widget.controller.prepareForEdit(meal);
                    Get.toNamed(Routes.addEditMeal);
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
                  onPressed: (ctx) => widget.controller.deleteMeal(meal),
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
            child: _buildCard(meal, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Meal meal, bool isDark) {
    final notifColor = AppUtils.notifTypeColor(meal.notificationType);
    final notifIcon = AppUtils.notifTypeIcon(meal.notificationType);
    final notifLabel = AppUtils.notifTypeLabel(meal.notificationType);

    // Determine meal period icon
    final mealIcon = _getMealIcon(meal.time.hour);
    final mealPeriodLabel = _getMealPeriodLabel(meal.time.hour);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: meal.isActive
              ? AppColors.mealColor.withOpacity(0.25)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.mealColor.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Left icon ──
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        meal.isActive ? AppColors.mealGradient : null,
                    color: meal.isActive
                        ? null
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    mealIcon,
                    color: meal.isActive
                        ? Colors.white
                        : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
                if (!meal.isActive)
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

            // ── Center content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: meal.isActive ? null : Colors.grey.shade500,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Time chip + period label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mealColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: AppColors.mealColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.formatTimeOfDay(meal.time),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mealColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mealPeriodLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Notification type
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

            // ── Right: Toggle ──
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => widget.controller.toggleActive(meal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 24,
                    decoration: BoxDecoration(
                      color: meal.isActive
                          ? AppColors.mealColor
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: meal.isActive
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
                Text(
                  'swipe_hint'.tr,
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

  IconData _getMealIcon(int hour) {
    if (hour >= 5 && hour < 11) return Icons.free_breakfast_rounded;
    if (hour >= 11 && hour < 15) return Icons.lunch_dining_rounded;
    if (hour >= 15 && hour < 18) return Icons.coffee_rounded;
    if (hour >= 18 && hour < 22) return Icons.dinner_dining_rounded;
    return Icons.restaurant_rounded;
  }

  String _getMealPeriodLabel(int hour) {
    if (hour >= 5 && hour < 11) return 'preset_breakfast'.tr;
    if (hour >= 11 && hour < 15) return 'preset_lunch'.tr;
    if (hour >= 15 && hour < 18) return 'preset_snack'.tr;
    if (hour >= 18 && hour < 22) return 'preset_dinner'.tr;
    return 'meal_title'.tr;
  }
}