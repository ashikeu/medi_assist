import 'astronomical.dart';
import 'calculation_params.dart';

/// The prayer times for one calendar day at one coordinate.
///
/// Every field is a **UTC instant**. The calendar day is the one that runs at
/// the location, which is why [PrayerTimes.forDate] takes the date already
/// expressed in the location's own offset — see `PrayerService`, which is the
/// only thing in the app that owns that conversion.
///
/// A field is `null` when the sun never reaches the required altitude on that
/// day and no high-latitude rule can rescue it (true polar day/night). The UI
/// shows a dash rather than inventing a time.
class PrayerTimes {
  const PrayerTimes._({
    required this.year,
    required this.month,
    required this.day,
    required this.latitude,
    required this.longitude,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.sunset,
    required this.isha,
    required this.midnight,
    required this.tahajjud,
    required this.nextFajr,
  });

  final int year;
  final int month;
  final int day;
  final double latitude;
  final double longitude;

  final DateTime? fajr;
  final DateTime? sunrise;
  final DateTime? dhuhr;
  final DateTime? asr;

  /// Maghrib proper. Equal to [sunset] unless the method uses a depression
  /// angle for it (Tehran).
  final DateTime? maghrib;
  final DateTime? sunset;
  final DateTime? isha;

  /// Midpoint of the night, Maghrib to the following Fajr — the end of Isha
  /// under the stricter opinion.
  final DateTime? midnight;

  /// Start of the last third of the night.
  final DateTime? tahajjud;

  /// Tomorrow's Fajr, which is what Isha, midnight and Tahajjud are measured
  /// against. Exposed because the schedule screen shows Isha's end time.
  final DateTime? nextFajr;

  /// Computes the times for the civil date [year]-[month]-[day] at the given
  /// coordinate.
  factory PrayerTimes.forDate({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
    required CalculationParameters parameters,
  }) {
    final today = _DayCore.compute(
      year: year,
      month: month,
      day: day,
      latitude: latitude,
      longitude: longitude,
      parameters: parameters,
    );

    final tomorrowDate = DateTime.utc(year, month, day).add(_oneDay);
    final tomorrow = _DayCore.compute(
      year: tomorrowDate.year,
      month: tomorrowDate.month,
      day: tomorrowDate.day,
      latitude: latitude,
      longitude: longitude,
      parameters: parameters,
    );

    final maghrib = today.maghrib;
    final nextFajr = tomorrow.fajr;

    DateTime? midnight;
    DateTime? tahajjud;
    if (maghrib != null && nextFajr != null) {
      final nightSeconds = nextFajr.difference(maghrib).inSeconds;
      midnight = _roundToMinute(
          maghrib.add(Duration(seconds: (nightSeconds / 2).round())));
      tahajjud = _roundToMinute(
          maghrib.add(Duration(seconds: (nightSeconds * 2 / 3).round())));
    }

    return PrayerTimes._(
      year: year,
      month: month,
      day: day,
      latitude: latitude,
      longitude: longitude,
      fajr: today.fajr,
      sunrise: today.sunrise,
      dhuhr: today.dhuhr,
      asr: today.asr,
      maghrib: maghrib,
      sunset: today.sunset,
      isha: today.isha,
      midnight: midnight,
      tahajjud: tahajjud,
      nextFajr: nextFajr,
    );
  }

  /// The instant [kind] begins, or `null` if it cannot be determined.
  DateTime? timeFor(PrayerKind kind) {
    switch (kind) {
      case PrayerKind.fajr:
        return fajr;
      case PrayerKind.sunrise:
        return sunrise;
      case PrayerKind.dhuhr:
        return dhuhr;
      case PrayerKind.asr:
        return asr;
      case PrayerKind.maghrib:
        return maghrib;
      case PrayerKind.sunset:
        return sunset;
      case PrayerKind.isha:
        return isha;
      case PrayerKind.midnight:
        return midnight;
      case PrayerKind.tahajjud:
        return tahajjud;
    }
  }

  /// When [kind]'s window closes, for the prayers that have one.
  ///
  /// Sunrise, sunset and midnight are instants rather than windows, so they
  /// have no end time and the schedule shows a single column for them.
  DateTime? endTimeFor(PrayerKind kind) {
    switch (kind) {
      case PrayerKind.fajr:
        return sunrise;
      case PrayerKind.dhuhr:
        return asr;
      case PrayerKind.asr:
        return maghrib;
      case PrayerKind.maghrib:
        return isha;
      case PrayerKind.isha:
      case PrayerKind.tahajjud:
        return nextFajr;
      case PrayerKind.sunrise:
      case PrayerKind.sunset:
      case PrayerKind.midnight:
        return null;
    }
  }

  /// The prayers that mark the passage of the day, in the order they occur.
  static const List<PrayerKind> timeline = [
    PrayerKind.fajr,
    PrayerKind.sunrise,
    PrayerKind.dhuhr,
    PrayerKind.asr,
    PrayerKind.maghrib,
    PrayerKind.isha,
  ];

