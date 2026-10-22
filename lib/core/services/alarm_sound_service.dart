import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/alarm_sound_model.dart';
import '../constants/app_constants.dart';
import '../utils/id_generator.dart';
import 'storage_service.dart';

/// Why importing a sound did not produce one.
enum SoundImportFailure {
  /// The user backed out of the picker. Not an error.
  cancelled,

  /// Past [AppConstants.maxAlarmSoundBytes].
  tooLarge,

  /// Not one of [AppConstants.alarmSoundExtensions].
  unsupportedFormat,

  /// The file or ringtone could not be read.
  unreadable,

  unavailable,
}

/// The outcome of asking the user for a sound.
class SoundImportResult {
  const SoundImportResult.success(this.sound) : failure = null;
  const SoundImportResult.failure(this.failure) : sound = null;

  final AlarmSound? sound;
  final SoundImportFailure? failure;

  bool get isSuccess => sound != null;
  bool get wasCancelled => failure == SoundImportFailure.cancelled;
}

/// Picking, importing, previewing and remembering alarm sounds.
///
/// Every imported sound is **copied into the app's documents directory** and
/// referenced by a relative path from then on. See the note on [AlarmSound] for
/// why; the short version is that neither a `content://` ringtone URI nor a
/// path into shared storage is still readable from the broadcast receiver that
/// re-arms alarms days later, with no Flutter engine and no URI grant.
class AlarmSoundService extends GetxService {
  static AlarmSoundService get to => Get.find();

  static const MethodChannel _channel =
      MethodChannel('com.mediassist.app/sound');

  /// Bumped when the library changes, so open pickers repaint.
  final RxInt revision = 0.obs;

  // ─── The global default ───────────────────────────────────────────────────

  /// The sound used by any reminder that does not name its own.
  AlarmSound get defaultSound => StorageService.to.defaultAlarmSound;

  Future<void> setDefaultSound(AlarmSound sound) async {
    await StorageService.to.setDefaultAlarmSound(sound);
    revision.value++;
  }

  /// Resolves a reminder's stored choice, falling back to the global default.
  ///
  /// This is the single place that decision is made, so "inherit" means the
  /// same thing on every screen and in the scheduler.
  AlarmSound resolve(AlarmSound? preference) => preference ?? defaultSound;

  /// What to hand to `AlarmSettings.assetAudioPath`, with the missing-file
  /// case already handled.
  String? resolvedAudioPath(AlarmSound? preference) {
    final sound = resolve(preference);
    if (!sound.isCustom) return sound.assetAudioPath;

    // A custom sound whose file has gone — cleared app storage, a failed
    // restore — must not silence the alarm. Fall back to the bundled tone.
    if (!isAvailable(sound)) {
      debugPrint('⚠️ Alarm sound missing (${sound.path}); using bundled tone');
      return AlarmSound.appDefault.assetAudioPath;
    }
    return sound.assetAudioPath;
  }

  // ─── The library of imported sounds ───────────────────────────────────────

  /// Sounds the user has imported before, most recent first.
  List<AlarmSound> get library => StorageService.to.alarmSoundLibrary;

  /// Whether a custom sound's file is still on disk.
  bool isAvailable(AlarmSound sound) {
    if (!sound.isCustom) return true;
    final absolute = absolutePathFor(sound);
    return absolute != null && File(absolute).existsSync();
  }

  /// The on-disk path of a custom sound, once [initialize] has resolved the
  /// documents directory.
  String? absolutePathFor(AlarmSound sound) {
    final relative = sound.path;
    if (relative == null || _documentsPath == null) return null;
    return '$_documentsPath/$relative';
  }

  String? _documentsPath;

