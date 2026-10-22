import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';
import '../localization/localized_digits.dart';
import 'reminder_scheduler.dart';
import 'storage_service.dart';
import '../../models/medicine_model.dart';
import '../../models/meal_model.dart';
import '../../models/activity_model.dart';
import '../../models/medical_record_model.dart';
import '../../models/prayer_reminder_model.dart';

enum BackupResult { success, cancelled, failed }

/// Export and import of all user data as a single JSON document.
class BackupService extends GetxService {
  static BackupService get to => Get.find();

  static const int _backupFormatVersion = 1;

  // ─── Export Data to JSON File ────────────────────────────────────────────────
  Future<BackupResult> exportData() async {
    try {
      final data = {
        'formatVersion': _backupFormatVersion,
        'appVersion': AppConstants.appVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'medicines':
            StorageService.to.getMedicines().map((m) => m.toJson()).toList(),
        'meals': StorageService.to.getMeals().map((m) => m.toJson()).toList(),
        'activities':
            StorageService.to.getActivities().map((a) => a.toJson()).toList(),
        'medicalRecords': StorageService.to
            .getMedicalRecords()
            .map((r) => r.toJson())
            .toList(),
        // Prayer reminders and custom entries are user data and live in the
        // data box, so they belong in a backup. The location and calculation
        // settings do not — those are settings, like the language, and are
        // tied to where this particular phone is.
        'prayerReminders': StorageService.to
            .getPrayerReminders()
            .map((r) => r.toJson())
            .toList(),
        'customPrayers': StorageService.to
            .getCustomPrayers()
            .map((e) => e.toJson())
            .toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final filename = 'mediassist_backup_$stamp.json';

      final dir = await _exportDirectory();
      await _clearPreviousExports(dir);

      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString, flush: true);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'backup_share_subject'.tr,
        text: 'backup_share_text'.tr,
      );

      // Only `dismissed` reliably means "user backed out". Android cannot tell
      // us which app received the file, so it reports `unavailable` even on a
      // successful share — treating that as failure told users every export had
      // failed. The file is written either way.
      if (result.status == ShareResultStatus.dismissed) {
        return BackupResult.cancelled;
      }
      return BackupResult.success;
    } catch (e) {
      debugPrint('❌ Export failed: $e');
      return BackupResult.failed;
    }
  }

  /// Backups live in their own subdirectory so cleanup can never touch files
  /// written by other parts of the app.
  Future<Directory> _exportDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// The previous export is removed on the *next* export rather than straight
  /// after sharing: the receiving app may still be reading the file when the
  /// share sheet closes, and deleting it there produced truncated backups.
  Future<void> _clearPreviousExports(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not clear previous exports: $e');
    }
  }

  // ─── Import Data from JSON File ──────────────────────────────────────────────
  Future<BackupResult> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        // Some Android file providers report .json as octet-stream and the
        // custom-extension filter then hides the user's own backup.
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return BackupResult.cancelled;
      }

      final filePath = result.files.single.path;
      if (filePath == null) return BackupResult.cancelled;

      final jsonString = await File(filePath).readAsString();
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup root is not an object');
      }

      // Parse everything up front. A malformed file must fail before any of the
      // user's existing data is touched.
      final parsed = _parseBackup(decoded);

      final confirmed = await _showImportConfirmation(parsed);
      if (!confirmed) return BackupResult.cancelled;

      await _restore(parsed);
      return BackupResult.success;
    } on FormatException catch (e) {
      debugPrint('❌ Import rejected — malformed backup: $e');
      return BackupResult.failed;
    } catch (e) {
      debugPrint('❌ Import failed: $e');
      return BackupResult.failed;
    }
  }

  _BackupPayload _parseBackup(Map<String, dynamic> data) {
    for (final key in ['medicines', 'meals', 'activities', 'medicalRecords']) {
      if (data[key] is! List) {
        throw FormatException('Backup is missing the "$key" list');
      }
    }

    return _BackupPayload(
      medicines: (data['medicines'] as List)
          .map((m) => Medicine.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      meals: (data['meals'] as List)
          .map((m) => Meal.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      activities: (data['activities'] as List)
          .map((a) => Activity.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      medicalRecords: (data['medicalRecords'] as List)
          .map((r) =>
              MedicalRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      // Optional, unlike the four above: backups written before the prayer
      // module existed are still perfectly valid and must keep importing.
      prayerReminders: _optionalList(
        data['prayerReminders'],
        (m) => PrayerReminder.fromJson(m),
      ),
      customPrayers: _optionalList(
        data['customPrayers'],
        (m) => CustomPrayerEvent.fromJson(m),
      ),
    );
  }

  static List<T> _optionalList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return const [];
    return raw
        .map((e) => parse(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Restore ─────────────────────────────────────────────────────────────────
  Future<void> _restore(_BackupPayload payload) async {
    final storage = StorageService.to;

    // Snapshot for rollback — a half-written restore would leave the user with
    // neither their old data nor the backup.
    final previous = _BackupPayload(
      medicines: storage.getMedicines(),
      meals: storage.getMeals(),
      activities: storage.getActivities(),
      medicalRecords: storage.getMedicalRecords(),
      prayerReminders: storage.getPrayerReminders(),
      customPrayers: storage.getCustomPrayers(),
    );

    // Reminders belonging to the outgoing data must go first, otherwise their
    // alarms keep firing for medicines that no longer exist.
    await ReminderScheduler.cancelEverything();

    try {
      await storage.saveMedicines(payload.medicines);
      await storage.saveMeals(payload.meals);
      await storage.saveActivities(payload.activities);
      await storage.saveMedicalRecords(payload.medicalRecords);
      await storage.savePrayerReminders(payload.prayerReminders);
      await storage.saveCustomPrayers(payload.customPrayers);
    } catch (e) {
      debugPrint('❌ Restore failed, rolling back: $e');
      await storage.saveMedicines(previous.medicines);
      await storage.saveMeals(previous.meals);
      await storage.saveActivities(previous.activities);
      await storage.saveMedicalRecords(previous.medicalRecords);
      await storage.savePrayerReminders(previous.prayerReminders);
      await storage.saveCustomPrayers(previous.customPrayers);
      await ReminderScheduler.rescheduleAllFromStorage();
      rethrow;
    }

    // Imported reminders have never been scheduled — without this the restored
    // medicines would sit in the list and never remind anyone.
    await ReminderScheduler.rescheduleAllFromStorage();

    debugPrint('✅ Restored ${payload.medicines.length} medicines, '
        '${payload.meals.length} meals, '
        '${payload.activities.length} activities, '
        '${payload.medicalRecords.length} records');
  }

  // ─── Show Import Confirmation Dialog ─────────────────────────────────────────
  Future<bool> _showImportConfirmation(_BackupPayload payload) async {
    return await Get.dialog<bool>(
          AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.file_upload_rounded, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Expanded(child: Text('settings_import'.tr)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'backup_contains'.tr,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${'backup_count_medicines'.trParams({
                        'count': payload.medicines.length.localizedDigits,
                      })}\n'
                  '• ${'backup_count_meals'.trParams({
                        'count': payload.meals.length.localizedDigits,
                      })}\n'
                  '• ${'backup_count_activities'.trParams({
                        'count': payload.activities.length.localizedDigits,
                      })}\n'
                  '• ${'backup_count_records'.trParams({
                        'count': payload.medicalRecords.length.localizedDigits,
                      })}\n'
                  '• ${'backup_count_prayer_reminders'.trParams({
                        'count': payload.prayerReminders.length.localizedDigits,
                      })}',
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'backup_replace_warning'.tr,
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('backup_replace_import'.tr),
              ),
            ],
          ),
          barrierDismissible: false,
        ) ??
        false;
  }

  // ─── Get Backup Count Summary ────────────────────────────────────────────────
  Map<String, int> getBackupSummary() {
    return {
      'medicines': StorageService.to.getMedicines().length,
      'meals': StorageService.to.getMeals().length,
      'activities': StorageService.to.getActivities().length,
      'medicalRecords': StorageService.to.getMedicalRecords().length,
    };
  }
}

class _BackupPayload {
  const _BackupPayload({
    required this.medicines,
    required this.meals,
    required this.activities,
    required this.medicalRecords,
    this.prayerReminders = const [],
    this.customPrayers = const [],
  });

  final List<Medicine> medicines;
  final List<Meal> meals;
  final List<Activity> activities;
  final List<MedicalRecord> medicalRecords;
  final List<PrayerReminder> prayerReminders;
  final List<CustomPrayerEvent> customPrayers;
}
