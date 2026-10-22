import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/permission_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/backup_service.dart';
import '../services/device_location_service.dart';
import '../services/prayer_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageService>(StorageService(), permanent: true);
    Get.put<NotificationService>(NotificationService(), permanent: true);
    Get.put<AlarmService>(AlarmService(), permanent: true);
    Get.put<PermissionService>(PermissionService(), permanent: true);
    Get.put<AlarmSoundService>(AlarmSoundService(), permanent: true);
    Get.put<BackupService>(BackupService(), permanent: true);
    // After StorageService — PrayerService reads the saved location and
    // calculation settings in its onInit.
    Get.put<PrayerService>(PrayerService(), permanent: true);
    Get.put<DeviceLocationService>(DeviceLocationService(), permanent: true);
  }
}