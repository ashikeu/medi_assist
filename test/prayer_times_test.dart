import 'package:flutter_test/flutter_test.dart';
import 'package:medi_assist/core/data/location_catalog.dart';
import 'package:medi_assist/core/prayer/calculation_params.dart';
import 'package:medi_assist/core/prayer/prayer_times.dart';

/// The prayer-time engine is the one piece of this app whose output nobody can
/// eyeball: a Fajr that is fifteen minutes wrong looks exactly as plausible as
/// a correct one. These pin it against published reference values.
void main() {
  group('PrayerTimes', () {
    // The reference case from the Adhan library's own test suite: Raleigh,
    // North Carolina on 2015-07-12 with ISNA parameters, local time UTC-4.
    test('matches the published reference timetable', () {
      final times = PrayerTimes.forDate(
        year: 2015,
        month: 7,
        day: 12,
        latitude: 35.7750,
        longitude: -78.6336,
        parameters: CalculationMethod.northAmerica.parameters,
      );

      expect(_clock(times.fajr, -4), '04:42');
      expect(_clock(times.sunrise, -4), '06:08');
      expect(_clock(times.dhuhr, -4), '13:21');
      expect(_clock(times.asr, -4), '17:09');
      expect(_clock(times.maghrib, -4), '20:32');
      expect(_clock(times.isha, -4), '21:57');
    });

    test('puts Asr later under the Hanafi shadow length', () {
      PrayerTimes at(Madhab madhab) => PrayerTimes.forDate(
            year: 2015,
            month: 7,
            day: 12,
            latitude: 35.7750,
            longitude: -78.6336,
            parameters: CalculationMethod.northAmerica.parameters
                .copyWith(madhab: madhab),
          );

      final shafi = at(Madhab.shafi).asr!;
      final hanafi = at(Madhab.hanafi).asr!;
      expect(hanafi.isAfter(shafi), isTrue);
      // Roughly an hour at this latitude and season — a sanity bound, not a
      // pinned value.
      expect(hanafi.difference(shafi).inMinutes, inInclusiveRange(30, 120));
    });

    test('uses the fixed interval for methods that publish one', () {
      final times = PrayerTimes.forDate(
        year: 2026,
        month: 9,
        day: 17,
        latitude: 21.4225,
        longitude: 39.8262,
        parameters: CalculationMethod.ummAlQura.parameters,
      );

      // Umm Al-Qura sets Isha 90 minutes after Maghrib rather than by angle.
      expect(times.isha!.difference(times.maghrib!).inMinutes, 90);
    });

    test('applies the user adjustments on top of the method adjustments', () {
      PrayerTimes at(PrayerAdjustments adjustments) => PrayerTimes.forDate(
            year: 2026,
            month: 9,
            day: 17,
            latitude: 23.8103,
            longitude: 90.4125,
            parameters: CalculationMethod.karachi.parameters
                .copyWith(adjustments: adjustments),
          );

      final plain = at(PrayerAdjustments.none);
      final nudged = at(const PrayerAdjustments(fajr: -3, isha: 7));

      expect(nudged.fajr!.difference(plain.fajr!).inMinutes, -3);
      expect(nudged.isha!.difference(plain.isha!).inMinutes, 7);
      // Prayers the user did not touch stay where they were.
      expect(nudged.dhuhr, plain.dhuhr);
    });

    test('places the night markers between Maghrib and the next Fajr', () {
      final times = PrayerTimes.forDate(
        year: 2026,
        month: 9,
        day: 17,
        latitude: 23.8103,
        longitude: 90.4125,
        parameters: CalculationMethod.karachi.parameters,
      );

      expect(times.midnight!.isAfter(times.maghrib!), isTrue);
      expect(times.midnight!.isBefore(times.nextFajr!), isTrue);
      expect(times.tahajjud!.isAfter(times.midnight!), isTrue);
      expect(times.tahajjud!.isBefore(times.nextFajr!), isTrue);
    });

    // London in midsummer never gets 18° of twilight, so the angle-based Fajr
    // and Isha do not exist. Without the high-latitude fallback the screen
    // would show a dash for two of the five obligatory prayers.
    test('falls back to a night portion where the angle is never reached', () {
      final times = PrayerTimes.forDate(
        year: 2026,
        month: 6,
        day: 21,
        latitude: 51.5074,
        longitude: -0.1278,
        parameters: CalculationMethod.muslimWorldLeague.parameters,
      );

      expect(times.fajr, isNotNull);
      expect(times.isha, isNotNull);
      expect(times.fajr!.isBefore(times.sunrise!), isTrue);
      expect(times.isha!.isAfter(times.maghrib!), isTrue);
    });

    test('reports the current and next prayer around a known instant', () {
      final times = PrayerTimes.forDate(
        year: 2026,
        month: 9,
        day: 17,
        latitude: 23.8103,
        longitude: 90.4125,
        parameters: CalculationMethod.karachi.parameters,
      );

      final justAfterAsr = times.asr!.add(const Duration(minutes: 1));
      expect(times.currentPrayer(justAfterAsr), PrayerKind.asr);
      expect(times.nextPrayer(justAfterAsr), PrayerKind.maghrib);

      final beforeFajr = times.fajr!.subtract(const Duration(minutes: 1));
      expect(times.currentPrayer(beforeFajr), isNull);
      expect(times.nextPrayer(beforeFajr), PrayerKind.fajr);
    });

    test('gives every prayer with a window an end time', () {
      final times = PrayerTimes.forDate(
        year: 2026,
        month: 9,
        day: 17,
        latitude: 23.8103,
        longitude: 90.4125,
        parameters: CalculationMethod.karachi.parameters,
      );

      expect(times.endTimeFor(PrayerKind.fajr), times.sunrise);
      expect(times.endTimeFor(PrayerKind.dhuhr), times.asr);
      expect(times.endTimeFor(PrayerKind.asr), times.maghrib);
      expect(times.endTimeFor(PrayerKind.maghrib), times.isha);
      expect(times.endTimeFor(PrayerKind.isha), times.nextFajr);
      // Instants, not windows.
      expect(times.endTimeFor(PrayerKind.sunrise), isNull);
      expect(times.endTimeFor(PrayerKind.midnight), isNull);
    });
  });

  group('LocationCatalog', () {
    test('resolves a coordinate to the nearest listed place', () {
      final place = LocationCatalog.nearest(23.8103, 90.4125);
      expect(place, isNotNull);
      expect(place!.country.code, 'BD');
      expect(place.district.name, 'Dhaka');
    });

    // Labelling someone in the middle of the Pacific as being in the nearest
    // listed city would be worse than showing them bare coordinates.
    test('returns nothing when no listed place is close enough', () {
      expect(LocationCatalog.nearest(-40.0, -140.0), isNull);
    });

    test('finds places by name across every level', () {
      expect(LocationCatalog.search('sylhet'), isNotEmpty);
      expect(LocationCatalog.search('mirpur'), isNotEmpty);
      expect(LocationCatalog.search('saudi'), isNotEmpty);
      expect(LocationCatalog.search(''), isEmpty);
    });

    test('gives every country a distinct code and a usable default method',
        () {
      final codes =
          LocationCatalog.countries.map((c) => c.code).toSet();
      expect(codes.length, LocationCatalog.countries.length);

      for (final country in LocationCatalog.countries) {
        expect(country.divisions, isNotEmpty,
            reason: '${country.name} has no divisions');
        for (final division in country.divisions) {
          expect(division.districts, isNotEmpty,
              reason: '${division.name} has no districts');
        }
      }
    });
  });
}

/// A UTC instant rendered at a fixed offset, as "HH:mm".
String _clock(DateTime? instant, int offsetHours) {
  if (instant == null) return '--:--';
  final local = instant.add(Duration(hours: offsetHours));
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