  /// The last entry of [timeline] that has already started at [instant], or
  /// `null` before Fajr.
  PrayerKind? currentPrayer(DateTime instant) {
    final utc = instant.toUtc();
    PrayerKind? current;
    for (final kind in timeline) {
      final time = timeFor(kind);
      if (time != null && !time.isAfter(utc)) current = kind;
    }
    return current;
  }

  /// The first entry of [timeline] still to come at [instant], or `null` once
  /// Isha has begun — the caller then moves to the next day.
  PrayerKind? nextPrayer(DateTime instant) {
    final utc = instant.toUtc();
    for (final kind in timeline) {
      final time = timeFor(kind);
      if (time != null && time.isAfter(utc)) return kind;
    }
    return null;
  }
}

const Duration _oneDay = Duration(days: 1);

/// One day's raw prayer times, before the night markers that need the next
/// day's Fajr.
class _DayCore {
  const _DayCore({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.sunset,
    required this.isha,
  });

  final DateTime? fajr;
  final DateTime? sunrise;
  final DateTime? dhuhr;
  final DateTime? asr;
  final DateTime? maghrib;
  final DateTime? sunset;
  final DateTime? isha;

  static _DayCore compute({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
    required CalculationParameters parameters,
  }) {
    final solar = SolarTime(
      year: year,
      month: month,
      day: day,
      latitude: latitude,
      longitude: longitude,
    );

    final transit = _fromHours(year, month, day, solar.transit);
    final sunriseTime = _fromHours(year, month, day, solar.sunrise);
    final sunsetTime = _fromHours(year, month, day, solar.sunset);
    final asrTime =
        _fromHours(year, month, day, solar.afternoon(parameters.madhab.shadowLength));

    // The night is measured to *tomorrow's* sunrise, so the high-latitude
    // fallbacks stay correct across the date boundary rather than folding
    // today's own sunrise back in.
    final tomorrow = DateTime.utc(year, month, day).add(_oneDay);
    final tomorrowSolar = SolarTime(
      year: tomorrow.year,
      month: tomorrow.month,
      day: tomorrow.day,
      latitude: latitude,
      longitude: longitude,
    );
    final tomorrowSunrise = _fromHours(
        tomorrow.year, tomorrow.month, tomorrow.day, tomorrowSolar.sunrise);

    if (sunriseTime == null || sunsetTime == null || tomorrowSunrise == null) {
      // Polar day or night: no sunrise to anchor anything to. Report what the
      // sun still does — it always transits — and leave the rest unknown.
      final adjusted = parameters.adjustments + parameters.method.methodAdjustments;
      return _DayCore(
        fajr: null,
        sunrise: null,
        dhuhr: _shift(transit, adjusted.dhuhr),
        asr: null,
        maghrib: null,
        sunset: null,
        isha: null,
      );
    }

    final night = tomorrowSunrise.difference(sunsetTime);
    final dayOfYear = DateTime.utc(year, month, day)
            .difference(DateTime.utc(year, 1, 1))
            .inDays +
        1;

    // ── Fajr ────────────────────────────────────────────────────────────────
    var fajrTime =
        _fromHours(year, month, day, solar.hourAngle(-parameters.fajrAngle, afterTransit: false));
    final safeFajr = _safeFajr(
      parameters: parameters,
      latitude: latitude,
      year: year,
      dayOfYear: dayOfYear,
      sunrise: sunriseTime,
      night: night,
    );
    if (fajrTime == null || fajrTime.isBefore(safeFajr)) fajrTime = safeFajr;

    // ── Isha ────────────────────────────────────────────────────────────────
    DateTime? ishaTime;
    if (parameters.ishaInterval > 0) {
      ishaTime = sunsetTime.add(Duration(minutes: parameters.ishaInterval));
    } else {
      ishaTime = _fromHours(
          year, month, day, solar.hourAngle(-parameters.ishaAngle, afterTransit: true));
      final safeIsha = _safeIsha(
        parameters: parameters,
        latitude: latitude,
        year: year,
        dayOfYear: dayOfYear,
        sunset: sunsetTime,
        night: night,
      );
      if (ishaTime == null || ishaTime.isAfter(safeIsha)) ishaTime = safeIsha;
    }

    // ── Maghrib ─────────────────────────────────────────────────────────────
    var maghribTime = sunsetTime;
    final maghribAngle = parameters.maghribAngle;
    if (maghribAngle != null) {
      final angleBased =
          _fromHours(year, month, day, solar.hourAngle(-maghribAngle, afterTransit: true));
      if (angleBased != null &&
          sunsetTime.isBefore(angleBased) &&
          ishaTime.isAfter(angleBased)) {
        maghribTime = angleBased;
      }
    }

    // The user's own offsets sit on top of the method's published ones, so
    // switching method never silently discards what the user typed.
    final total = parameters.adjustments + parameters.method.methodAdjustments;

    return _DayCore(
      fajr: _shift(fajrTime, total.fajr),
      sunrise: _shift(sunriseTime, total.sunrise),
      dhuhr: _shift(transit, total.dhuhr),
      asr: _shift(asrTime, total.asr),
      maghrib: _shift(maghribTime, total.maghrib),
      sunset: _shift(sunsetTime, total.maghrib),
      isha: _shift(ishaTime, total.isha),
    );
  }

