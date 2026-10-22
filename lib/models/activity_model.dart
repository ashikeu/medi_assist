import 'package:flutter/material.dart';

import 'alarm_sound_model.dart';

class Activity {
  final String id;
  final String name;
  final TimeOfDay time;
  final String notificationType; // 'notification', 'alarm', 'both', 'none'
  final bool isActive;
  /// The sound this reminder's alarm plays, or `null` to follow the app-wide
  /// default. Only meaningful for alarm-type reminders: a notification's sound
  /// is a property of its Android channel, not of the notification.
  final AlarmSound? alarmSound;
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.name,
    required this.time,
    required this.notificationType,
    this.isActive = true,
    this.alarmSound,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ─── Copy With ──────────────────────────────────────────────────────────────
  Activity copyWith({
    String? id,
    String? name,
    TimeOfDay? time,
    String? notificationType,
    bool? isActive,
    AlarmSound? alarmSound,
    bool clearAlarmSound = false,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      notificationType: notificationType ?? this.notificationType,
      isActive: isActive ?? this.isActive,
      alarmSound:
          clearAlarmSound ? null : (alarmSound ?? this.alarmSound),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── JSON Serialization ─────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'time': {'hour': time.hour, 'minute': time.minute},
      'notificationType': notificationType,
      'isActive': isActive,
      'alarmSound': alarmSound?.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    final timeMap = json['time'] as Map;
    return Activity(
      id: json['id'] as String,
      name: json['name'] as String,
      time: TimeOfDay(
        hour: timeMap['hour'] as int,
        minute: timeMap['minute'] as int,
      ),
      notificationType: json['notificationType'] as String,
      isActive: json['isActive'] as bool? ?? true,
      // Absent in anything saved before per-reminder sounds existed, which
      // reads as "follow the default" — exactly the right migration.
      alarmSound: AlarmSound.tryFromJson(json['alarmSound']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  String toString() => 'Activity(id: $id, name: $name, time: $formattedTime)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}