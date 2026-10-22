import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'alarm_sound_model.dart';

/// One reminder attached to one prayer.
///
/// A prayer can hold several of these — "15 minutes before", "at the prayer",
/// "10 minutes after" are three independent reminders sharing a [prayerId],
/// which is what lets each carry its own sound, alarm type and wording.
///
/// [prayerId] is either a [PrayerKind] id (`fajr`, `isha`, …) or the id of a
/// [CustomPrayerEvent]. It is stored, so it never changes with the UI
/// language.
class PrayerReminder {
  PrayerReminder({
    required this.id,
    required this.prayerId,
    this.offsetMinutes = 0,
    this.exactTime,
    this.notificationType = AppConstants.notifTypeNotification,
    this.isActive = true,
    this.playSound = true,
    this.vibrate = true,
    this.loopAudio = false,
    this.alarmSound,
    this.title,
    this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String prayerId;

  /// Minutes relative to the prayer: negative is before, `0` is at the prayer
  /// time itself, positive is after. Ignored when [exactTime] is set.
  final int offsetMinutes;

  /// A wall-clock time at the prayer location, for a reminder that should fire
  /// at the same time every day regardless of where the prayer falls.
  ///
  /// When this is set the reminder no longer tracks the sun; [prayerId] is
  /// kept anyway, because it is still what the reminder is *for* and it is how
  /// the reminder is grouped and named.
  final TimeOfDay? exactTime;

  /// Whether this fires at a fixed clock time rather than relative to the
  /// prayer.
  bool get usesExactTime => exactTime != null;

  /// `notification`, `alarm`, `both` or `none` — the same vocabulary the rest
  /// of the app's reminders use, so a prayer alarm behaves like a medicine
  /// alarm and is silenced the same way.
  final String notificationType;

  final bool isActive;

  /// Whether the reminder makes a sound. Routed through a second, silent
  /// notification channel rather than a per-notification flag, because Android
  /// only lets a channel's sound be set when the channel is created.
  final bool playSound;

  final bool vibrate;

  /// Keeps an alarm ringing until it is stopped, instead of playing once.
  final bool loopAudio;

  /// The sound the alarm plays, or `null` to follow the app-wide default.
  final AlarmSound? alarmSound;

  /// Overrides for the notification's wording. `null` falls back to the
  /// translated default, which is what keeps an untouched reminder following
  /// the app's language.
  final String? title;
  final String? message;

  final DateTime createdAt;

  bool get isBefore => !usesExactTime && offsetMinutes < 0;
  bool get isAfter => !usesExactTime && offsetMinutes > 0;
  bool get isAtPrayerTime => !usesExactTime && offsetMinutes == 0;

  bool get usesNotification =>
      notificationType == AppConstants.notifTypeNotification ||
      notificationType == AppConstants.notifTypeBoth;

  bool get usesAlarm =>
      notificationType == AppConstants.notifTypeAlarm ||
      notificationType == AppConstants.notifTypeBoth;

  /// The instant this reminder should fire for a prayer that starts at
  /// [prayerTime]. Only meaningful for an offset reminder — an exact-time one
  /// is resolved by `PrayerService`, which owns the location's wall clock.
  DateTime fireTimeFor(DateTime prayerTime) =>
      prayerTime.add(Duration(minutes: offsetMinutes));

  PrayerReminder copyWith({
    String? id,
    String? prayerId,
    int? offsetMinutes,
    TimeOfDay? exactTime,
    bool clearExactTime = false,
    String? notificationType,
    bool? isActive,
    bool? playSound,
    bool? vibrate,
    bool? loopAudio,
    AlarmSound? alarmSound,
    bool clearAlarmSound = false,
    String? title,
    bool clearTitle = false,
    String? message,
    bool clearMessage = false,
    DateTime? createdAt,
  }) =>
      PrayerReminder(
        id: id ?? this.id,
        prayerId: prayerId ?? this.prayerId,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
        exactTime: clearExactTime ? null : (exactTime ?? this.exactTime),
        notificationType: notificationType ?? this.notificationType,
        isActive: isActive ?? this.isActive,
        playSound: playSound ?? this.playSound,
        vibrate: vibrate ?? this.vibrate,
        loopAudio: loopAudio ?? this.loopAudio,
        alarmSound:
            clearAlarmSound ? null : (alarmSound ?? this.alarmSound),
        title: clearTitle ? null : (title ?? this.title),
        message: clearMessage ? null : (message ?? this.message),
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'prayerId': prayerId,
        'offsetMinutes': offsetMinutes,
        'exactTime': exactTime == null
            ? null
            : {'hour': exactTime!.hour, 'minute': exactTime!.minute},
        'notificationType': notificationType,
        'isActive': isActive,
        'playSound': playSound,
        'vibrate': vibrate,
        'loopAudio': loopAudio,
        'alarmSound': alarmSound?.toJson(),
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PrayerReminder.fromJson(Map<String, dynamic> json) {
    final exact = json['exactTime'];
    return PrayerReminder(
      id: json['id'] as String,
      prayerId: json['prayerId'] as String,
      offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
      exactTime: exact is Map
          ? TimeOfDay(
              hour: (exact['hour'] as num).toInt(),
              minute: (exact['minute'] as num).toInt(),
            )
          : null,
      notificationType: json['notificationType'] as String? ??
          AppConstants.notifTypeNotification,
      isActive: json['isActive'] as bool? ?? true,
      playSound: json['playSound'] as bool? ?? true,
      vibrate: json['vibrate'] as bool? ?? true,
      loopAudio: json['loopAudio'] as bool? ?? false,
      // Absent in anything saved before per-reminder sounds existed, which
      // reads as "follow the default" — exactly the right migration.
      alarmSound: AlarmSound.tryFromJson(json['alarmSound']),
      title: json['title'] as String?,
      message: json['message'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A user-defined prayer or event that sits alongside the calculated ones —
/// Ishraq, Duha, a nightly wird, a mosque's own jamaat time.
///
/// It is either *anchored* to a calculated prayer with an offset (so it moves
/// with the sun through the year) or pinned to a wall-clock time.
class CustomPrayerEvent {
  CustomPrayerEvent({
    required this.id,
    required this.name,
    this.anchorPrayerId,
    this.offsetMinutes = 0,
    this.fixedTime,
    this.isActive = true,
    DateTime? createdAt,
  })  : assert(anchorPrayerId != null || fixedTime != null,
            'A custom event needs either an anchor prayer or a fixed time'),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;

  /// [PrayerKind] id this event follows, or `null` for a fixed clock time.
  final String? anchorPrayerId;

  /// Minutes from the anchor prayer. Ignored when [fixedTime] is used.
  final int offsetMinutes;

  /// Wall-clock time at the location, used when [anchorPrayerId] is `null`.
  final TimeOfDay? fixedTime;

  final bool isActive;
  final DateTime createdAt;

  bool get isAnchored => anchorPrayerId != null;

  CustomPrayerEvent copyWith({
    String? id,
    String? name,
    String? anchorPrayerId,
    bool clearAnchor = false,
    int? offsetMinutes,
    TimeOfDay? fixedTime,
    bool clearFixedTime = false,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      CustomPrayerEvent(
        id: id ?? this.id,
        name: name ?? this.name,
        anchorPrayerId:
            clearAnchor ? null : (anchorPrayerId ?? this.anchorPrayerId),
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
        fixedTime: clearFixedTime ? null : (fixedTime ?? this.fixedTime),
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'anchorPrayerId': anchorPrayerId,
        'offsetMinutes': offsetMinutes,
        'fixedTime': fixedTime == null
            ? null
            : {'hour': fixedTime!.hour, 'minute': fixedTime!.minute},
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomPrayerEvent.fromJson(Map<String, dynamic> json) {
    final timeMap = json['fixedTime'];
    return CustomPrayerEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      anchorPrayerId: json['anchorPrayerId'] as String?,
      offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
      fixedTime: timeMap is Map
          ? TimeOfDay(
              hour: (timeMap['hour'] as num).toInt(),
              minute: (timeMap['minute'] as num).toInt(),
            )
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPrayerEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