  /// Resolves the documents directory once.
  ///
  /// Called from `main()` before `runApp`: [resolvedAudioPath] runs on the
  /// scheduling path, which must not be async, and needs the directory to
  /// check whether a file is still there.
  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _documentsPath = directory.path;
    } catch (e) {
      debugPrint('⚠️ Could not resolve documents directory: $e');
    }
  }

  Future<Directory?> _soundsDirectory() async {
    if (_documentsPath == null) await initialize();
    if (_documentsPath == null) return null;
    final directory =
        Directory('$_documentsPath/${AppConstants.alarmSoundsDirName}');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // ─── Importing ────────────────────────────────────────────────────────────

  /// Opens Android's own ringtone picker and imports what comes back.
  Future<SoundImportResult> importFromRingtonePicker() async {
    if (!Platform.isAndroid) {
      return const SoundImportResult.failure(SoundImportFailure.unavailable);
    }

    final Map<String, dynamic>? picked;
    try {
      picked = await _channel.invokeMapMethod<String, dynamic>(
        'pickRingtone',
        {'title': 'alarm_sound_pick_ringtone'.tr},
      );
    } on PlatformException catch (e) {
      debugPrint('🔈 Ringtone picker failed: ${e.code} ${e.message}');
      return const SoundImportResult.failure(SoundImportFailure.unavailable);
    }

    if (picked == null) {
      return const SoundImportResult.failure(SoundImportFailure.cancelled);
    }

    final uri = picked['uri'] as String?;
    if (uri == null || uri.isEmpty) {
      return const SoundImportResult.failure(SoundImportFailure.cancelled);
    }

    final directory = await _soundsDirectory();
    if (directory == null) {
      return const SoundImportResult.failure(SoundImportFailure.unavailable);
    }

    try {
      // Native does the copy: only it can read a content URI, and streaming it
      // there avoids carrying the whole file through the method channel.
      final copied = await _channel.invokeMapMethod<String, dynamic>('copyUri', {
        'uri': uri,
        'directory': directory.path,
        'baseName': IdGenerator.generate(),
        'maxBytes': AppConstants.maxAlarmSoundBytes,
      });

      final absolute = copied?['path'] as String?;
      if (absolute == null) {
        return const SoundImportResult.failure(SoundImportFailure.unreadable);
      }

      final title = (picked['title'] as String?)?.trim();
      return SoundImportResult.success(await _register(
        absolutePath: absolute,
        label: title == null || title.isEmpty
            ? 'alarm_sound_custom'.tr
            : title,
      ));
    } on PlatformException catch (e) {
      debugPrint('🔈 Ringtone copy failed: ${e.code} ${e.message}');
      return SoundImportResult.failure(
        e.code == 'too_large'
            ? SoundImportFailure.tooLarge
            : SoundImportFailure.unreadable,
      );
    }
  }

  /// Opens the file picker and imports the chosen audio file.
  Future<SoundImportResult> importFromFile() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
    } catch (e) {
      debugPrint('🔈 File picker failed: $e');
      return const SoundImportResult.failure(SoundImportFailure.unavailable);
    }

    if (picked == null || picked.files.isEmpty) {
      return const SoundImportResult.failure(SoundImportFailure.cancelled);
    }

    final file = picked.files.single;
    final sourcePath = file.path;
    if (sourcePath == null) {
      return const SoundImportResult.failure(SoundImportFailure.unreadable);
    }

    final extension = _extensionOf(sourcePath);
    if (!AppConstants.alarmSoundExtensions.contains(extension)) {
      return const SoundImportResult.failure(
          SoundImportFailure.unsupportedFormat);
    }

    final source = File(sourcePath);
    try {
      if (await source.length() > AppConstants.maxAlarmSoundBytes) {
        return const SoundImportResult.failure(SoundImportFailure.tooLarge);
      }

      final directory = await _soundsDirectory();
      if (directory == null) {
        return const SoundImportResult.failure(SoundImportFailure.unavailable);
      }

      final destination =
          File('${directory.path}/${IdGenerator.generate()}.$extension');
      await source.copy(destination.path);

      final name = file.name.trim();
      return SoundImportResult.success(await _register(
        absolutePath: destination.path,
        label: name.isEmpty ? 'alarm_sound_custom'.tr : name,
      ));
    } catch (e) {
      debugPrint('🔈 Could not import $sourcePath: $e');
      return const SoundImportResult.failure(SoundImportFailure.unreadable);
    }
  }

  /// Records a freshly copied file in the library and returns it.
  Future<AlarmSound> _register({
    required String absolutePath,
    required String label,
  }) async {
    final relative = _relativeToDocuments(absolutePath);
    final sound = AlarmSound.custom(path: relative, label: label);

    final entries = library
      // Re-importing the same ringtone should move it to the top rather than
      // list it twice.
      ..removeWhere((s) => s.label == label && s.path == relative)
      ..insert(0, sound);

    await StorageService.to.saveAlarmSoundLibrary(entries);
    revision.value++;
    return sound;
  }

  /// Removes a sound from the library and deletes its file.
  ///
  /// Any reminder still pointing at it falls back to the bundled tone through
  /// [resolvedAudioPath], so this can never leave an alarm silent.
  Future<void> removeFromLibrary(AlarmSound sound) async {
    if (!sound.isCustom) return;

    final absolute = absolutePathFor(sound);
    if (absolute != null) {
      try {
        final file = File(absolute);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('⚠️ Could not delete ${sound.path}: $e');
      }
    }

    final entries = library..removeWhere((s) => s.path == sound.path);
    await StorageService.to.saveAlarmSoundLibrary(entries);

    // If the global default was the sound just removed, something has to take
    // its place — leaving it dangling would push every alarm through the
    // missing-file fallback.
    if (defaultSound.path == sound.path) {
      await setDefaultSound(AlarmSound.appDefault);
    }
    revision.value++;
  }

  String _relativeToDocuments(String absolutePath) {
    final base = _documentsPath;
    if (base != null && absolutePath.startsWith('$base/')) {
      return absolutePath.substring(base.length + 1);
    }
    // Should not happen — the file was just written into that directory — but
    // an absolute path still plays, so keep it rather than losing the import.
    return absolutePath;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  // ─── Preview ──────────────────────────────────────────────────────────────

  /// Plays a sound once, so the user can hear what they are about to choose.
  Future<void> preview(AlarmSound sound) async {
    if (!Platform.isAndroid) return;
    try {
      // Absolute for a custom sound: the native player resolves relative paths
      // the same way the alarm plugin does, but being explicit keeps the two
      // from drifting.
      final path = sound.isCustom
          ? absolutePathFor(sound)
          : sound.assetAudioPath;
      await _channel.invokeMethod<void>('preview', {'path': path});
    } on PlatformException catch (e) {
      debugPrint('🔈 Preview failed: ${e.code} ${e.message}');
    }
  }

  Future<void> stopPreview() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } on PlatformException catch (e) {
      debugPrint('🔈 Stopping preview failed: ${e.code} ${e.message}');
    }
  }
}
