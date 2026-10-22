/// The prayers, sun events and optional night markers the app can show.
///
/// The `id` is what gets **stored** — in the settings box, in a reminder, in a
/// backup — so it never changes with the UI language. The display name comes
/// from `prayer_<id>` in `AppTranslations`.
enum PrayerKind {
  fajr('fajr'),
  sunrise('sunrise'),
  dhuhr('dhuhr'),
  asr('asr'),
  maghrib('maghrib'),
  sunset('sunset'),
  isha('isha'),
  midnight('midnight'),
  tahajjud('tahajjud');

  const PrayerKind(this.id);

  final String id;

  /// The five daily obligatory prayers, in order.
  static const List<PrayerKind> obligatory = [
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
  ];

  /// Everything the schedule screen lists, obligatory prayers first.
  static const List<PrayerKind> schedule = [
    fajr,
    sunrise,
    dhuhr,
    asr,
    maghrib,
    sunset,
    isha,
    midnight,
    tahajjud,
  ];

  bool get isObligatory => obligatory.contains(this);

  /// Translation key for the prayer's name.
  String get nameKey => 'prayer_$id';

  static PrayerKind? byId(String? id) {
    for (final kind in PrayerKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// Juristic method for the Asr shadow length.
enum Madhab {
  /// Shadow equal to the object's own length — Shafi'i, Maliki, Hanbali.
  shafi('shafi', 1.0),

  /// Shadow twice the object's own length — Hanafi.
  hanafi('hanafi', 2.0);

  const Madhab(this.id, this.shadowLength);

  final String id;
  final double shadowLength;

  String get nameKey => 'madhab_$id';

  static Madhab byId(String? id) => Madhab.values.firstWhere(
        (m) => m.id == id,
        orElse: () => Madhab.shafi,
      );
}

/// How to derive Fajr and Isha where the sun never dips far enough below the
/// horizon for the twilight angles to be reached.
enum HighLatitudeRule {
  /// Fajr and Isha are pushed no further than the midpoint of the night.
  middleOfTheNight('middle_of_the_night'),

  /// Fajr no earlier than a seventh of the night before sunrise, Isha no later
  /// than a seventh of the night after sunset.
  seventhOfTheNight('seventh_of_the_night'),

  /// The night portion is scaled by the twilight angle itself, so a method
  /// with a shallower angle gets a proportionally shorter portion.
  twilightAngle('twilight_angle');

  const HighLatitudeRule(this.id);

  final String id;

  String get nameKey => 'high_lat_$id';

  /// What to use when the user has not chosen: places far enough north or
  /// south to have real twilight problems get the seventh-of-the-night rule.
  static HighLatitudeRule recommendedFor(double latitude) =>
      latitude.abs() > 48 ? seventhOfTheNight : middleOfTheNight;

  static HighLatitudeRule byId(String? id) => HighLatitudeRule.values.firstWhere(
        (r) => r.id == id,
        orElse: () => middleOfTheNight,
      );
}

/// Per-prayer offsets, in whole minutes.
class PrayerAdjustments {
  const PrayerAdjustments({
    this.fajr = 0,
    this.sunrise = 0,
    this.dhuhr = 0,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
  });

  final int fajr;
  final int sunrise;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  static const PrayerAdjustments none = PrayerAdjustments();

  PrayerAdjustments operator +(PrayerAdjustments other) => PrayerAdjustments(
        fajr: fajr + other.fajr,
        sunrise: sunrise + other.sunrise,
        dhuhr: dhuhr + other.dhuhr,
        asr: asr + other.asr,
        maghrib: maghrib + other.maghrib,
        isha: isha + other.isha,
      );

  int forPrayer(PrayerKind kind) {
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
      case PrayerKind.sunset:
        return maghrib;
      case PrayerKind.isha:
        return isha;
      case PrayerKind.midnight:
      case PrayerKind.tahajjud:
        return 0;
    }
  }

  PrayerAdjustments withPrayer(PrayerKind kind, int minutes) {
    switch (kind) {
      case PrayerKind.fajr:
        return copyWith(fajr: minutes);
      case PrayerKind.sunrise:
        return copyWith(sunrise: minutes);
      case PrayerKind.dhuhr:
        return copyWith(dhuhr: minutes);
      case PrayerKind.asr:
        return copyWith(asr: minutes);
      case PrayerKind.maghrib:
      case PrayerKind.sunset:
        return copyWith(maghrib: minutes);
      case PrayerKind.isha:
        return copyWith(isha: minutes);
      case PrayerKind.midnight:
      case PrayerKind.tahajjud:
        return this;
    }
  }

  PrayerAdjustments copyWith({
    int? fajr,
    int? sunrise,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
  }) =>
      PrayerAdjustments(
        fajr: fajr ?? this.fajr,
        sunrise: sunrise ?? this.sunrise,
        dhuhr: dhuhr ?? this.dhuhr,
        asr: asr ?? this.asr,
        maghrib: maghrib ?? this.maghrib,
        isha: isha ?? this.isha,
      );

  bool get isEmpty =>
      fajr == 0 &&
      sunrise == 0 &&
      dhuhr == 0 &&
      asr == 0 &&
      maghrib == 0 &&
      isha == 0;

  Map<String, dynamic> toJson() => {
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
      };

  factory PrayerAdjustments.fromJson(Map<String, dynamic> json) =>
      PrayerAdjustments(
        fajr: (json['fajr'] as num?)?.toInt() ?? 0,
        sunrise: (json['sunrise'] as num?)?.toInt() ?? 0,
        dhuhr: (json['dhuhr'] as num?)?.toInt() ?? 0,
        asr: (json['asr'] as num?)?.toInt() ?? 0,
        maghrib: (json['maghrib'] as num?)?.toInt() ?? 0,
        isha: (json['isha'] as num?)?.toInt() ?? 0,
      );
}

/// The published calculation methods, i.e. the twilight angles each authority
/// uses plus the small per-prayer offsets that come with them.
///
/// Selecting one seeds [CalculationParameters]; the user can then override the
/// angles individually without losing which method they started from.
enum CalculationMethod {
  muslimWorldLeague(
    'muslim_world_league',
    fajrAngle: 18.0,
    ishaAngle: 17.0,
    methodAdjustments: PrayerAdjustments(dhuhr: 1),
  ),
  egyptian(
    'egyptian',
    fajrAngle: 19.5,
    ishaAngle: 17.5,
    methodAdjustments: PrayerAdjustments(dhuhr: 1),
  ),
  karachi(
    'karachi',
    fajrAngle: 18.0,
    ishaAngle: 18.0,
    methodAdjustments: PrayerAdjustments(dhuhr: 1),
  ),
  ummAlQura(
    'umm_al_qura',
    fajrAngle: 18.5,
    ishaAngle: 0.0,
    ishaInterval: 90,
  ),
  dubai(
    'dubai',
    fajrAngle: 18.2,
    ishaAngle: 18.2,
    methodAdjustments:
        PrayerAdjustments(sunrise: -3, dhuhr: 3, asr: 3, maghrib: 3),
  ),
  moonsightingCommittee(
    'moonsighting_committee',
    fajrAngle: 18.0,
    ishaAngle: 18.0,
    methodAdjustments: PrayerAdjustments(dhuhr: 5, maghrib: 3),
  ),
  northAmerica(
    'north_america',
    fajrAngle: 15.0,
    ishaAngle: 15.0,
    methodAdjustments: PrayerAdjustments(dhuhr: 1),
  ),
  kuwait('kuwait', fajrAngle: 18.0, ishaAngle: 17.5),
  qatar('qatar', fajrAngle: 18.0, ishaAngle: 0.0, ishaInterval: 90),
  singapore(
    'singapore',
    fajrAngle: 20.0,
    ishaAngle: 18.0,
    methodAdjustments: PrayerAdjustments(dhuhr: 1),
  ),
  tehran(
    'tehran',
    fajrAngle: 17.7,
    ishaAngle: 14.0,
    maghribAngle: 4.5,
  ),
  turkey(
    'turkey',
    fajrAngle: 18.0,
    ishaAngle: 17.0,
    methodAdjustments:
        PrayerAdjustments(sunrise: -7, dhuhr: 5, asr: 4, maghrib: 7),
  ),
  /// Islamic Foundation Bangladesh — Karachi's angles with the Foundation's
  /// own published per-prayer caution margins.
  bangladesh(
    'bangladesh',
    fajrAngle: 18.0,
    ishaAngle: 18.0,
    methodAdjustments:
        PrayerAdjustments(fajr: -1, dhuhr: 4, asr: 3, maghrib: 3, isha: 3),
  ),

  /// Angles at zero — the starting point for someone entering their local
  /// committee's own figures by hand.
  other('other', fajrAngle: 0.0, ishaAngle: 0.0);

  const CalculationMethod(
    this.id, {
    required this.fajrAngle,
    required this.ishaAngle,
    this.ishaInterval = 0,
    this.maghribAngle,
    this.methodAdjustments = PrayerAdjustments.none,
  });

  final String id;
  final double fajrAngle;
  final double ishaAngle;

  /// Minutes after Maghrib at which Isha begins. Non-zero replaces
  /// [ishaAngle] entirely — Umm Al-Qura and Qatar work this way.
  final int ishaInterval;

  /// Depression angle for Maghrib where sunset alone is not used (Tehran).
  final double? maghribAngle;

  /// Offsets baked into the published method, kept apart from the user's own
  /// [CalculationParameters.adjustments] so changing method does not wipe
  /// what the user typed.
  final PrayerAdjustments methodAdjustments;

  String get nameKey => 'calc_method_$id';

  static CalculationMethod byId(String? id) => CalculationMethod.values
      .firstWhere((m) => m.id == id, orElse: () => muslimWorldLeague);

  CalculationParameters get parameters => CalculationParameters(
        method: this,
        fajrAngle: fajrAngle,
        ishaAngle: ishaAngle,
        ishaInterval: ishaInterval,
        maghribAngle: maghribAngle,
      );
}

/// Everything the calculation needs beyond a date and a coordinate.
class CalculationParameters {
  const CalculationParameters({
    required this.method,
    required this.fajrAngle,
    required this.ishaAngle,
    this.ishaInterval = 0,
    this.maghribAngle,
    this.madhab = Madhab.shafi,
    this.highLatitudeRule,
    this.adjustments = PrayerAdjustments.none,
  });

  final CalculationMethod method;
  final double fajrAngle;
  final double ishaAngle;
  final int ishaInterval;
  final double? maghribAngle;
  final Madhab madhab;

  /// `null` means "let the latitude decide" — see
  /// [HighLatitudeRule.recommendedFor].
  final HighLatitudeRule? highLatitudeRule;

  /// The user's own per-prayer minute offsets, applied on top of the method's.
  final PrayerAdjustments adjustments;

  CalculationParameters copyWith({
    CalculationMethod? method,
    double? fajrAngle,
    double? ishaAngle,
    int? ishaInterval,
    double? maghribAngle,
    bool clearMaghribAngle = false,
    Madhab? madhab,
    HighLatitudeRule? highLatitudeRule,
    bool clearHighLatitudeRule = false,
    PrayerAdjustments? adjustments,
  }) =>
      CalculationParameters(
        method: method ?? this.method,
        fajrAngle: fajrAngle ?? this.fajrAngle,
        ishaAngle: ishaAngle ?? this.ishaAngle,
        ishaInterval: ishaInterval ?? this.ishaInterval,
        maghribAngle:
            clearMaghribAngle ? null : (maghribAngle ?? this.maghribAngle),
        madhab: madhab ?? this.madhab,
        highLatitudeRule: clearHighLatitudeRule
            ? null
            : (highLatitudeRule ?? this.highLatitudeRule),
        adjustments: adjustments ?? this.adjustments,
      );

  /// Fraction of the night that Fajr may start before sunrise, and Isha end
  /// after sunset, under the effective high-latitude rule.
  ({double fajr, double isha}) nightPortions(double latitude) {
    final rule = highLatitudeRule ?? HighLatitudeRule.recommendedFor(latitude);
    switch (rule) {
      case HighLatitudeRule.middleOfTheNight:
        return (fajr: 1 / 2, isha: 1 / 2);
      case HighLatitudeRule.seventhOfTheNight:
        return (fajr: 1 / 7, isha: 1 / 7);
      case HighLatitudeRule.twilightAngle:
        return (fajr: fajrAngle / 60, isha: ishaAngle / 60);
    }
  }
}
