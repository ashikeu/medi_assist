
import 'package:get/get.dart';

import '../../models/prayer_location_model.dart';
import '../../models/prayer_reminder_model.dart';
import '../../models/prayer_settings_model.dart';
import '../prayer/calculation_params.dart';
import '../prayer/prayer_times.dart';
import 'storage_service.dart';

/// One row of a day's prayer schedule: a calculated prayer, a sun event or a
/// user-defined entry, resolved to actual instants.
class PrayerScheduleEntry {
  const PrayerScheduleEntry({
    required this.id,
    required this.kind,
    required this.custom,
    required this.start,
    required this.end,
  });

  /// [PrayerKind.id] for a calculated entry, or the custom event's id.
  final String id;

  /// `null` for a custom event.
  final PrayerKind? kind;

  /// `null` for a calculated prayer.
  final CustomPrayerEvent? custom;

  /// When the prayer begins, as a UTC instant. `null` at polar latitudes where
  /// the sun never reaches the required altitude.
  final DateTime? start;

  /// When its window closes, where it has one.
  final DateTime? end;

  bool get isCustom => custom != null;

  /// The name to show. Calculated prayers go through `.tr` so they follow the
  /// app's language; a custom entry keeps whatever the user typed.
  String get displayName => custom?.name ?? kind!.nameKey.tr;

  bool get isObligatory => kind?.isObligatory ?? false;
}

/// Owns the prayer module's location, calculation settings and the arithmetic
/// that turns them into times.
///
/// It is the only place that knows how to move between the location's wall
/// clock and a UTC instant. Reminders are scheduled off the instants, so they
/// are correct regardless of which zone the phone is in; the screens render
/// the wall clock, so a user checking Makkah's times from London sees Makkah's
/// clock rather than their own.
class PrayerService extends GetxService {
  static PrayerService get to => Get.find();

  /// Bumped whenever the location or settings change, so anything showing
  /// times can rebuild without each screen having to subscribe separately.
  final RxInt revision = 0.obs;

  PrayerLocation? _location;
  PrayerSettings? _settings;

  @override
  void onInit() {
    super.onInit();
    _location = StorageService.to.prayerLocation;
    _settings = StorageService.to.prayerSettings;
  }

  // ─── Location & settings ──────────────────────────────────────────────────

  /// The configured location, or Dhaka until the user picks one.
  PrayerLocation get location => _location ??= PrayerLocation.fallback();

  /// Whether the user has actually chosen a location, as opposed to being
  /// shown the fallback. The UI nudges towards the location screen until they
  /// have.
  bool get hasConfiguredLocation => StorageService.to.prayerLocation != null;

  PrayerSettings get settings => _settings ??= const PrayerSettings();

  Future<void> setLocation(PrayerLocation newLocation) async {
    _location = newLocation;
    await StorageService.to.savePrayerLocation(newLocation);
    revision.value++;
  }

  Future<void> setSettings(PrayerSettings newSettings) async {
    _settings = newSettings;
    await StorageService.to.savePrayerSettings(newSettings);
    revision.value++;
  }

  /// Applies the calculation method the selected country's own authority
  /// publishes, dropping any angle overrides that belonged to the old method.
  Future<void> applyRegionalMethod() async {
    final method = location.regionalMethod;
    if (method == null) return;
    await setSettings(settings
        .copyWith(
          method: method,
          clearCustomFajrAngle: true,
          clearCustomIshaAngle: true,
          clearCustomIshaInterval: true,
        ));
  }

  CalculationParameters get parameters => settings.toParameters();

  // ─── Time zone ────────────────────────────────────────────────────────────

  int get deviceOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  /// Minutes east of UTC that this location's times are rendered in.
  int get offsetMinutes => location.resolvedOffsetMinutes(deviceOffsetMinutes);

  /// Whether the location is being shown in a different zone from the phone.
  bool get usesForeignTimeZone => offsetMinutes != deviceOffsetMinutes;