  static DateTime _safeFajr({
    required CalculationParameters parameters,
    required double latitude,
    required int year,
    required int dayOfYear,
    required DateTime sunrise,
    required Duration night,
  }) {
    if (parameters.method == CalculationMethod.moonsightingCommittee) {
      if (latitude.abs() >= 55) {
        return sunrise.subtract(Duration(seconds: night.inSeconds ~/ 7));
      }
      final minutes = _seasonAdjustedTwilight(
        latitude: latitude,
        year: year,
        dayOfYear: dayOfYear,
        coefficients: _morningCoefficients,
      );
      return sunrise.subtract(Duration(seconds: (minutes * 60).round()));
    }
    final portion = parameters.nightPortions(latitude).fajr;
    return sunrise
        .subtract(Duration(seconds: (portion * night.inSeconds).round()));
  }

  static DateTime _safeIsha({
    required CalculationParameters parameters,
    required double latitude,
    required int year,
    required int dayOfYear,
    required DateTime sunset,
    required Duration night,
  }) {
    if (parameters.method == CalculationMethod.moonsightingCommittee) {
      if (latitude.abs() >= 55) {
        return sunset.add(Duration(seconds: night.inSeconds ~/ 7));
      }
      final minutes = _seasonAdjustedTwilight(
        latitude: latitude,
        year: year,
        dayOfYear: dayOfYear,
        coefficients: _eveningCoefficients,
      );
      return sunset.add(Duration(seconds: (minutes * 60).round()));
    }
    final portion = parameters.nightPortions(latitude).isha;
    return sunset.add(Duration(seconds: (portion * night.inSeconds).round()));
  }

  /// The Moonsighting Committee's seasonal twilight tables: minutes between
  /// sunrise/sunset and the twilight boundary, interpolated across the year
  /// from four latitude-scaled anchor values.
  static double _seasonAdjustedTwilight({
    required double latitude,
    required int year,
    required int dayOfYear,
    required List<double> coefficients,
  }) {
    final absLatitude = latitude.abs();
    final a = 75 + ((coefficients[0] / 55.0) * absLatitude);
    final b = 75 + ((coefficients[1] / 55.0) * absLatitude);
    final c = 75 + ((coefficients[2] / 55.0) * absLatitude);
    final d = 75 + ((coefficients[3] / 55.0) * absLatitude);

    final dyy = Astronomical.daysSinceSolstice(
      dayOfYear: dayOfYear,
      year: year,
      latitude: latitude,
    );

    if (dyy < 91) return a + (b - a) / 91.0 * dyy;
    if (dyy < 137) return b + (c - b) / 46.0 * (dyy - 91);
    if (dyy < 183) return c + (d - c) / 46.0 * (dyy - 137);
    if (dyy < 229) return d + (c - d) / 46.0 * (dyy - 183);
    if (dyy < 275) return c + (b - c) / 46.0 * (dyy - 229);
    return b + (a - b) / 91.0 * (dyy - 275);
  }

  /// Latitude coefficients for morning twilight. The third is subtracted in
  /// the published table, hence the negative sign here.
  static const List<double> _morningCoefficients = [28.65, 19.44, 32.74, 48.10];

  /// Evening twilight, "general" shafaq — the committee's default.
  static const List<double> _eveningCoefficients = [25.60, 2.050, -9.210, 6.140];
}

/// A UT hour offset from midnight of [year]-[month]-[day], as a UTC instant.
///
/// `hours` may fall outside `[0, 24)` — an event can belong to the previous or
/// next UTC day at extreme longitudes — and `Duration` handles that. NaN means
/// the sun never reached the requested altitude.
DateTime? _fromHours(int year, int month, int day, double hours) {
  if (hours.isNaN || hours.isInfinite) return null;
  return DateTime.utc(year, month, day)
      .add(Duration(milliseconds: (hours * 3600 * 1000).round()));
}

DateTime? _shift(DateTime? time, int minutes) {
  if (time == null) return null;
  return _roundToMinute(time.add(Duration(minutes: minutes)));
}

/// Prayer times are published to the minute; carrying seconds through would
/// make two equal times compare unequal and make the countdown jitter.
DateTime _roundToMinute(DateTime time) {
  final rounded = DateTime.utc(
    time.year,
    time.month,
    time.day,
    time.hour,
    time.minute,
  );
  return time.second >= 30 ? rounded.add(const Duration(minutes: 1)) : rounded;
}
