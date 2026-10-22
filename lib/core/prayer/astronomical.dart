import 'dart:math' as math;

/// Solar position maths behind the prayer times, ported from the Adhan
/// algorithm (itself Jean Meeus, *Astronomical Algorithms*, 2nd ed.).
///
/// Everything here is pure arithmetic on UTC instants — no Flutter, no
/// storage, no locale — so `test/prayer_times_test.dart` can pin it against
/// published timetables.
///
/// Angles are in **degrees** unless a name says otherwise; the `radians`
/// helper is applied at each trigonometric call rather than kept in a
/// radian-valued variable, which is what the reference implementation does and
/// what makes the two comparable line by line.
class Astronomical {
  Astronomical._();

  static double radians(double degrees) => degrees * math.pi / 180.0;

  static double degrees(double radians) => radians * 180.0 / math.pi;

  /// Wraps [value] into `[0, max)`. Used to keep angles inside one turn.
  static double normalizeWithBound(double value, double max) =>
      value - (max * (value / max).floorToDouble());

  static double unwindAngle(double angle) => normalizeWithBound(angle, 360.0);

  /// Maps an angle onto `[-180, 180]`, the branch the transit correction needs.
  static double quadrantShiftAngle(double angle) {
    if (angle >= -180 && angle <= 180) return angle;
    return angle - (360 * (angle / 360).roundToDouble());
  }

  // ─── Julian dates ─────────────────────────────────────────────────────────