  /// The location's wall clock for a UTC [instant].
  ///
  /// The result is a plain, zone-less `DateTime` whose fields are the digits
  /// to print. Never do arithmetic against `DateTime.now()` with it — that is
  /// what the UTC instants are for.
  DateTime wallClock(DateTime instant) {
    final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day, shifted.hour,
        shifted.minute, shifted.second);
  }

  /// The UTC instant of a wall-clock time at the location.
  DateTime instantFromWallClock(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day, local.hour,
              local.minute, local.second)
          .subtract(Duration(minutes: offsetMinutes));

  /// Today's date at the location — which is not necessarily the phone's.
  DateTime get currentDate {
    final now = wallClock(DateTime.now());
    return DateTime(now.year, now.month, now.day);
  }

  // ─── Calculation ──────────────────────────────────────────────────────────

  /// The calculated prayer times for a date expressed in the location's own
  /// calendar.
  PrayerTimes timesForDate(DateTime date) => PrayerTimes.forDate(
        year: date.year,
        month: date.month,
        day: date.day,
        latitude: location.latitude,
        longitude: location.longitude,
        parameters: parameters,
      );

  /// A full day's schedule: the calculated prayers and sun events, plus every
  /// active custom entry, ordered by the time they occur.
  List<PrayerScheduleEntry> scheduleForDate(DateTime date) {
    final times = timesForDate(date);
    final entries = <PrayerScheduleEntry>[
      for (final kind in PrayerKind.schedule)
        PrayerScheduleEntry(
          id: kind.id,
          kind: kind,
          custom: null,
          start: times.timeFor(kind),
          end: times.endTimeFor(kind),
        ),
    ];

    for (final event in StorageService.to.getCustomPrayers()) {
      if (!event.isActive) continue;
      entries.add(PrayerScheduleEntry(
        id: event.id,
        kind: null,
        custom: event,
        start: customEventInstant(event, date, times),
        end: null,
      ));
    }

    entries.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return a.start!.compareTo(b.start!);
    });
    return entries;
  }

  /// Only the entries a reminder can be attached to — the calculated prayers
  /// and sun events plus the user's own, in the order the settings screen
  /// lists them.
  List<PrayerScheduleEntry> reminderTargetsForDate(DateTime date) {
    final times = timesForDate(date);
    return [
      for (final kind in PrayerKind.schedule)
        PrayerScheduleEntry(
          id: kind.id,
          kind: kind,
          custom: null,
          start: times.timeFor(kind),
          end: times.endTimeFor(kind),
        ),
      for (final event in StorageService.to.getCustomPrayers())
        PrayerScheduleEntry(
          id: event.id,
          kind: null,
          custom: event,
          start: customEventInstant(event, date, times),
          end: null,
        ),
    ];
  }

  /// When a custom entry falls on [date], as a UTC instant.
  ///
  /// An anchored entry rides its prayer through the year; a fixed one is a
  /// wall-clock time at the location, so it also has to be converted rather
  /// than taken as a device-local time.
  DateTime? customEventInstant(
    CustomPrayerEvent event,
    DateTime date,
    PrayerTimes times,
  ) {
    final fixed = event.fixedTime;
    if (!event.isAnchored && fixed != null) {
      return instantFromWallClock(
        DateTime(date.year, date.month, date.day, fixed.hour, fixed.minute),
      );
    }
    final anchor = PrayerKind.byId(event.anchorPrayerId);
    if (anchor == null) return null;
    final base = times.timeFor(anchor);
    if (base == null) return null;
    return base.add(Duration(minutes: event.offsetMinutes));
  }

  /// The instant a reminder's target falls on [date], or `null` if that target
  /// has no time that day.
  DateTime? targetInstant(String prayerId, DateTime date) {
    final times = timesForDate(date);
    final kind = PrayerKind.byId(prayerId);
    if (kind != null) return times.timeFor(kind);

    final event = StorageService.to
        .getCustomPrayers()
        .firstMatching((e) => e.id == prayerId);
    if (event == null || !event.isActive) return null;
    return customEventInstant(event, date, times);
  }

  /// The display name of a reminder's target, translated for the calculated
  /// prayers and verbatim for a custom one.
  String targetName(String prayerId) {
    final kind = PrayerKind.byId(prayerId);
    if (kind != null) return kind.nameKey.tr;
    final event = StorageService.to
        .getCustomPrayers()
        .firstMatching((e) => e.id == prayerId);
    return event?.name ?? prayerId;
  }

  // ─── Next / current prayer ────────────────────────────────────────────────

  /// The next of the five obligatory prayers (plus sunrise) still to come,
  /// rolling into tomorrow once Isha has begun.
  PrayerScheduleEntry? nextPrayer([DateTime? from]) {
    final now = (from ?? DateTime.now()).toUtc();
    final today = currentDate;

    for (final date in [today, today.add(const Duration(days: 1))]) {
      final times = timesForDate(date);
      for (final kind in PrayerTimes.timeline) {
        final start = times.timeFor(kind);
        if (start != null && start.isAfter(now)) {
          return PrayerScheduleEntry(
            id: kind.id,
            kind: kind,
            custom: null,
            start: start,
            end: times.endTimeFor(kind),
          );
        }
      }
    }
    return null;
  }

  /// The prayer currently in progress, or `null` before the day's Fajr.
  PrayerScheduleEntry? currentPrayer([DateTime? at]) {
    final now = (at ?? DateTime.now()).toUtc();
    final today = currentDate;

    for (final date in [today, today.subtract(const Duration(days: 1))]) {
      final times = timesForDate(date);
      final kind = times.currentPrayer(now);
      if (kind == null) continue;
      final start = times.timeFor(kind);
      final end = times.endTimeFor(kind);
      // Yesterday's Isha still counts until today's Fajr — which is exactly
      // the window a user checking the app at 2am is in.
      if (end != null && !end.isAfter(now)) continue;
      return PrayerScheduleEntry(
        id: kind.id,
        kind: kind,
        custom: null,
        start: start,
        end: end,
      );
    }
    return null;
  }

  /// How long until [instant], never negative.
  Duration timeUntil(DateTime instant) {
    final remaining = instant.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

extension _FirstMatching<T> on List<T> {
  T? firstMatching(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
