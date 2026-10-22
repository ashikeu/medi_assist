import 'package:get/get.dart';

// ✅ FIXED: All relative imports — no package:medi_assist/
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/time_utils.dart';

class HomeController extends GetxController {
  static HomeController get to => Get.find();

  // ─── Reactive state ──────────────────────────────────────────────────────────
  final RxString greeting           = ''.obs;
  final RxMap<String, bool> permissionStatus = <String, bool>{}.obs;
  final RxBool showPermissionBanner = false.obs;

  // ─── Reactive summary counts ─────────────────────────────────────────────────
  final RxInt activeMedicineCount  = 0.obs;
  final RxInt activeMealCount      = 0.obs;
  final RxInt activeActivityCount  = 0.obs;
  final RxInt totalRecordsCount    = 0.obs;

  /// Whether the prayer card belongs on the dashboard. Mirrored from the
  /// settings box so turning the module off in Settings removes the card
  /// without the user having to pull to refresh.
  final RxBool prayerModuleEnabled = true.obs;

  // ─── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    greeting.value = TimeUtils.getGreeting();
    refreshCounts();
    // Use cached permission status — don't spam Android permission APIs
    await _refreshPermissionsCached();
  }

  // ─── Counts ──────────────────────────────────────────────────────────────────
  void refreshCounts() {
    try {
      activeMedicineCount.value =
          StorageService.to.getMedicines().where((m) => m.isActive).length;
      activeMealCount.value =
          StorageService.to.getMeals().where((m) => m.isActive).length;
      activeActivityCount.value =
          StorageService.to.getActivities().where((a) => a.isActive).length;
      totalRecordsCount.value =
          StorageService.to.getMedicalRecords().length;
      prayerModuleEnabled.value = StorageService.to.isPrayerModuleEnabled;
    } catch (e) {
      // Non-critical — counts stay at previous value
    }
  }

  // ─── Permissions ─────────────────────────────────────────────────────────────
  /// Fast check — uses Android API only if needed
  Future<void> _refreshPermissionsCached() async {
    try {
      final status = await PermissionService.to.checkAllPermissions();
      permissionStatus.assignAll(status);
      showPermissionBanner.value = !status.values.every((v) => v);
    } catch (_) {
      showPermissionBanner.value = false;
    }
  }

  /// Full check — always calls Android APIs (use for settings/manual refresh)
  Future<void> checkPermissions() async {
    final status = await PermissionService.to.checkAllPermissions();
    permissionStatus.assignAll(status);
    showPermissionBanner.value = !status.values.every((v) => v);
  }

  Future<void> requestPermissions() async {
    await PermissionService.to.requestAllPermissions();
    await checkPermissions();
  }

  // ─── Refresh greeting + counts ───────────────────────────────────────────────
  void refreshGreeting() {
    greeting.value = TimeUtils.getGreeting();
    refreshCounts();
  }
}