import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/location_catalog.dart';
import '../../../../core/prayer/calculation_params.dart';
import '../../../../core/services/device_location_service.dart';
import '../../../../core/services/prayer_service.dart';
import '../../../../core/services/reminder_scheduler.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/time_utils.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../models/alarm_sound_model.dart';
import '../../../../models/prayer_location_model.dart';
import '../../../../models/prayer_reminder_model.dart';
import '../../../../models/prayer_settings_model.dart';

/// Drives every prayer screen: the daily schedule, the calendar, the location
/// picker, the calculation settings and the reminders.
///
/// One controller rather than five because they all read the same two pieces
/// of state — the location and the calculation settings — and every one of
/// them has to repaint when either changes.
class PrayerController extends GetxController {
  static PrayerController get to => Get.find();

  PrayerService get _prayer => PrayerService.to;

  // ─── Schedule ─────────────────────────────────────────────────────────────

  /// The date being shown, in the *location's* calendar.
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  /// Today's schedule rows. A plain list rather than a computed getter so the
  /// astronomical maths runs once per change, not once per rebuild.
  final RxList<PrayerScheduleEntry> schedule = <PrayerScheduleEntry>[].obs;

  final RxString locationLabel = ''.obs;
  final RxString methodLabel = ''.obs;

  // ─── Next prayer ──────────────────────────────────────────────────────────
  final RxString nextPrayerId = ''.obs;
  final RxString nextPrayerName = ''.obs;
  final RxString nextPrayerTime = ''.obs;
  final RxString countdown = ''.obs;
  final RxString currentPrayerId = ''.obs;

  Timer? _ticker;

  // ─── Calendar ─────────────────────────────────────────────────────────────
  /// First day of the month the calendar is showing.
  final Rx<DateTime> calendarMonth = DateTime.now().obs;
  final RxBool calendarIsMonthly = true.obs;
  final RxList<PrayerDayRow> calendarRows = <PrayerDayRow>[].obs;

  // ─── Reminders ────────────────────────────────────────────────────────────
  final RxList<PrayerReminder> reminders = <PrayerReminder>[].obs;
  final RxList<CustomPrayerEvent> customEvents = <CustomPrayerEvent>[].obs;
  final RxBool isBusy = false.obs;
  final RxBool moduleEnabled = true.obs;

  // ─── Location picker state ────────────────────────────────────────────────
  final RxString pickerCountryCode = ''.obs;
  final RxString pickerDivision = ''.obs;
  final RxString pickerDistrict = ''.obs;
  final RxString pickerArea = ''.obs;
  final RxBool isLocating = false.obs;

  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  final offsetController = TextEditingController();

  // ─── Reminder form state ──────────────────────────────────────────────────
  PrayerReminder? editingReminder;
  final RxString formPrayerId = PrayerKind.fajr.id.obs;
  final RxInt formOffsetMinutes = 0.obs;
  /// Whether the reminder being edited fires at a fixed clock time rather than
  /// relative to its prayer.
  final RxBool formUsesExactTime = false.obs;
  final Rx<TimeOfDay> formExactTime =
      const TimeOfDay(hour: 5, minute: 0).obs;
  final Rx<AlarmSound?> formAlarmSound = Rx<AlarmSound?>(null);
  final RxString formNotifType = AppConstants.notifTypeNotification.obs;
  final RxBool formPlaySound = true.obs;
  final RxBool formVibrate = true.obs;
  final RxBool formLoopAudio = false.obs;
  final RxBool formActive = true.obs;
  final reminderTitleController = TextEditingController();
  final reminderMessageController = TextEditingController();

  // ─── Custom event form state ──────────────────────────────────────────────
  CustomPrayerEvent? editingCustomEvent;
  final customNameController = TextEditingController();
  final RxBool customIsAnchored = true.obs;
  final RxString customAnchorId = PrayerKind.maghrib.id.obs;
  final RxInt customOffsetMinutes = 30.obs;
  final Rx<TimeOfDay> customFixedTime = const TimeOfDay(hour: 21, minute: 0).obs;

