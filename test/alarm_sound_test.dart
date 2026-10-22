import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/models/activity_model.dart';
import 'package:medi_assist/models/alarm_sound_model.dart';
import 'package:medi_assist/models/meal_model.dart';
import 'package:medi_assist/models/medicine_model.dart';
import 'package:medi_assist/models/prayer_reminder_model.dart';

void main() {
  group('AlarmSound', () {
    test('maps each kind to what the alarm plugin expects', () {
      expect(AlarmSound.appDefault.assetAudioPath, AppConstants.alarmAudioPath);
      // Null is meaningful here, not missing: the plugin reads it as "use the
      // device's default alarm sound".
      expect(AlarmSound.systemDefault.assetAudioPath, isNull);
      expect(
        AlarmSound.custom(path: 'alarm_sounds/a.ogg', label: 'Adhan')
            .assetAudioPath,
        'alarm_sounds/a.ogg',
      );
    });

    test('round-trips through JSON', () {
      for (final sound in [
        AlarmSound.appDefault,
        AlarmSound.systemDefault,
        AlarmSound.custom(path: 'alarm_sounds/a.ogg', label: 'Adhan'),
      ]) {
        final restored = AlarmSound.fromJson(sound.toJson());
        expect(restored, sound);
        expect(restored.assetAudioPath, sound.assetAudioPath);
      }
    });

    test('keeps a custom sound label across a round trip', () {
      final restored = AlarmSound.fromJson(
        AlarmSound.custom(path: 'alarm_sounds/a.ogg', label: 'Adhan').toJson(),
      );
      expect(restored.label, 'Adhan');
    });

    // A corrupt entry that resolved to nothing would leave the alarm silent,
    // which is the worst failure this app has.
    test('falls back to the bundled tone for a custom entry with no path', () {
      final restored = AlarmSound.fromJson({'kind': 'custom', 'path': null});
      expect(restored, AlarmSound.appDefault);
      expect(restored.assetAudioPath, AppConstants.alarmAudioPath);
    });

    test('treats an unknown kind as the bundled tone', () {
      expect(AlarmSound.fromJson({'kind': 'nonsense'}), AlarmSound.appDefault);
    });

    test('reads a missing stored value as "no preference"', () {
      expect(AlarmSound.tryFromJson(null), isNull);
      expect(AlarmSound.tryFromJson('not a map'), isNull);
      expect(
        AlarmSound.tryFromJson({'kind': 'system_default'}),
        AlarmSound.systemDefault,
      );
    });

    test('picks the right channel for each sound and vibration combination',
        () {
      String channel({required bool sound, required bool vibrate}) =>
          AppConstants.prayerChannelFor(playSound: sound, vibrate: vibrate).id;

      final ids = {
        channel(sound: true, vibrate: true),
        channel(sound: true, vibrate: false),
        channel(sound: false, vibrate: true),
        channel(sound: false, vibrate: false),
      };
      // Android fixes sound and vibration per channel, so all four
      // combinations need distinct channels or one of them is a lie.
      expect(ids.length, 4);
    });
  });

  group('Reminder models carry the sound choice', () {
    final custom = AlarmSound.custom(path: 'alarm_sounds/a.ogg', label: 'Adhan');

    test('medicine, meal and activity round-trip it', () {
      final medicine = Medicine(
        id: 'm',
        name: 'Test',
        times: const [TimeOfDay(hour: 8, minute: 0)],
        notificationType: AppConstants.notifTypeAlarm,
        alarmSound: custom,
      );
      expect(Medicine.fromJson(medicine.toJson()).alarmSound, custom);

      final meal = Meal(
        id: 'e',
        name: 'Test',
        time: const TimeOfDay(hour: 8, minute: 0),
        notificationType: AppConstants.notifTypeAlarm,
        alarmSound: custom,
      );
      expect(Meal.fromJson(meal.toJson()).alarmSound, custom);

      final activity = Activity(
        id: 'a',
        name: 'Test',
        time: const TimeOfDay(hour: 8, minute: 0),
        notificationType: AppConstants.notifTypeAlarm,
        alarmSound: custom,
      );
      expect(Activity.fromJson(activity.toJson()).alarmSound, custom);
    });

    // Anything saved before per-reminder sounds existed has no such field, and
    // that has to read as "follow the default" rather than crash.
    test('read an absent sound as no preference', () {
      final legacy = {
        'id': 'm',
        'name': 'Test',
        'times': [
          {'hour': 8, 'minute': 0}
        ],
        'notificationType': AppConstants.notifTypeAlarm,
        'isActive': true,
      };
      expect(Medicine.fromJson(legacy).alarmSound, isNull);
    });

    test('clearAlarmSound goes back to following the default', () {
      final medicine = Medicine(
        id: 'm',
        name: 'Test',
        times: const [TimeOfDay(hour: 8, minute: 0)],
        notificationType: AppConstants.notifTypeAlarm,
        alarmSound: custom,
      );
      expect(medicine.copyWith(clearAlarmSound: true).alarmSound, isNull);
    });
  });

  group('PrayerReminder timing', () {
    test('defaults to an offset relative to the prayer', () {
      final reminder =
          PrayerReminder(id: 'r', prayerId: 'fajr', offsetMinutes: -15);
      expect(reminder.usesExactTime, isFalse);
      expect(reminder.isBefore, isTrue);

      final prayerTime = DateTime.utc(2026, 9, 22, 4, 30);
      expect(
        reminder.fireTimeFor(prayerTime),
        DateTime.utc(2026, 9, 22, 4, 15),
      );
    });

    test('an exact time is not before, after, or at the prayer', () {
      final reminder = PrayerReminder(
        id: 'r',
        prayerId: 'fajr',
        offsetMinutes: -15,
        exactTime: const TimeOfDay(hour: 4, minute: 30),
      );
      expect(reminder.usesExactTime, isTrue);
      // The offset wording would be a lie for a fixed clock time, so none of
      // the three offset predicates may claim it.
      expect(reminder.isBefore, isFalse);
      expect(reminder.isAfter, isFalse);
      expect(reminder.isAtPrayerTime, isFalse);
    });

    test('round-trips both modes through JSON', () {
      final offset = PrayerReminder(
        id: 'r',
        prayerId: 'fajr',
        offsetMinutes: -15,
        alarmSound: AlarmSound.systemDefault,
      );
      final restoredOffset = PrayerReminder.fromJson(offset.toJson());
      expect(restoredOffset.exactTime, isNull);
      expect(restoredOffset.offsetMinutes, -15);
      expect(restoredOffset.alarmSound, AlarmSound.systemDefault);

      final exact = PrayerReminder(
        id: 'r',
        prayerId: 'isha',
        exactTime: const TimeOfDay(hour: 21, minute: 45),
      );
      final restoredExact = PrayerReminder.fromJson(exact.toJson());
      expect(restoredExact.exactTime, const TimeOfDay(hour: 21, minute: 45));
      expect(restoredExact.usesExactTime, isTrue);
    });

    test('clearExactTime switches back to the offset mode', () {
      final exact = PrayerReminder(
        id: 'r',
        prayerId: 'isha',
        exactTime: const TimeOfDay(hour: 21, minute: 45),
      );
      expect(exact.copyWith(clearExactTime: true).usesExactTime, isFalse);
    });
  });
}
