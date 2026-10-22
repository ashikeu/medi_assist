import '../core/data/location_catalog.dart';
import '../core/prayer/calculation_params.dart';

/// Where the location the prayer times are calculated for came from.
///
/// Stored rather than derived, because it changes what the UI offers: a GPS
/// fix can be re-taken, a catalogue pick can be narrowed to an area, and a
/// hand-entered coordinate must never be silently "corrected".
enum PrayerLocationSource {
  gps('gps'),
  catalog('catalog'),
  manual('manual');

  const PrayerLocationSource(this.id);

  final String id;

  String get nameKey => 'location_source_$id';

  static PrayerLocationSource byId(String? id) =>
      PrayerLocationSource.values.firstWhere(
        (s) => s.id == id,
        orElse: () => catalog,
      );
}

/// The place prayer times are calculated for.
///
/// The coordinate is authoritative; the country/division/district/area names
/// are labels on top of it. A GPS fix keeps its exact coordinate and borrows
/// only the *names* from the nearest catalogue entry, so the user sees a place
/// they recognise without the times being snapped to a city centre they are
/// nowhere near.
class PrayerLocation {
  PrayerLocation({
    required this.latitude,
    required this.longitude,
    this.countryCode,
    this.countryName,
    this.division,
    this.district,
    this.area,
    this.utcOffsetMinutes,
    this.source = PrayerLocationSource.catalog,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final double latitude;
  final double longitude;

  final String? countryCode;
  final String? countryName;
  final String? division;
  final String? district;
  final String? area;

  /// Minutes east of UTC to render these times in.
  ///
  /// `null` means "follow the device clock", which is both the common case and
  /// the one that handles daylight saving without the user doing anything. It
  /// is only set when the user picks somewhere in a different zone from the
  /// phone they are holding, where following the device would be wrong.
  final int? utcOffsetMinutes;

  final PrayerLocationSource source;
  final DateTime updatedAt;

  /// Dhaka — somewhere sensible to stand until the user says otherwise, and
  /// the app's primary audience.
  factory PrayerLocation.fallback() => PrayerLocation(
        latitude: 23.8103,
        longitude: 90.4125,
        countryCode: 'BD',
        countryName: 'Bangladesh',
        division: 'Dhaka',
        district: 'Dhaka',
        utcOffsetMinutes: null,
        source: PrayerLocationSource.catalog,
      );

  /// Builds a location from a catalogue pick.
  ///
  /// The zone offset is only pinned when the place is in a different one from
  /// the device: a user in Dhaka picking Dhaka keeps following their phone,
  /// while a user in London checking Makkah's times gets Makkah's clock.
  factory PrayerLocation.fromCatalog(
    CatalogPlace place, {
    required int deviceOffsetMinutes,
    PrayerLocationSource source = PrayerLocationSource.catalog,
  }) {
    final standard = place.country.standardUtcOffsetMinutes;
    // Within an hour of the device covers the daylight-saving case, where the
    // device is the more accurate of the two.
    final followsDevice = (standard - deviceOffsetMinutes).abs() <= 60;
    return PrayerLocation(
      latitude: place.latitude,
      longitude: place.longitude,
      countryCode: place.country.code,
      countryName: place.country.name,
      division: place.division.name,
      district: place.district.name,
      area: place.area?.name,
      utcOffsetMinutes: followsDevice ? null : standard,
      source: source,
    );
  }

  /// The calculation method the country's own authority publishes, or `null`
  /// where the country is outside the catalogue.
  CalculationMethod? get regionalMethod =>
      LocationCatalog.countryByCode(countryCode)?.defaultMethod;

  /// The offset these times are rendered in, resolving "follow the device".
  int resolvedOffsetMinutes(int deviceOffsetMinutes) =>
      utcOffsetMinutes ?? deviceOffsetMinutes;

  /// "Mirpur, Dhaka, Bangladesh" — the most specific labels first, with the
  /// duplicates a district-level pick would otherwise produce removed.
  String get displayName {
    final parts = <String>[];
    for (final part in [area, district, division, countryName]) {
      if (part == null || part.isEmpty) continue;
      if (parts.contains(part)) continue;
      parts.add(part);
    }
    if (parts.isEmpty) return coordinateLabel;
    return parts.join(', ');
  }

  /// "23.8103°N, 90.4125°E".
  String get coordinateLabel {
    final ns = latitude >= 0 ? 'N' : 'S';
    final ew = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$ns, '
        '${longitude.abs().toStringAsFixed(4)}°$ew';
  }

  bool get hasPlaceName =>
      (area != null && area!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      (countryName != null && countryName!.isNotEmpty);

  PrayerLocation copyWith({
    double? latitude,
    double? longitude,
    String? countryCode,
    String? countryName,
    String? division,
    String? district,
    String? area,
    bool clearArea = false,
    int? utcOffsetMinutes,
    bool clearUtcOffset = false,
    PrayerLocationSource? source,
    DateTime? updatedAt,
  }) =>
      PrayerLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        countryCode: countryCode ?? this.countryCode,
        countryName: countryName ?? this.countryName,
        division: division ?? this.division,
        district: district ?? this.district,
        area: clearArea ? null : (area ?? this.area),
        utcOffsetMinutes:
            clearUtcOffset ? null : (utcOffsetMinutes ?? this.utcOffsetMinutes),
        source: source ?? this.source,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'countryCode': countryCode,
        'countryName': countryName,
        'division': division,
        'district': district,
        'area': area,
        'utcOffsetMinutes': utcOffsetMinutes,
        'source': source.id,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PrayerLocation.fromJson(Map<String, dynamic> json) => PrayerLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        countryCode: json['countryCode'] as String?,
        countryName: json['countryName'] as String?,
        division: json['division'] as String?,
        district: json['district'] as String?,
        area: json['area'] as String?,
        utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt(),
        source: PrayerLocationSource.byId(json['source'] as String?),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  @override
  String toString() => 'PrayerLocation($displayName, $coordinateLabel)';
}
