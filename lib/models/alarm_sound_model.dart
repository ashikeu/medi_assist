import 'package:get/get.dart';

import '../core/constants/app_constants.dart';

/// Where an alarm's audio comes from.
///
/// The `id` is what gets **stored**, so it never changes with the UI language.
enum AlarmSoundKind {
  /// The tone bundled with the app (`assets/audio/alarm.mp3`).
  appDefault('app_default'),

  /// Whatever the phone is set to use for alarms. The `alarm` package resolves
  /// this itself when `assetAudioPath` is null, via `RingtoneManager`.
  systemDefault('system_default'),

  /// A ringtone or audio file the user chose, copied into the app's own
  /// documents directory. See [AlarmSound.path].
  custom('custom');

  const AlarmSoundKind(this.id);

  final String id;

  static AlarmSoundKind byId(String? id) => AlarmSoundKind.values.firstWhere(
        (k) => k.id == id,
        orElse: () => appDefault,
      );
}

/// The sound one alarm plays.
///
/// A custom sound is referenced by a path **relative to the app's documents
/// directory**, not by the `content://` URI or external path it was picked
/// from. Three reasons, all of which have teeth:
///
///  * the `alarm` plugin plays `assetAudioPath` through `MediaPlayer` with no
///    `Context`, so a `content://` URI is not reliably playable;
///  * the native re-arm sweep replays the same path with no Flutter engine and
///    no granted URI permission, hours or days later;
///  * the file the user picked can be deleted or moved out from under them,
///    and an alarm that silently stops making noise is the worst failure this
///    app has.
///
/// `AlarmSoundService` is what copies a pick into that directory.
class AlarmSound {
  const AlarmSound._({required this.kind, this.path, this.label});

  final AlarmSoundKind kind;

  /// Relative to the app documents directory, e.g. `alarm_sounds/ab12.ogg`.
  /// Only set for [AlarmSoundKind.custom].
  final String? path;

  /// What to call it on screen — the ringtone's own title, or the file name.
  final String? label;

  static const AlarmSound appDefault =
      AlarmSound._(kind: AlarmSoundKind.appDefault);

  static const AlarmSound systemDefault =
      AlarmSound._(kind: AlarmSoundKind.systemDefault);

  factory AlarmSound.custom({required String path, required String label}) =>
      AlarmSound._(kind: AlarmSoundKind.custom, path: path, label: label);

  bool get isCustom => kind == AlarmSoundKind.custom;

  /// The value to hand to `AlarmSettings.assetAudioPath`.
  ///
  /// `null` is meaningful rather than missing: the plugin reads it as "use the
  /// device's default alarm sound".
  String? get assetAudioPath {
    switch (kind) {
      case AlarmSoundKind.appDefault:
        return AppConstants.alarmAudioPath;
      case AlarmSoundKind.systemDefault:
        return null;
      case AlarmSoundKind.custom:
        return path;
    }
  }

  /// The name to show. Built-ins go through `.tr` so they follow the app's
  /// language; a custom sound keeps the title it was imported with.
  String get displayLabel {
    switch (kind) {
      case AlarmSoundKind.appDefault:
        return 'alarm_sound_app_default'.tr;
      case AlarmSoundKind.systemDefault:
        return 'alarm_sound_system_default'.tr;
      case AlarmSoundKind.custom:
        return label ?? 'alarm_sound_custom'.tr;
    }
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.id,
        'path': path,
        'label': label,
      };

  factory AlarmSound.fromJson(Map<String, dynamic> json) {
    final kind = AlarmSoundKind.byId(json['kind'] as String?);
    if (kind != AlarmSoundKind.custom) {
      return kind == AlarmSoundKind.systemDefault ? systemDefault : appDefault;
    }
    final path = json['path'] as String?;
    // A custom entry with no path is corrupt; falling back to the bundled tone
    // keeps the alarm audible rather than silently resolving to nothing.
    if (path == null || path.isEmpty) return appDefault;
    return AlarmSound.custom(path: path, label: json['label'] as String? ?? '');
  }

  /// Parses a stored value that may be absent, for the "inherit the global
  /// default" case.
  static AlarmSound? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return AlarmSound.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSound &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          path == other.path;

  @override
  int get hashCode => Object.hash(kind, path);

  @override
  String toString() => 'AlarmSound(${kind.id}${path == null ? '' : ', $path'})';
}
