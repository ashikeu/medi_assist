import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_assist/core/constants/app_constants.dart';
import 'package:medi_assist/models/medicine_model.dart';

void main() {
  group('Medicine serialization', () {
    test('survives a JSON round trip', () {
      final original = Medicine(
        id: 'med-1',
        name: 'Metformin',
        times: const [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 30)],
        notificationType: AppConstants.notifTypeBoth,
        createdAt: DateTime(2026, 1, 2, 3, 4, 5),
      );

      final restored = Medicine.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.notificationType, original.notificationType);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
      expect(restored.times.length, 2);
      expect(restored.times[1].hour, 20);
      expect(restored.times[1].minute, 30);
    });
  });

  group('Snooze ID mapping', () {
    test('maps every alarm range into the snooze range', () {
      for (final base in [
        AppConstants.medicineAlarmBase,
        AppConstants.mealAlarmBase,
        AppConstants.activityAlarmBase,
        AppConstants.medicalAlarmBase,
      ]) {
        for (final offset in [0, 1, 250, 999]) {
          final snoozeId = AppConstants.snoozeIdFor(base + offset);
          expect(AppConstants.isSnoozeId(snoozeId), isTrue);
        }
      }
    });

    test('never collides with the alarm ID it came from', () {
      // A snooze reusing its source ID would overwrite the next day's alarm,
      // walking the daily reminder later by the snooze duration each time.
      final alarmId = AppConstants.medicineAlarmBase + 40;
      expect(AppConstants.snoozeIdFor(alarmId), isNot(alarmId));
      expect(AppConstants.isSnoozeId(alarmId), isFalse);
    });

    test('is stable, so re-snoozing replaces rather than stacks', () {
      final alarmId = AppConstants.mealAlarmBase + 7;
      expect(
        AppConstants.snoozeIdFor(alarmId),
        AppConstants.snoozeIdFor(alarmId),
      );
    });
  });
}
