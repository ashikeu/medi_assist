import '../core/prayer/calculation_params.dart';

/// The user's prayer-time calculation preferences.
///
/// Angles are kept separately from [method] so that picking a method seeds
/// them and hand-editing one afterwards does not have to abandon the method
/// label — which is what the user recognises. `null` on an angle means "use
/// whatever the method publishes".
class PrayerSettings {
  const PrayerSettings({
    this.method = CalculationMethod.muslimWorldLeague,
    this.madhab = Madhab.shafi,
    this.highLatitudeRule,
    this.customFajrAngle,
    this.customIshaAngle,
    this.customIshaInterval,
    this.adjustments = PrayerAdjustments.none,
  });

  final CalculationMethod method;
  final Madhab madhab;

  /// `null` lets the latitude choose — see [HighLatitudeRule.recommendedFor].
  final HighLatitudeRule? highLatitudeRule;

  /// Overrides for the method's published angles, in degrees.
  final double? customFajrAngle;
  final double? customIshaAngle;

  /// Minutes after Maghrib for Isha, overriding the angle entirely. `null`
  /// keeps the method's own choice; `0` forces the angle back on for a method
  /// that would otherwise use an interval.
  final int? customIshaInterval;

  /// The user's own per-prayer minute offsets, on top of the method's.
  final PrayerAdjustments adjustments;

  double get fajrAngle => customFajrAngle ?? method.fajrAngle;

  double get ishaAngle => customIshaAngle ?? method.ishaAngle;

  int get ishaInterval => customIshaInterval ?? method.ishaInterval;

  bool get hasCustomAngles =>
      customFajrAngle != null ||
      customIshaAngle != null ||
      customIshaInterval != null;

  /// Everything above, in the shape the calculation itself wants.
  CalculationParameters toParameters() => CalculationParameters(
        method: method,
        fajrAngle: fajrAngle,
        ishaAngle: ishaAngle,
        ishaInterval: ishaInterval,
        maghribAngle: method.maghribAngle,
        madhab: madhab,
        highLatitudeRule: highLatitudeRule,
        adjustments: adjustments,
      );

  PrayerSettings copyWith({
    CalculationMethod? method,
    Madhab? madhab,
    HighLatitudeRule? highLatitudeRule,
    bool clearHighLatitudeRule = false,
    double? customFajrAngle,
    bool clearCustomFajrAngle = false,
    double? customIshaAngle,
    bool clearCustomIshaAngle = false,
    int? customIshaInterval,
    bool clearCustomIshaInterval = false,
    PrayerAdjustments? adjustments,
  }) =>
      PrayerSettings(
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        highLatitudeRule: clearHighLatitudeRule
            ? null
            : (highLatitudeRule ?? this.highLatitudeRule),
        customFajrAngle: clearCustomFajrAngle
            ? null
            : (customFajrAngle ?? this.customFajrAngle),
        customIshaAngle: clearCustomIshaAngle
            ? null
            : (customIshaAngle ?? this.customIshaAngle),
        customIshaInterval: clearCustomIshaInterval
            ? null
            : (customIshaInterval ?? this.customIshaInterval),
        adjustments: adjustments ?? this.adjustments,
      );

  /// Drops every override and goes back to exactly what [method] publishes.
  PrayerSettings resetToMethodDefaults() => PrayerSettings(
        method: method,
        madhab: madhab,
        highLatitudeRule: null,
        adjustments: PrayerAdjustments.none,
      );

  Map<String, dynamic> toJson() => {
        'method': method.id,
        'madhab': madhab.id,
        'highLatitudeRule': highLatitudeRule?.id,
        'customFajrAngle': customFajrAngle,
        'customIshaAngle': customIshaAngle,
        'customIshaInterval': customIshaInterval,
        'adjustments': adjustments.toJson(),
      };

  factory PrayerSettings.fromJson(Map<String, dynamic> json) => PrayerSettings(
        method: CalculationMethod.byId(json['method'] as String?),
        madhab: Madhab.byId(json['madhab'] as String?),
        highLatitudeRule: json['highLatitudeRule'] == null
            ? null
            : HighLatitudeRule.byId(json['highLatitudeRule'] as String?),
        customFajrAngle: (json['customFajrAngle'] as num?)?.toDouble(),
        customIshaAngle: (json['customIshaAngle'] as num?)?.toDouble(),
        customIshaInterval: (json['customIshaInterval'] as num?)?.toInt(),
        adjustments: json['adjustments'] is Map
            ? PrayerAdjustments.fromJson(
                Map<String, dynamic>.from(json['adjustments'] as Map))
            : PrayerAdjustments.none,
      );
}