  @override
  void onInit() {
    super.onInit();
    selectedDate.value = _prayer.currentDate;
    calendarMonth.value =
        DateTime(_prayer.currentDate.year, _prayer.currentDate.month, 1);
    moduleEnabled.value = StorageService.to.isPrayerModuleEnabled;
    _syncPickerFromLocation();
    refreshAll();

    // A one-second tick is what a countdown needs, and it is the only thing
    // in the app that polls. It is cancelled in onClose, so it stops with the
    // screen rather than running for the life of the process.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Any change to the location or the calculation settings invalidates every
    // time on screen.
    ever<int>(_prayer.revision, (_) => refreshAll());
  }

  @override
  void onClose() {
    _ticker?.cancel();
    latitudeController.dispose();
    longitudeController.dispose();
    offsetController.dispose();
    reminderTitleController.dispose();
    reminderMessageController.dispose();
    customNameController.dispose();
    super.onClose();
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  void refreshAll() {
    loadSchedule();
    loadReminders();
    loadCalendar();
    locationLabel.value = _prayer.location.displayName;
    methodLabel.value = _prayer.settings.method.nameKey.tr;
    // The location or the settings may have moved every prayer, so the cached
    // next-prayer instant is no longer trustworthy — and the back-off must not
    // hold a stale "no next prayer" over a change that creates one.
    _nextPrayerStart = null;
    _lastProbe = null;
    _tick();
  }

  void loadSchedule() {
    schedule.assignAll(_prayer.scheduleForDate(selectedDate.value));
  }

  void loadReminders() {
    reminders.assignAll(StorageService.to.getPrayerReminders());
    customEvents.assignAll(StorageService.to.getCustomPrayers());
  }

  /// Reminders attached to one prayer, earliest offset first.
  List<PrayerReminder> remindersFor(String prayerId) =>
      reminders.where((r) => r.prayerId == prayerId).toList()
        ..sort((a, b) => a.offsetMinutes.compareTo(b.offsetMinutes));

  int activeReminderCountFor(String prayerId) =>
      reminders.where((r) => r.prayerId == prayerId && r.isActive).length;

  // ─── Countdown ────────────────────────────────────────────────────────────

  /// The instant the countdown is counting down to, kept so the per-second
  /// tick can format a string instead of recomputing the day's solar position.
  DateTime? _nextPrayerStart;

  /// When the next prayer was last derived. Only consulted when there is no
  /// next prayer at all, to keep the retry off the per-second path.
  DateTime? _lastProbe;

  void _tick() {
    final now = DateTime.now().toUtc();
    // Only re-derive which prayer is next when the one we had has arrived.
    // Recomputing every second would run the astronomical maths sixty times a
    // minute to produce the same answer — and at a polar latitude, where
    // there is no next prayer to cache, it would do so forever, hence the
    // minute-long back-off.
    final expired = _nextPrayerStart != null && !_nextPrayerStart!.isAfter(now);
    final shouldProbe = _nextPrayerStart == null &&
        (_lastProbe == null ||
            now.difference(_lastProbe!) >= const Duration(minutes: 1));

    if (expired || shouldProbe) {
      _lastProbe = now;
      _recomputeNextPrayer();
    }

    final start = _nextPrayerStart;
    countdown.value =
        start == null ? '' : _formatCountdown(_prayer.timeUntil(start));
  }

  void _recomputeNextPrayer() {
    final next = _prayer.nextPrayer();
    if (next == null || next.start == null) {
      _nextPrayerStart = null;
      nextPrayerId.value = '';
      nextPrayerName.value = '';
      nextPrayerTime.value = '';
    } else {
      _nextPrayerStart = next.start;
      nextPrayerId.value = next.id;
      nextPrayerName.value = next.displayName;
      nextPrayerTime.value = formatInstant(next.start);
    }
    // The current prayer only changes when the next one arrives, which is
    // exactly when this runs.
    currentPrayerId.value = _prayer.currentPrayer()?.id ?? '';
  }

  /// "02:14:09" — deliberately not localised into words, because a countdown
  /// is read at a glance rather than sentence by sentence.
  static String _formatCountdown(Duration remaining) {
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // ─── Date navigation ──────────────────────────────────────────────────────

  void selectDate(DateTime date) {
    selectedDate.value = DateTime(date.year, date.month, date.day);
    loadSchedule();
  }

  void showToday() => selectDate(_prayer.currentDate);

  void showTomorrow() =>
      selectDate(_prayer.currentDate.add(const Duration(days: 1)));

  void shiftDay(int days) =>
      selectDate(selectedDate.value.add(Duration(days: days)));

  bool get isShowingToday => _isSameDay(selectedDate.value, _prayer.currentDate);

  bool get isShowingTomorrow => _isSameDay(
      selectedDate.value, _prayer.currentDate.add(const Duration(days: 1)));

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Calendar ─────────────────────────────────────────────────────────────

  void setCalendarMonthly(bool monthly) {
    calendarIsMonthly.value = monthly;
    loadCalendar();
  }

  void shiftCalendar(int step) {
    if (calendarIsMonthly.value) {
      final month = calendarMonth.value;
      calendarMonth.value = DateTime(month.year, month.month + step, 1);
    } else {
      calendarMonth.value = calendarMonth.value.add(Duration(days: 7 * step));
    }
    loadCalendar();
  }

  void loadCalendar() {
    final rows = <PrayerDayRow>[];
    if (calendarIsMonthly.value) {
      final month = calendarMonth.value;
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        rows.add(_dayRow(DateTime(month.year, month.month, day)));
      }
    } else {
      // The week the anchor falls in, starting on its own weekday rather than
      // on an arbitrary Sunday — the user navigated here from a date.
      final start = calendarMonth.value;
      for (var day = 0; day < 7; day++) {
        rows.add(_dayRow(start.add(Duration(days: day))));
      }
    }
    calendarRows.assignAll(rows);
  }

  PrayerDayRow _dayRow(DateTime date) {
    final times = _prayer.timesForDate(date);
    return PrayerDayRow(
      date: date,
      isToday: _isSameDay(date, _prayer.currentDate),
      times: {
        for (final kind in PrayerKind.obligatory)
          kind.id: formatInstant(times.timeFor(kind)),
      },
      sunrise: formatInstant(times.sunrise),
    );
  }

  /// The month or week the calendar header names.
  String get calendarTitle {
    if (calendarIsMonthly.value) {
      final month = calendarMonth.value;
      return '${'month_short_${month.month}'.tr} ${month.year}';
    }
    final start = calendarMonth.value;
    final end = start.add(const Duration(days: 6));
    return '${TimeUtils.formatDate(start)} — ${TimeUtils.formatDate(end)}';
  }

  // ─── Formatting ───────────────────────────────────────────────────────────

  /// A UTC instant as the location's wall clock, in the app's language.
  String formatInstant(DateTime? instant) {
    if (instant == null) return '—';
    return TimeUtils.formatDateTime(_prayer.wallClock(instant));
  }

  String formatDateLabel(DateTime date) => TimeUtils.formatDate(date);

  /// Whether the times on screen are in a different zone from the phone.
  bool get usesForeignTimeZone => _prayer.usesForeignTimeZone;

  String get timeZoneLabel {
    final minutes = _prayer.offsetMinutes;
    final sign = minutes < 0 ? '-' : '+';
    final hours = (minutes.abs() ~/ 60).toString().padLeft(2, '0');
    final rest = (minutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$rest';
  }

  // ─── Module toggle ────────────────────────────────────────────────────────

  Future<void> setModuleEnabled(bool enabled) async {
    moduleEnabled.value = enabled;
    await StorageService.to.setPrayerModuleEnabled(enabled);
    if (enabled) {
      await ReminderScheduler.schedulePrayerReminders();
    } else {
      await ReminderScheduler.cancelAllPrayerReminders();
    }
    // The dashboard reads this flag to decide whether to show the card, and it
    // is not rebuilt by navigating back to it.
    if (Get.isRegistered<HomeController>()) {
      HomeController.to.refreshCounts();
    }
  }

  // ─── Location ─────────────────────────────────────────────────────────────

  PrayerLocation get location => _prayer.location;

  void _syncPickerFromLocation() {
    final current = _prayer.location;
    pickerCountryCode.value = current.countryCode ?? '';
    pickerDivision.value = current.division ?? '';
    pickerDistrict.value = current.district ?? '';
    pickerArea.value = current.area ?? '';
    latitudeController.text = current.latitude.toStringAsFixed(6);
    longitudeController.text = current.longitude.toStringAsFixed(6);
    offsetController.text = current.utcOffsetMinutes?.toString() ?? '';
  }

  List<CatalogCountry> get countries => LocationCatalog.countries;

  CatalogCountry? get selectedCountry =>
      LocationCatalog.countryByCode(pickerCountryCode.value);

  List<CatalogDivision> get divisions => selectedCountry?.divisions ?? const [];

  CatalogDivision? get selectedDivision =>
      LocationCatalog.divisionByName(selectedCountry, pickerDivision.value);

  List<CatalogDistrict> get districts =>
      selectedDivision?.districts ?? const [];

  CatalogDistrict? get selectedDistrict =>
      LocationCatalog.districtByName(selectedDivision, pickerDistrict.value);

  List<CatalogArea> get areas => selectedDistrict?.areas ?? const [];

  void setPickerCountry(String code) {
    pickerCountryCode.value = code;
    pickerDivision.value = '';
    pickerDistrict.value = '';
    pickerArea.value = '';
  }

  void setPickerDivision(String name) {
    pickerDivision.value = name;
    pickerDistrict.value = '';
    pickerArea.value = '';
  }

  void setPickerDistrict(String name) {
    pickerDistrict.value = name;
    pickerArea.value = '';
  }

  void setPickerArea(String name) => pickerArea.value = name;

  /// Saves the country/division/district/area currently selected.
  Future<void> applyCatalogSelection() async {
    final country = selectedCountry;
    final division = selectedDivision;
    final district = selectedDistrict;
    if (country == null || division == null || district == null) {
      AppUtils.showError('prayer_location_incomplete'.tr);
      return;
    }
    final area = LocationCatalog.areaByName(district, pickerArea.value);

    await _applyLocation(
      PrayerLocation.fromCatalog(
        CatalogPlace(
          country: country,
          division: division,
          district: district,
          area: area,
          latitude: area?.latitude ?? district.latitude,
          longitude: area?.longitude ?? district.longitude,
        ),
        deviceOffsetMinutes: _prayer.deviceOffsetMinutes,
      ),
      offerRegionalMethod: true,
    );
  }

  /// Saves whatever is in the latitude/longitude/offset fields.
  Future<void> applyManualCoordinates() async {
    final latitude = double.tryParse(latitudeController.text.trim());
    final longitude = double.tryParse(longitudeController.text.trim());

    if (latitude == null || latitude < -90 || latitude > 90) {
      AppUtils.showError('prayer_latitude_invalid'.tr);
      return;
    }
    if (longitude == null || longitude < -180 || longitude > 180) {
      AppUtils.showError('prayer_longitude_invalid'.tr);
      return;
    }

    final rawOffset = offsetController.text.trim();
    int? offsetMinutes;
    if (rawOffset.isNotEmpty) {
      offsetMinutes = int.tryParse(rawOffset);
      if (offsetMinutes == null || offsetMinutes < -720 || offsetMinutes > 840) {
        AppUtils.showError('prayer_offset_invalid'.tr);
        return;
      }
    }

    // Hand-entered coordinates keep whatever place name the nearest catalogue
    // entry suggests, so the screen still says somewhere recognisable — but
    // the coordinate itself is used exactly as typed.
    final nearest = LocationCatalog.nearest(latitude, longitude);

    await _applyLocation(
      PrayerLocation(
        latitude: latitude,
        longitude: longitude,
        countryCode: nearest?.country.code,
        countryName: nearest?.country.name,
        division: nearest?.division.name,
        district: nearest?.district.name,
        area: nearest?.area?.name,
        utcOffsetMinutes: offsetMinutes,
        source: PrayerLocationSource.manual,
      ),
      offerRegionalMethod: false,
    );
  }

  /// Takes a GPS fix and names it from the nearest catalogue entry.
  Future<void> useCurrentLocation() async {
    if (isLocating.value) return;
    isLocating.value = true;
    try {
      final result = await DeviceLocationService.to.currentPosition();
      if (!result.isSuccess) {
        _reportLocationFailure(result.failure!);
        return;
      }

      final latitude = result.latitude!;
      final longitude = result.longitude!;
      final nearest = LocationCatalog.nearest(latitude, longitude);

      await _applyLocation(
        PrayerLocation(
          latitude: latitude,
          longitude: longitude,
          countryCode: nearest?.country.code,
          countryName: nearest?.country.name,
          division: nearest?.division.name,
          district: nearest?.district.name,
          area: nearest?.area?.name,
          // A GPS fix is where the phone is, so the phone's own clock is the
          // right one — including through daylight saving.
          utcOffsetMinutes: null,
          source: PrayerLocationSource.gps,
        ),
        offerRegionalMethod: true,
      );

      AppUtils.showSuccess(
        nearest == null
            ? 'prayer_location_gps_unnamed'.tr
            : 'prayer_location_detected'
                .trParams({'place': _prayer.location.displayName}),
      );
    } finally {
      isLocating.value = false;
    }
  }

  void _reportLocationFailure(LocationFailure failure) {
    switch (failure) {
      case LocationFailure.permissionDenied:
        AppUtils.showWarning('prayer_location_permission_denied'.tr);
      case LocationFailure.permissionPermanentlyDenied:
        AppUtils.showWarning('prayer_location_permission_blocked'.tr);
      case LocationFailure.servicesDisabled:
        AppUtils.showWarning('prayer_location_services_off'.tr);
      case LocationFailure.timeout:
        AppUtils.showError('prayer_location_timeout'.tr);
      case LocationFailure.unavailable:
        AppUtils.showError('prayer_location_failed'.tr);
    }
  }

  Future<void> _applyLocation(
    PrayerLocation newLocation, {
    required bool offerRegionalMethod,
  }) async {
    await _prayer.setLocation(newLocation);

    // A location in a country with its own published method adopts it, unless
    // the user has already hand-tuned the angles — in which case silently
    // overwriting their work would be worse than leaving the method alone.
    if (offerRegionalMethod && !_prayer.settings.hasCustomAngles) {
      await _prayer.applyRegionalMethod();
    }

    _syncPickerFromLocation();
    // Every scheduled prayer reminder was computed for the old coordinate.
    await ReminderScheduler.schedulePrayerReminders();
    refreshAll();
  }

  // ─── Calculation settings ─────────────────────────────────────────────────

  PrayerSettings get settings => _prayer.settings;

  Future<void> setMethod(CalculationMethod method) async {
    await _prayer.setSettings(settings.copyWith(
      method: method,
      // The overrides belonged to the previous method's angles; carrying them
      // across would make the new method's name a lie.
      clearCustomFajrAngle: true,
      clearCustomIshaAngle: true,
      clearCustomIshaInterval: true,
    ));
    await _afterSettingsChange();
  }

  Future<void> setMadhab(Madhab madhab) async {
    await _prayer.setSettings(settings.copyWith(madhab: madhab));
    await _afterSettingsChange();
  }

  Future<void> setHighLatitudeRule(HighLatitudeRule? rule) async {
    await _prayer.setSettings(rule == null
        ? settings.copyWith(clearHighLatitudeRule: true)
        : settings.copyWith(highLatitudeRule: rule));
    await _afterSettingsChange();
  }

  Future<void> setFajrAngle(double? angle) async {
    await _prayer.setSettings(angle == null
        ? settings.copyWith(clearCustomFajrAngle: true)
        : settings.copyWith(customFajrAngle: angle));
    await _afterSettingsChange();
  }

  Future<void> setIshaAngle(double? angle) async {
    await _prayer.setSettings(angle == null
        ? settings.copyWith(clearCustomIshaAngle: true)
        : settings.copyWith(customIshaAngle: angle));
    await _afterSettingsChange();
  }

  Future<void> setIshaInterval(int? minutes) async {
    await _prayer.setSettings(minutes == null
        ? settings.copyWith(clearCustomIshaInterval: true)
        : settings.copyWith(customIshaInterval: minutes));
    await _afterSettingsChange();
  }

  Future<void> setAdjustment(PrayerKind kind, int minutes) async {
    await _prayer.setSettings(settings.copyWith(
      adjustments: settings.adjustments.withPrayer(kind, minutes),
    ));
    await _afterSettingsChange();
  }

  Future<void> resetSettings() async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'prayer_settings_reset'.tr,
      message: 'prayer_settings_reset_message'.tr,
      confirmText: 'prayer_settings_reset_confirm'.tr,
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed) return;
    await _prayer.setSettings(settings.resetToMethodDefaults());
    await _afterSettingsChange();
  }

