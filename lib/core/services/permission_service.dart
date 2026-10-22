import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../constants/app_colors.dart';
import '../services/notification_service.dart';

class PermissionService extends GetxService {
  static PermissionService get to => Get.find();

  // ─── Request all permissions at once ─────────────────────────────────────────
  Future<void> requestAllPermissions() async {
    await requestNotificationPermission();
    await requestExactAlarmPermission();
    await requestBatteryOptimizationPermission();
  }

  // ─── Notification permission ──────────────────────────────────────────────────
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.notification.request();
      debugPrint('📣 Notification permission: $status');
      return status.isGranted;
    }
    return await NotificationService.to.requestPermission();
  }

  Future<bool> get isNotificationGranted async {
    return await ph.Permission.notification.isGranted;
  }

  // ─── Exact alarm permission (Android 12+) ────────────────────────────────────
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await canScheduleExactAlarms) return true;
      return await NotificationService.to.requestExactAlarmPermission();
    } catch (e) {
      debugPrint('⚠️ Exact alarm permission request failed: $e');
      return false;
    }
  }

  Future<bool> get canScheduleExactAlarms async {
    if (!Platform.isAndroid) return true;
    try {
      return await NotificationService.to.canScheduleExactAlarms();
    } catch (_) {
      return false;
    }
  }

  // ─── Battery optimization ─────────────────────────────────────────────────────
  Future<bool> requestBatteryOptimizationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await isBatteryOptimizationIgnored) return true;
      await _showBatteryOptimizationDialog();
      return await isBatteryOptimizationIgnored;
    } catch (e) {
      debugPrint('⚠️ Battery optimization check failed: $e');
      return false;
    }
  }

  Future<bool> get isBatteryOptimizationIgnored async {
    if (!Platform.isAndroid) return true;
    try {
      return await ph.Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showBatteryOptimizationDialog() async {
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
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.battery_saver_outlined,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'battery_dialog_title'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'battery_dialog_message'.tr,
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
                    child: Text('skip'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    child: Text('open_settings'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    if (result == true) {
      await ph.Permission.ignoreBatteryOptimizations.request();
    }
  }

  // ─── Check all permissions ────────────────────────────────────────────────────
  Future<Map<String, bool>> checkAllPermissions() async {
    final results = await Future.wait([
      ph.Permission.notification.isGranted,
      isBatteryOptimizationIgnored,
      canScheduleExactAlarms,
    ]);
    return {
      'notification':        results[0],
      'batteryOptimization': results[1],
      'exactAlarm':          results[2],
    };
  }

  Future<bool> get areAllCriticalPermissionsGranted async {
    final notif      = await ph.Permission.notification.isGranted;
    final exactAlarm = await canScheduleExactAlarms;
    return notif && exactAlarm;
  }

  // ✅ FIXED: Renamed to avoid recursive call
  // Calls ph.openAppSettings() from permission_handler package
  Future<void> openApplicationSettings() async {
    await ph.openAppSettings();
  }
}