  /// Julian Day for a Gregorian calendar date, [hours] being the UT fraction.
  static double julianDay(int year, int month, int day, [double hours = 0.0]) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    final i0 = (365.25 * (y + 4716)).floor();
    final i1 = (30.6001 * (m + 1)).floor();
    return i0 + i1 + day + (hours / 24) + b - 1524.5;
  }

  /// Julian centuries since J2000.0 — the time argument every series below is
  /// expressed in.
  static double julianCentury(double julianDay) =>
      (julianDay - 2451545.0) / 36525.0;

  // ─── Periodic terms ───────────────────────────────────────────────────────

  static double meanSolarLongitude(double t) {
    const term1 = 280.4664567;
    final term2 = 36000.76983 * t;
    final term3 = 0.0003032 * t * t;
    return unwindAngle(term1 + term2 + term3);
  }

  static double meanLunarLongitude(double t) =>
      unwindAngle(218.3165 + (481267.8813 * t));

  static double ascendingLunarNodeLongitude(double t) {
    const term1 = 125.04452;
    final term2 = 1934.136261 * t;
    final term3 = 0.0020708 * t * t;
    final term4 = (t * t * t) / 450000;
    return unwindAngle(term1 - term2 + term3 + term4);
  }

  static double meanSolarAnomaly(double t) {
    const term1 = 357.52911;
    final term2 = 35999.05029 * t;
    final term3 = 0.0001537 * t * t;
    return unwindAngle(term1 + term2 - term3);
  }

  static double solarEquationOfTheCenter(double t, double meanAnomaly) {
    final m = radians(meanAnomaly);
    final term1 = (1.914602 - (0.004817 * t) - (0.000014 * t * t)) * math.sin(m);
    final term2 = (0.019993 - (0.000101 * t)) * math.sin(2 * m);
    final term3 = 0.000289 * math.sin(3 * m);
    return term1 + term2 + term3;
  }

  static double apparentSolarLongitude(double t, double meanLongitude) {
    final longitude =
        meanLongitude + solarEquationOfTheCenter(t, meanSolarAnomaly(t));
    final omega = 125.04 - (1934.136 * t);
    final lambda = longitude - 0.00569 - (0.00478 * math.sin(radians(omega)));
    return unwindAngle(lambda);
  }

  static double meanObliquityOfTheEcliptic(double t) {
    const term1 = 23.439291;
    final term2 = 0.013004167 * t;
    final term3 = 0.0000001639 * t * t;
    final term4 = 0.0000005036 * t * t * t;
    return term1 - term2 - term3 + term4;
  }

  static double apparentObliquityOfTheEcliptic(double t, double meanObliquity) {
    final o = 125.04 - (1934.136 * t);
    return meanObliquity + (0.00256 * math.cos(radians(o)));
  }

  static double meanSiderealTime(double t) {
    final jd = (t * 36525) + 2451545.0;
    const term1 = 280.46061837;
    final term2 = 360.98564736629 * (jd - 2451545);
    final term3 = 0.000387933 * t * t;
    final term4 = (t * t * t) / 38710000;
    return unwindAngle(term1 + term2 + term3 - term4);
  }

  static double nutationInLongitude(
      double solarLongitude, double lunarLongitude, double ascendingNode) {
    final term1 = (-17.2 / 3600) * math.sin(radians(ascendingNode));
    final term2 = (1.32 / 3600) * math.sin(2 * radians(solarLongitude));
    final term3 = (0.23 / 3600) * math.sin(2 * radians(lunarLongitude));
    final term4 = (0.21 / 3600) * math.sin(2 * radians(ascendingNode));
    return term1 - term2 - term3 + term4;
  }

  static double nutationInObliquity(
      double solarLongitude, double lunarLongitude, double ascendingNode) {
    final term1 = (9.2 / 3600) * math.cos(radians(ascendingNode));
    final term2 = (0.57 / 3600) * math.cos(2 * radians(solarLongitude));
    final term3 = (0.10 / 3600) * math.cos(2 * radians(lunarLongitude));
    final term4 = (0.09 / 3600) * math.cos(2 * radians(ascendingNode));
    return term1 + term2 + term3 - term4;
  }

  /// Altitude of a body at [declination] and [localHourAngle], seen from
  /// [latitude].
  static double altitudeOfCelestialBody({
    required double latitude,
    required double declination,
    required double localHourAngle,
  }) {
    final term1 = math.sin(radians(latitude)) * math.sin(radians(declination));
    final term2 = math.cos(radians(latitude)) *
        math.cos(radians(declination)) *
        math.cos(radians(localHourAngle));
    return degrees(math.asin(term1 + term2));
  }

  // ─── Transit & hour angles ────────────────────────────────────────────────

  /// First guess at solar transit, as a fraction of a day.
  static double approximateTransit({
    required double longitude,
    required double siderealTime,
    required double rightAscension,
  }) {
    final lw = longitude * -1;
    return normalizeWithBound((rightAscension + lw - siderealTime) / 360, 1.0);
  }

  /// Solar transit in hours UT, corrected by interpolating the neighbouring
  /// days' right ascensions.
  static double correctedTransit({
    required double approximateTransit,
    required double longitude,
    required double siderealTime,
    required double rightAscension,
    required double previousRightAscension,
    required double nextRightAscension,
  }) {
    final lw = longitude * -1;
    final theta = unwindAngle(siderealTime + (360.985647 * approximateTransit));
    final alpha = unwindAngle(interpolateAngles(
      value: rightAscension,
      previousValue: previousRightAscension,
      nextValue: nextRightAscension,
      factor: approximateTransit,
    ));
    final hourAngle = quadrantShiftAngle(theta - lw - alpha);
    final delta = hourAngle / -360;
    return (approximateTransit + delta) * 24;
  }

  /// Time in hours UT at which the sun reaches altitude [angle].
  ///
  /// Returns `double.nan` when the sun never reaches that altitude on this
  /// day — the polar case the high-latitude rules exist to paper over.
  static double correctedHourAngle({
    required double approximateTransit,
    required double angle,
    required double latitude,
    required double longitude,
    required bool afterTransit,
    required double siderealTime,
    required double rightAscension,
    required double previousRightAscension,
    required double nextRightAscension,
    required double declination,
    required double previousDeclination,
    required double nextDeclination,
  }) {
    final lw = longitude * -1;
    final term1 = math.sin(radians(angle)) -
        (math.sin(radians(latitude)) * math.sin(radians(declination)));
    final term2 = math.cos(radians(latitude)) * math.cos(radians(declination));
    final ratio = term1 / term2;
    if (ratio.isNaN || ratio < -1 || ratio > 1) return double.nan;

    final h0 = degrees(math.acos(ratio));
    final m = afterTransit
        ? approximateTransit + (h0 / 360)
        : approximateTransit - (h0 / 360);

    final theta = unwindAngle(siderealTime + (360.985647 * m));
    final alpha = unwindAngle(interpolateAngles(
      value: rightAscension,
      previousValue: previousRightAscension,
      nextValue: nextRightAscension,
      factor: m,
    ));
    final delta = interpolate(
      value: declination,
      previousValue: previousDeclination,
      nextValue: nextDeclination,
      factor: m,
    );

    final localHourAngle = theta - lw - alpha;
    final h = altitudeOfCelestialBody(
      latitude: latitude,
      declination: delta,
      localHourAngle: localHourAngle,
    );

    final numerator = h - angle;
    final denominator = 360 *
        math.cos(radians(delta)) *
        math.cos(radians(latitude)) *
        math.sin(radians(localHourAngle));
    return (m + (numerator / denominator)) * 24;
  }

  /// Three-point interpolation (Meeus 3.3).
  static double interpolate({
    required double value,
    required double previousValue,
    required double nextValue,
    required double factor,
  }) {
    final a = value - previousValue;
    final b = nextValue - value;
    final c = b - a;
    return value + ((factor / 2) * (a + b + (factor * c)));
  }

  /// As [interpolate], but unwinds each difference so the interpolation is not
  /// thrown by right ascension wrapping through 360°.
  static double interpolateAngles({
    required double value,
    required double previousValue,
    required double nextValue,
    required double factor,
  }) {
    final a = unwindAngle(value - previousValue);
    final b = unwindAngle(nextValue - value);
    final c = b - a;
    return value + ((factor / 2) * (a + b + (factor * c)));
  }

  /// Days since the December solstice, which is what the Moonsighting
  /// Committee's seasonal twilight tables are indexed by. Southern-hemisphere
  /// callers get the June solstice instead, since their seasons are inverted.
  static int daysSinceSolstice({
    required int dayOfYear,
    required int year,
    required double latitude,
  }) {
    final leap = isLeapYear(year);
    final daysInYear = leap ? 366 : 365;
    if (latitude >= 0) {
      var days = dayOfYear + 10;
      if (days >= daysInYear) days -= daysInYear;
      return days;
    }
    var days = dayOfYear - (leap ? 173 : 172);
    if (days < 0) days += daysInYear;
    return days;
  }

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}

