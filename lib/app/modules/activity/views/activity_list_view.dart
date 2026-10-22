import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:medi_assist/app/routes/app_pages.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:medi_assist/core/utils/app_utils.dart';
import 'package:medi_assist/core/utils/time_utils.dart';
import 'package:medi_assist/models/activity_model.dart';
import '../controllers/activity_controller.dart';


class ActivityListView extends StatelessWidget {
  const ActivityListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ActivityController>();
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
                  child: CircularProgressIndicator(
                    color: AppColors.activityColor,
                  ),
                );
              }
              if (controller.filteredActivities.isEmpty) {
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
    ActivityController controller,
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'notif_activity_title'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Obx(
            () => Text(
              '${controller.activeActivitiesCount} active reminder${controller.activeActivitiesCount != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.activityColor,
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
            gradient: AppColors.activityGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(ActivityController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: controller.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'activity_search'.tr,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.activityColor,
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
            borderSide: const BorderSide(
              color: AppColors.activityColor,
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
  Widget _buildList(ActivityController controller, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: controller.filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = controller.filteredActivities[index];
        return _ActivityListItem(
          key: ValueKey(activity.id),
          activity: activity,
          controller: controller,
          isDark: isDark,
          animationIndex: index,
        );
      },
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(ActivityController controller) {
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
                color: AppColors.activityColorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                size: 52,
                color: AppColors.activityColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.searchQuery.value.isNotEmpty
                  ? 'activity_not_found'.tr
                  : 'activity_empty_title'.tr,
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
                  : 'activity_empty_detail'.tr,
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
                  Get.toNamed(Routes.addEditActivity);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('activity_add'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.activityColor,
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
  Widget _buildFAB(ActivityController controller) {
    return FloatingActionButton.extended(
      onPressed: () {
        controller.prepareForAdd();
        Get.toNamed(Routes.addEditActivity);
      },
      backgroundColor: AppColors.activityColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'activity_add'.tr,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─── Activity List Item ───────────────────────────────────────────────────────
class _ActivityListItem extends StatefulWidget {
  final Activity activity;
  final ActivityController controller;
  final bool isDark;
  final int animationIndex;

  const _ActivityListItem({
    super.key,
    required this.activity,
    required this.controller,
    required this.isDark,
    required this.animationIndex,
  });

  @override
  State<_ActivityListItem> createState() => _ActivityListItemState();
}

class _ActivityListItemState extends State<_ActivityListItem>
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
    final activity = widget.activity;
    final isDark = widget.isDark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Slidable(
            key: ValueKey(activity.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.45,
              children: [
                SlidableAction(
                  onPressed: (ctx) {
                    widget.controller.prepareForEdit(activity);
                    Get.toNamed(Routes.addEditActivity);
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
                      widget.controller.deleteActivity(activity),
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
            child: _buildCard(activity, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Activity activity, bool isDark) {
    final notifColor = AppUtils.notifTypeColor(activity.notificationType);
    final notifIcon = AppUtils.notifTypeIcon(activity.notificationType);
    final notifLabel = AppUtils.notifTypeLabel(activity.notificationType);
    final activityIcon = _getActivityIcon(activity.name);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activity.isActive
              ? AppColors.activityColor.withOpacity(0.25)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.activityColor.withOpacity(0.06),
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
                    gradient: activity.isActive
                        ? AppColors.activityGradient
                        : null,
                    color: activity.isActive
                        ? null
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    activityIcon,
                    color: activity.isActive
                        ? Colors.white
                        : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
                if (!activity.isActive)
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
                    activity.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: activity.isActive ? null : Colors.grey.shade500,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Time chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.activityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: AppColors.activityColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.formatTimeOfDay(activity.time),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.activityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Duration/intensity badge
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
                          _getActivityCategory(activity.name),
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
                  onTap: () => widget.controller.toggleActive(activity),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 24,
                    decoration: BoxDecoration(
                      color: activity.isActive
                          ? AppColors.activityColor
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: activity.isActive
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

  IconData _getActivityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('run') || lower.contains('jog')) {
      return Icons.directions_run_rounded;
    }
    if (lower.contains('walk')) return Icons.directions_walk_rounded;
    if (lower.contains('swim')) return Icons.pool_rounded;
    if (lower.contains('cycl') || lower.contains('bike')) {
      return Icons.directions_bike_rounded;
    }
    if (lower.contains('yoga') || lower.contains('meditat')) {
      return Icons.self_improvement_rounded;
    }
    if (lower.contains('gym') || lower.contains('workout') ||
        lower.contains('weight') || lower.contains('lift')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('stretch')) return Icons.accessibility_new_rounded;
    if (lower.contains('dance')) return Icons.music_note_rounded;
    if (lower.contains('hike') || lower.contains('trek')) {
      return Icons.landscape_rounded;
    }
    return Icons.sports_rounded;
  }

  String _getActivityCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('run') || lower.contains('jog')) return 'preset_cardio'.tr;
    if (lower.contains('walk')) return 'preset_low_impact'.tr;
    if (lower.contains('swim')) return 'preset_full_body'.tr;
    if (lower.contains('cycl') || lower.contains('bike')) return 'preset_cardio'.tr;
    if (lower.contains('yoga') || lower.contains('meditat')) {
      return 'preset_mindfulness'.tr;
    }
    if (lower.contains('gym') || lower.contains('workout') ||
        lower.contains('weight')) {
      return 'preset_strength'.tr;
    }
    if (lower.contains('stretch')) return 'preset_flexibility'.tr;
    return 'preset_fitness'.tr;
  }
}