  /// Every scheduled reminder was computed from the old settings, so they all
  /// have to be re-derived — the same reason a language change reschedules.
  Future<void> _afterSettingsChange() async {
    await ReminderScheduler.schedulePrayerReminders();
    refreshAll();
  }

  // ─── Reminder CRUD ────────────────────────────────────────────────────────

  void prepareReminderForAdd(String prayerId) {
    editingReminder = null;
    formPrayerId.value = prayerId;
    formOffsetMinutes.value = 0;
    formUsesExactTime.value = false;
    // Seed the time picker with when that prayer actually falls today, so
    // switching to exact mode starts somewhere sensible rather than at 5am.
    final start = _prayer.targetInstant(prayerId, selectedDate.value);
    formExactTime.value = start == null
        ? const TimeOfDay(hour: 5, minute: 0)
        : TimeOfDay.fromDateTime(_prayer.wallClock(start));
    formAlarmSound.value = null;
    formNotifType.value = AppConstants.notifTypeNotification;
    formPlaySound.value = true;
    formVibrate.value = true;
    formLoopAudio.value = false;
    formActive.value = true;
    reminderTitleController.clear();
    reminderMessageController.clear();
  }

  void prepareReminderForEdit(PrayerReminder reminder) {
    editingReminder = reminder;
    formPrayerId.value = reminder.prayerId;
    formOffsetMinutes.value = reminder.offsetMinutes;
    formUsesExactTime.value = reminder.usesExactTime;
    formExactTime.value =
        reminder.exactTime ?? const TimeOfDay(hour: 5, minute: 0);
    formAlarmSound.value = reminder.alarmSound;
    formNotifType.value = reminder.notificationType;
    formPlaySound.value = reminder.playSound;
    formVibrate.value = reminder.vibrate;
    formLoopAudio.value = reminder.loopAudio;
    formActive.value = reminder.isActive;
    reminderTitleController.text = reminder.title ?? '';
    reminderMessageController.text = reminder.message ?? '';
  }