/// The sun's apparent position for one Julian Day.
class SolarCoordinates {
  factory SolarCoordinates(double julianDay) {
    final t = Astronomical.julianCentury(julianDay);

    final meanSolar = Astronomical.meanSolarLongitude(t);
    final meanLunar = Astronomical.meanLunarLongitude(t);
    final ascendingNode = Astronomical.ascendingLunarNodeLongitude(t);
    final apparentSolar =
        Astronomical.radians(Astronomical.apparentSolarLongitude(t, meanSolar));

    final meanObliquity = Astronomical.meanObliquityOfTheEcliptic(t);
    final apparentObliquity = Astronomical.radians(
        Astronomical.apparentObliquityOfTheEcliptic(t, meanObliquity));

    final declination = Astronomical.degrees(
        math.asin(math.sin(apparentObliquity) * math.sin(apparentSolar)));

    final rightAscension = Astronomical.unwindAngle(Astronomical.degrees(
        math.atan2(math.cos(apparentObliquity) * math.sin(apparentSolar),
            math.cos(apparentSolar))));

    final apparentSiderealTime = Astronomical.meanSiderealTime(t) +
        (((Astronomical.nutationInLongitude(
                        meanSolar, meanLunar, ascendingNode) *
                    3600) *
                math.cos(Astronomical.radians(meanObliquity +
                    Astronomical.nutationInObliquity(
                        meanSolar, meanLunar, ascendingNode)))) /
            3600);

    return SolarCoordinates._(
      declination: declination,
      rightAscension: rightAscension,
      apparentSiderealTime: apparentSiderealTime,
    );
  }

