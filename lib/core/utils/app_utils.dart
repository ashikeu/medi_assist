import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';

class AppUtils {
  AppUtils._();

  // ─── Snackbars ───────────────────────────────────────────────────────────────

  static void showSuccess(String message, {String? title}) {
    Get.snackbar(
      title ?? 'success'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.secondary,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 400),
    );
  }

  static void showError(String message, {String? title}) {
    Get.snackbar(
      title ?? 'error'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.danger,
      colorText: Colors.white,
      icon: const Icon(Icons.error_rounded, color: Colors.white),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 400),
    );
  }

  static void showWarning(String message, {String? title}) {
    Get.snackbar(
      title ?? 'warning'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.warning,
      colorText: Colors.white,
      icon: const Icon(Icons.warning_rounded, color: Colors.white),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(String message, {String? title}) {
    Get.snackbar(
      title ?? 'info'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      icon: const Icon(Icons.info_rounded, color: Colors.white),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  /// Modal outcome popup for save actions — the success/failure counterpart to
  /// [showConfirmDialog].
  ///
  /// Deliberately fire-and-forget (`void`, not `Future`): callers show it right
  /// after `Get.back()`, and awaiting it inside a `try` would hold the save
  /// method's `finally` — and so `isLoading` — until the user taps OK, leaving a
  /// spinner running behind the dialog. It is also queued to the next frame so
  /// the dialog route is never pushed in the same frame the form is popped.
  static void showResultDialog({
    required bool success,
    required String title,
    required String message,
  }) {
    final color = success ? AppColors.secondary : AppColors.danger;
    final icon =
        success ? Icons.check_circle_rounded : Icons.error_outline_rounded;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: Text('ok'.tr),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  static Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color confirmColor = AppColors.danger,
    IconData icon = Icons.delete_outline_rounded,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(cancelText ?? 'cancel'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                    ),
                    child: Text(confirmText ?? 'delete'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    return result ?? false;
  }

  // ─── Notification Type Helpers ───────────────────────────────────────────────

  static String notifTypeLabel(String type) {
    switch (type) {
      case 'notification':
        return 'notif_type_notification'.tr;
      case 'alarm':
        return 'notif_type_alarm'.tr;
      case 'both':
        return 'notif_type_both'.tr;
      case 'none':
        return 'notif_type_none'.tr;
      default:
        return 'notif_type_notification'.tr;
    }
  }

  static IconData notifTypeIcon(String type) {
    switch (type) {
      case 'notification':
        return Icons.notifications_outlined;
      case 'alarm':
        return Icons.alarm_outlined;
      case 'both':
        return Icons.notifications_active_outlined;
      case 'none':
        return Icons.notifications_off_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color notifTypeColor(String type) {
    switch (type) {
      case 'notification':
        return AppColors.primary;
      case 'alarm':
        return AppColors.warning;
      case 'both':
        return AppColors.secondary;
      case 'none':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  // ─── Module Color/Icon Helpers ───────────────────────────────────────────────

  static Color moduleColor(String module) {
    switch (module) {
      case 'medicine':
        return AppColors.medicineColor;
      case 'meal':
        return AppColors.mealColor;
      case 'medical':
        return AppColors.medicalColor;
      case 'activity':
        return AppColors.activityColor;
      case 'prayer':
        return AppColors.prayerColor;
      default:
        return AppColors.primary;
    }
  }
}