  Future<void> saveReminder() async {
    final prayerId = formPrayerId.value;
    final existingForPrayer = remindersFor(prayerId);
    final isNew = editingReminder == null;

    if (isNew && existingForPrayer.length >= AppConstants.maxRemindersPerPrayer) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'prayer_reminder_limit'.trParams(
            {'count': '${AppConstants.maxRemindersPerPrayer}'}),
      );
      return;
    }

    // Two reminders at the same offset — or at the same clock time — would
    // fire twice at the same instant for the same prayer, which reads as a bug
    // rather than a choice.
    final usesExact = formUsesExactTime.value;
    final duplicate = existingForPrayer.any((r) {
      if (r.id == editingReminder?.id) return false;
      if (r.usesExactTime != usesExact) return false;
      return usesExact
          ? r.exactTime == formExactTime.value
          : r.offsetMinutes == formOffsetMinutes.value;
    });
    if (duplicate) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'prayer_reminder_duplicate'.tr,
      );
      return;
    }

    isBusy.value = true;
    try {
      final title = reminderTitleController.text.trim();
      final message = reminderMessageController.text.trim();

      final reminder = (editingReminder ??
              PrayerReminder(id: IdGenerator.generate(), prayerId: prayerId))
          .copyWith(
        prayerId: prayerId,
        offsetMinutes: usesExact ? 0 : formOffsetMinutes.value,
        exactTime: usesExact ? formExactTime.value : null,
        clearExactTime: !usesExact,
        notificationType: formNotifType.value,
        isActive: formActive.value,
        playSound: formPlaySound.value,
        vibrate: formVibrate.value,
        loopAudio: formLoopAudio.value,
        alarmSound: formAlarmSound.value,
        clearAlarmSound: formAlarmSound.value == null,
        title: title.isEmpty ? null : title,
        clearTitle: title.isEmpty,
        message: message.isEmpty ? null : message,
        clearMessage: message.isEmpty,
      );

      if (isNew) {
        await StorageService.to.addPrayerReminder(reminder);
      } else {
        await StorageService.to.updatePrayerReminder(reminder);
      }

      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();

      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: isNew ? 'prayer_reminder_added'.tr : 'prayer_reminder_updated'.tr,
        message: 'prayer_reminder_saved_detail'
            .trParams({'prayer': _prayer.targetName(prayerId)}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'prayer_reminder_save_failed'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> toggleReminder(PrayerReminder reminder) async {
    try {
      final updated = reminder.copyWith(isActive: !reminder.isActive);
      await StorageService.to.updatePrayerReminder(updated);
      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();
    } catch (e) {
      AppUtils.showError('prayer_reminder_save_failed'.tr);
    }
  }

  Future<void> deleteReminder(PrayerReminder reminder) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'prayer_reminder_delete_title'.tr,
      message: 'prayer_reminder_delete_message'
          .trParams({'prayer': _prayer.targetName(reminder.prayerId)}),
      confirmText: 'delete'.tr,
    );
    if (!confirmed) return;

    try {
      await StorageService.to.deletePrayerReminder(reminder.id);
      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();
      AppUtils.showSuccess('prayer_reminder_deleted'.tr, title: 'deleted'.tr);
    } catch (e) {
      AppUtils.showError('prayer_reminder_save_failed'.tr);
    }
  }

  /// Adds the before / at / after set the spec describes in one go, for a
  /// prayer that has no reminders yet.
  Future<void> addDefaultReminderSet(String prayerId) async {
    if (remindersFor(prayerId).isNotEmpty) return;
    isBusy.value = true;
    try {
      for (final offset in const [-15, 0, 10]) {
        await StorageService.to.addPrayerReminder(PrayerReminder(
          // IdGenerator derives its id from the millisecond clock, so three
          // calls inside one loop can collide. The offset is unique within the
          // set by construction, which is enough to separate them.
          id: '${IdGenerator.generate()}_$offset',
          prayerId: prayerId,
          offsetMinutes: offset,
          notificationType: offset == 0
              ? AppConstants.notifTypeBoth
              : AppConstants.notifTypeNotification,
          loopAudio: offset == 0,
        ));
      }
      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();
      AppUtils.showSuccess('prayer_reminder_set_added'
          .trParams({'prayer': _prayer.targetName(prayerId)}));
    } finally {
      isBusy.value = false;
    }
  }

  // ─── Custom prayer entries ────────────────────────────────────────────────

  void prepareCustomForAdd() {
    editingCustomEvent = null;
    customNameController.clear();
    customIsAnchored.value = true;
    customAnchorId.value = PrayerKind.maghrib.id;
    customOffsetMinutes.value = 30;
    customFixedTime.value = const TimeOfDay(hour: 21, minute: 0);
  }

  void prepareCustomForEdit(CustomPrayerEvent event) {
    editingCustomEvent = event;
    customNameController.text = event.name;
    customIsAnchored.value = event.isAnchored;
    customAnchorId.value = event.anchorPrayerId ?? PrayerKind.maghrib.id;
    customOffsetMinutes.value = event.offsetMinutes;
    customFixedTime.value =
        event.fixedTime ?? const TimeOfDay(hour: 21, minute: 0);
  }

  Future<void> saveCustomEvent() async {
    final name = customNameController.text.trim();
    if (name.length < 2) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'prayer_custom_name_required'.tr,
      );
      return;
    }

    isBusy.value = true;
    try {
      final anchored = customIsAnchored.value;
      final event = CustomPrayerEvent(
        id: editingCustomEvent?.id ?? IdGenerator.generate(),
        name: name,
        anchorPrayerId: anchored ? customAnchorId.value : null,
        offsetMinutes: anchored ? customOffsetMinutes.value : 0,
        fixedTime: anchored ? null : customFixedTime.value,
        isActive: editingCustomEvent?.isActive ?? true,
        createdAt: editingCustomEvent?.createdAt,
      );

      if (editingCustomEvent == null) {
        await StorageService.to.addCustomPrayer(event);
      } else {
        await StorageService.to.updateCustomPrayer(event);
      }

      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();
      refreshAll();

      Get.back();
      AppUtils.showResultDialog(
        success: true,
        title: 'prayer_custom_saved'.tr,
        message: 'prayer_custom_saved_detail'.trParams({'name': name}),
      );
    } catch (e) {
      AppUtils.showResultDialog(
        success: false,
        title: 'save_failed'.tr,
        message: 'prayer_custom_save_failed'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> deleteCustomEvent(CustomPrayerEvent event) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'prayer_custom_delete_title'.tr,
      message: 'delete_confirm_message'.trParams({'name': event.name}),
      confirmText: 'delete'.tr,
    );
    if (!confirmed) return;

    try {
      // Storage removes the reminders that pointed at it too — they would
      // otherwise keep firing for something with no screen left to edit.
      await StorageService.to.deleteCustomPrayer(event.id);
      loadReminders();
      await ReminderScheduler.schedulePrayerReminders();
      refreshAll();
      AppUtils.showSuccess(
        'item_deleted'.trParams({'name': event.name}),
        title: 'deleted'.tr,
      );
    } catch (e) {
      AppUtils.showError('prayer_custom_save_failed'.tr);
    }
  }

  Future<void> toggleCustomEvent(CustomPrayerEvent event) async {
    await StorageService.to
        .updateCustomPrayer(event.copyWith(isActive: !event.isActive));
    loadReminders();
    await ReminderScheduler.schedulePrayerReminders();
    refreshAll();
  }

  /// Every target a reminder can be attached to, for the picker.
  List<PrayerScheduleEntry> get reminderTargets =>
      _prayer.reminderTargetsForDate(selectedDate.value);

  String targetName(String prayerId) => _prayer.targetName(prayerId);
}

/// One row of the weekly or monthly calendar.
class PrayerDayRow {
  const PrayerDayRow({
    required this.date,
    required this.isToday,
    required this.times,
    required this.sunrise,
  });

  final DateTime date;
  final bool isToday;

  /// Formatted start times, keyed by [PrayerKind.id].
  final Map<String, String> times;
  final String sunrise;
}