  const SolarCoordinates._({
    required this.declination,
    required this.rightAscension,
    required this.apparentSiderealTime,
  });

  /// Declination of the sun, degrees north of the celestial equator.
  final double declination;

  /// Apparent right ascension, degrees.
  final double rightAscension;

  /// Apparent sidereal time at Greenwich, degrees.
  final double apparentSiderealTime;
}

/// Solar event times for one day at one place, in hours UT.
class SolarTime {
  factory SolarTime({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
  }) {
    final julian = Astronomical.julianDay(year, month, day);
    final previous = SolarCoordinates(julian - 1);
    final solar = SolarCoordinates(julian);
    final next = SolarCoordinates(julian + 1);

    return SolarTime._(
      latitude: latitude,
      longitude: longitude,
      approximateTransit: Astronomical.approximateTransit(
        longitude: longitude,
        siderealTime: solar.apparentSiderealTime,
        rightAscension: solar.rightAscension,
      ),
      previous: previous,
      solar: solar,
      next: next,
    );
  }

  SolarTime._({
    required this.latitude,
    required this.longitude,
    required double approximateTransit,
    required SolarCoordinates previous,
    required SolarCoordinates solar,
    required SolarCoordinates next,
  })  : _approximateTransit = approximateTransit,
        _previous = previous,
        _solar = solar,
        _next = next,
        transit = Astronomical.correctedTransit(
          approximateTransit: approximateTransit,
          longitude: longitude,
          siderealTime: solar.apparentSiderealTime,
          rightAscension: solar.rightAscension,
          previousRightAscension: previous.rightAscension,
          nextRightAscension: next.rightAscension,
        );

  final double latitude;
  final double longitude;
  final double _approximateTransit;
  final SolarCoordinates _previous;
  final SolarCoordinates _solar;
  final SolarCoordinates _next;

  /// Solar noon, hours UT.
  final double transit;

  /// The refraction-corrected altitude of the solar disc's upper limb at the
  /// horizon: 50 arcminutes below true horizontal.
  static const double horizonAltitude = -50.0 / 60.0;

  double get sunrise => hourAngle(horizonAltitude, afterTransit: false);

  double get sunset => hourAngle(horizonAltitude, afterTransit: true);

  /// Hours UT at which the sun sits [angle] degrees above the horizon.
  double hourAngle(double angle, {required bool afterTransit}) {
    return Astronomical.correctedHourAngle(
      approximateTransit: _approximateTransit,
      angle: angle,
      latitude: latitude,
      longitude: longitude,
      afterTransit: afterTransit,
      siderealTime: _solar.apparentSiderealTime,
      rightAscension: _solar.rightAscension,
      previousRightAscension: _previous.rightAscension,
      nextRightAscension: _next.rightAscension,
      declination: _solar.declination,
      previousDeclination: _previous.declination,
      nextDeclination: _next.declination,
    );
  }

  /// Asr: the moment an object's shadow reaches [shadowLength] times its own
  /// length, on top of the shadow it cast at noon.
  double afternoon(double shadowLength) {
    final tangent = (latitude - _solar.declination).abs();
    final inverse = shadowLength + math.tan(Astronomical.radians(tangent));
    final angle = Astronomical.degrees(math.atan(1 / inverse));
    return hourAngle(angle, afterTransit: true);
  }
}
