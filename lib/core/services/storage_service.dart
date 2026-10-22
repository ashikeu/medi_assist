import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../models/medicine_model.dart';
import '../../models/meal_model.dart';
import '../../models/medical_record_model.dart';
import '../../models/activity_model.dart';
import '../../models/alarm_sound_model.dart';
import '../../models/prayer_location_model.dart';
import '../../models/prayer_reminder_model.dart';
import '../../models/prayer_settings_model.dart';
import '../constants/app_constants.dart';

/// StorageService uses TWO separate GetStorage boxes:
///
/// [_dataBox]     — stores user data (medicines, meals, records, activities)
///                  CLEARED when user taps "Clear All Data"
///
/// [_settingsBox] — stores app settings (first launch, service state, prefs)
///                  NEVER cleared — persists forever across data clears
class StorageService extends GetxService {
  static StorageService get to => Get.find();

  // ─── Two isolated storage boxes ──────────────────────────────────────────────
  late final GetStorage _dataBox;
  late final GetStorage _settingsBox;

  @override
  void onInit() {
    super.onInit();
    _dataBox     = GetStorage();                              // default box
    _settingsBox = GetStorage(AppConstants.settingsBoxName);  // settings box
  }

  // ════════════════════════════════════════════════════════════════
  // ─── MEDICINE ────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  List<Medicine> getMedicines() {
    try {
      final data = _dataBox.read<List>(AppConstants.medicinesKey);
      if (data == null) return [];
      return data
          .map((e) => Medicine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveMedicines(List<Medicine> medicines) async {
    await _dataBox.write(
      AppConstants.medicinesKey,
      medicines.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addMedicine(Medicine medicine) async {
    final list = getMedicines()..add(medicine);
    await saveMedicines(list);
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final list = getMedicines();
    final idx = list.indexWhere((e) => e.id == medicine.id);
    if (idx != -1) {
      list[idx] = medicine;
      await saveMedicines(list);
    }
  }

  Future<void> deleteMedicine(String id) async {
    final list = getMedicines()..removeWhere((e) => e.id == id);
    await saveMedicines(list);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── MEAL ────────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  List<Meal> getMeals() {
    try {
      final data = _dataBox.read<List>(AppConstants.mealsKey);
      if (data == null) return [];
      return data
          .map((e) => Meal.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveMeals(List<Meal> meals) async {
    await _dataBox.write(
      AppConstants.mealsKey,
      meals.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addMeal(Meal meal) async {
    final list = getMeals()..add(meal);
    await saveMeals(list);
  }

  Future<void> updateMeal(Meal meal) async {
    final list = getMeals();
    final idx = list.indexWhere((e) => e.id == meal.id);
    if (idx != -1) {
      list[idx] = meal;
      await saveMeals(list);
    }
  }

  Future<void> deleteMeal(String id) async {
    final list = getMeals()..removeWhere((e) => e.id == id);
    await saveMeals(list);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── MEDICAL RECORDS ─────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  List<MedicalRecord> getMedicalRecords() {
    try {
      final data = _dataBox.read<List>(AppConstants.medicalRecordsKey);
      if (data == null) return [];
      return data
          .map((e) => MedicalRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<MedicalRecord> getMedicalRecordsByType(String type) {
    return getMedicalRecords().where((e) => e.type == type).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> saveMedicalRecords(List<MedicalRecord> records) async {
    await _dataBox.write(
      AppConstants.medicalRecordsKey,
      records.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addMedicalRecord(MedicalRecord record) async {
    final list = getMedicalRecords()..add(record);
    await saveMedicalRecords(list);
  }

  Future<void> updateMedicalRecord(MedicalRecord record) async {
    final list = getMedicalRecords();
    final idx = list.indexWhere((e) => e.id == record.id);
    if (idx != -1) {
      list[idx] = record;
      await saveMedicalRecords(list);
    }
  }

  Future<void> deleteMedicalRecord(String id) async {
    final list = getMedicalRecords()..removeWhere((e) => e.id == id);
    await saveMedicalRecords(list);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── ACTIVITY ────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  /// Get all activities
  List<Activity> getActivities() {
    try {
      final data = _dataBox.read<List>(AppConstants.activitiesKey);
      if (data == null) return [];
      return data
          .map((e) => Activity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting activities: $e');
      return [];
    }
  }

  Future<void> saveActivities(List<Activity> activities) async {
    await _dataBox.write(
      AppConstants.activitiesKey,
      activities.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addActivity(Activity activity) async {
    final list = getActivities()..add(activity);
    await saveActivities(list);
  }

  Future<void> updateActivity(Activity activity) async {
    final list = getActivities();
    final idx = list.indexWhere((e) => e.id == activity.id);
    if (idx != -1) {
      list[idx] = activity;
      await saveActivities(list);
    }
  }

  Future<void> deleteActivity(String id) async {
    final list = getActivities()..removeWhere((e) => e.id == id);
    await saveActivities(list);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── PRAYER REMINDERS ────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  //
  // Reminders and custom prayer entries are user *data* and live in the data
  // box. The location and calculation settings they depend on are settings and
  // live in the settings box — see further down.

  List<PrayerReminder> getPrayerReminders() {
    try {
      final data = _dataBox.read<List>(AppConstants.prayerRemindersKey);
      if (data == null) return [];
      return data
          .map((e) =>
              PrayerReminder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting prayer reminders: $e');
      return [];
    }
  }

  List<PrayerReminder> getPrayerRemindersFor(String prayerId) =>
      getPrayerReminders().where((r) => r.prayerId == prayerId).toList()
        ..sort((a, b) => a.offsetMinutes.compareTo(b.offsetMinutes));

  Future<void> savePrayerReminders(List<PrayerReminder> reminders) async {
    await _dataBox.write(
      AppConstants.prayerRemindersKey,
      reminders.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addPrayerReminder(PrayerReminder reminder) async {
    final list = getPrayerReminders()..add(reminder);
    await savePrayerReminders(list);
  }

  Future<void> updatePrayerReminder(PrayerReminder reminder) async {
    final list = getPrayerReminders();
    final idx = list.indexWhere((e) => e.id == reminder.id);
    if (idx != -1) {
      list[idx] = reminder;
      await savePrayerReminders(list);
    }
  }

  Future<void> deletePrayerReminder(String id) async {
    final list = getPrayerReminders()..removeWhere((e) => e.id == id);
    await savePrayerReminders(list);
  }

  // ─── Custom prayer entries ────────────────────────────────────────────────

  List<CustomPrayerEvent> getCustomPrayers() {
    try {
      final data = _dataBox.read<List>(AppConstants.customPrayersKey);
      if (data == null) return [];
      return data
          .map((e) =>
              CustomPrayerEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting custom prayers: $e');
      return [];
    }
  }

  Future<void> saveCustomPrayers(List<CustomPrayerEvent> events) async {
    await _dataBox.write(
      AppConstants.customPrayersKey,
      events.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> addCustomPrayer(CustomPrayerEvent event) async {
    final list = getCustomPrayers()..add(event);
    await saveCustomPrayers(list);
  }

  Future<void> updateCustomPrayer(CustomPrayerEvent event) async {
    final list = getCustomPrayers();
    final idx = list.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      list[idx] = event;
      await saveCustomPrayers(list);
    }
  }

  /// Removes a custom entry along with every reminder attached to it —
  /// otherwise those reminders would keep firing for something the user can no
  /// longer see or edit.
  Future<void> deleteCustomPrayer(String id) async {
    final list = getCustomPrayers()..removeWhere((e) => e.id == id);
    await saveCustomPrayers(list);
    final reminders = getPrayerReminders()
      ..removeWhere((r) => r.prayerId == id);
    await savePrayerReminders(reminders);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── CLEAR USER DATA ONLY (settings are preserved) ────────────────
  // ════════════════════════════════════════════════════════════════

  /// Clears ONLY user data — medicines, meals, activities, medical records.
  /// Settings (service state, preferences, first-launch flag) are preserved.
  Future<void> clearAllData() async {
    await _dataBox.remove(AppConstants.medicinesKey);
    await _dataBox.remove(AppConstants.mealsKey);
    await _dataBox.remove(AppConstants.medicalRecordsKey);
    await _dataBox.remove(AppConstants.activitiesKey);
    await _dataBox.remove(AppConstants.prayerRemindersKey);
    await _dataBox.remove(AppConstants.customPrayersKey);
  }

  // ════════════════════════════════════════════════════════════════
  // ─── SETTINGS (use _settingsBox — never erased) ───────────────────
  // ════════════════════════════════════════════════════════════════

  // ── First launch ──────────────────────────────────────────────────────────
  bool get isFirstLaunch {
    return _settingsBox.read<bool>(AppConstants.firstLaunchKey) ?? true;
  }

  Future<void> setFirstLaunchDone() async {
    await _settingsBox.write(AppConstants.firstLaunchKey, false);
  }

  // ── Permission asked ──────────────────────────────────────────────────────
  /// Whether we've already asked for permissions in the splash screen.
  /// Prevents re-asking on every app open.
  bool get hasPermissionBeenAsked {
    return _settingsBox.read<bool>(AppConstants.permissionAskedKey) ?? false;
  }

  Future<void> setPermissionAsked() async {
    await _settingsBox.write(AppConstants.permissionAskedKey, true);
  }

  // ── Snooze minutes ────────────────────────────────────────────────────────
  int get snoozeMinutes {
    return _settingsBox.read<int>(AppConstants.snoozeMinutesKey) ??
        AppConstants.defaultSnoozeMinutes;
  }

  Future<void> setSnoozeMinutes(int minutes) async {
    await _settingsBox.write(AppConstants.snoozeMinutesKey, minutes);
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
  String get themeMode {
    return _settingsBox.read<String>(AppConstants.themeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _settingsBox.write(AppConstants.themeKey, mode);
  }

  // ── Language ──────────────────────────────────────────────────────────────
  /// Language tag of the chosen UI language, e.g. `en_US` or `bn_BD`.
  ///
  /// Lives in the settings box, so "Clear All Data" leaves the user's choice
  /// alone. `null` means the user has never picked one.
  String? get languageTag {
    return _settingsBox.read<String>(AppConstants.languageKey);
  }

  Future<void> setLanguageTag(String tag) async {
    await _settingsBox.write(AppConstants.languageKey, tag);
  }

  // ── Prayer location & calculation settings ────────────────────────────────
  /// The location prayer times are calculated for, or `null` if the user has
  /// never chosen one.
  ///
  /// Settings box, deliberately: "Clear All Data" removes the user's reminders
  /// but should not send the prayer screen back to a fallback city, the same
  /// reasoning that keeps the language choice out of the data box.
  PrayerLocation? get prayerLocation {
    try {
      final raw = _settingsBox.read(AppConstants.prayerLocationKey);
      if (raw is! Map) return null;
      return PrayerLocation.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('Error reading prayer location: $e');
      return null;
    }
  }

  Future<void> savePrayerLocation(PrayerLocation location) async {
    await _settingsBox.write(
        AppConstants.prayerLocationKey, location.toJson());
  }

  /// Calculation method, madhab, angles and manual adjustments. Defaults on a
  /// fresh install rather than being nullable — there is always *some* method
  /// in force.
  PrayerSettings get prayerSettings {
    try {
      final raw = _settingsBox.read(AppConstants.prayerSettingsKey);
      if (raw is! Map) return const PrayerSettings();
      return PrayerSettings.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('Error reading prayer settings: $e');
      return const PrayerSettings();
    }
  }

  Future<void> savePrayerSettings(PrayerSettings settings) async {
    await _settingsBox.write(
        AppConstants.prayerSettingsKey, settings.toJson());
  }

  /// Whether the prayer module is shown on the dashboard and its reminders are
  /// scheduled. On by default — a user who does not want it turns it off once.
  bool get isPrayerModuleEnabled =>
      _settingsBox.read<bool>(AppConstants.prayerEnabledKey) ?? true;

  Future<void> setPrayerModuleEnabled(bool enabled) async {
    await _settingsBox.write(AppConstants.prayerEnabledKey, enabled);
  }

  /// How many reminder slots the last scheduling run used. See
  /// [AppConstants.prayerSlotCountKey].
  int get prayerSlotCount =>
      _settingsBox.read<int>(AppConstants.prayerSlotCountKey) ?? 0;

  Future<void> setPrayerSlotCount(int count) async {
    await _settingsBox.write(AppConstants.prayerSlotCountKey, count);
  }

  // ── Alarm sound ───────────────────────────────────────────────────────────
  /// The sound every alarm uses unless the reminder names its own.
  ///
  /// Settings box: it is a preference about this device (and points at a file
  /// in this device's storage), so "Clear All Data" leaves it alone.
  AlarmSound get defaultAlarmSound {
    final stored =
        AlarmSound.tryFromJson(_settingsBox.read(AppConstants.alarmSoundKey));
    return stored ?? AlarmSound.appDefault;
  }

  Future<void> setDefaultAlarmSound(AlarmSound sound) async {
    await _settingsBox.write(AppConstants.alarmSoundKey, sound.toJson());
  }

  /// Sounds the user has imported, most recent first.
  List<AlarmSound> get alarmSoundLibrary {
    try {
      final data = _settingsBox.read<List>(AppConstants.alarmSoundLibraryKey);
      if (data == null) return [];
      return data
          .map(AlarmSound.tryFromJson)
          .whereType<AlarmSound>()
          .where((s) => s.isCustom)
          .toList();
    } catch (e) {
      debugPrint('Error reading alarm sound library: $e');
      return [];
    }
  }

  Future<void> saveAlarmSoundLibrary(List<AlarmSound> sounds) async {
    await _settingsBox.write(
      AppConstants.alarmSoundLibraryKey,
      sounds.map((s) => s.toJson()).toList(),
    );
  }

  // ── Pending notification route ────────────────────────────────────────────
  String? get pendingRoute {
    return _settingsBox.read<String>(AppConstants.pendingRouteKey);
  }

  Future<void> setPendingRoute(String route) async {
    await _settingsBox.write(AppConstants.pendingRouteKey, route);
  }

  Future<void> clearPendingRoute() async {
    await _settingsBox.remove(AppConstants.pendingRouteKey);
  }

  // ── Last reschedule date ──────────────────────────────────────────────────
  /// Tracks last time we rescheduled all reminders.
  /// Used to avoid unnecessary reschedules on every app open.
  DateTime? get lastRescheduleDate {
    final s = _settingsBox.read<String>(AppConstants.lastRescheduleDateKey);
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastRescheduleDate(DateTime date) async {
    await _settingsBox.write(
      AppConstants.lastRescheduleDateKey,
      date.toIso8601String(),
    );
  }

  // ─── Generic helpers ──────────────────────────────────────────────────────
  bool getBool(String key, {bool defaultValue = false}) =>
      _settingsBox.read<bool>(key) ?? defaultValue;

  Future<void> setBool(String key, bool value) async =>
      await _settingsBox.write(key, value);

  String getString(String key, {String defaultValue = ''}) =>
      _settingsBox.read<String>(key) ?? defaultValue;

  Future<void> setString(String key, String value) async =>
      await _settingsBox.write(key, value);

  int getInt(String key, {int defaultValue = 0}) =>
      _settingsBox.read<int>(key) ?? defaultValue;

  Future<void> setInt(String key, int value) async =>
      await _settingsBox.write(key, value);
}