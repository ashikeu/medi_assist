import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/alarm_sound_model.dart';
import '../constants/app_colors.dart';
import '../services/alarm_sound_service.dart';
import '../utils/app_utils.dart';

/// The form row that shows which sound an alarm will play and opens the
/// picker.
///
/// [selected] is the reminder's own choice; `null` means "follow the app-wide
/// default", which is what most reminders will be. [accent] lets each module
/// keep its own colour.
class AlarmSoundRow extends StatelessWidget {
  const AlarmSoundRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.isDark,
    this.accent = AppColors.primary,
    this.allowInherit = true,
  });

  /// The reminder's stored preference, or `null` for "use the default".
  final Rx<AlarmSound?> selected;

  final ValueChanged<AlarmSound?> onChanged;
  final bool isDark;
  final Color accent;

  /// False on the Settings screen, where the value *is* the default and
  /// therefore has nothing to inherit from.
  final bool allowInherit;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final choice = selected.value;
      final effective = AlarmSoundService.to.resolve(choice);

      return InkWell(
        onTap: () async {
          final picked = await showAlarmSoundPicker(
            context: context,
            current: choice,
            accent: accent,
            allowInherit: allowInherit,
          );
          // `null` from the sheet means dismissed, which must not be confused
          // with the user actively choosing "follow the default" — the sheet
          // signals that with an explicit sentinel.
          if (picked != null) onChanged(picked.value);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.music_note_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'alarm_sound'.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice == null && allowInherit
                          ? 'alarm_sound_using_default'
                              .trParams({'sound': effective.displayLabel})
                          : effective.displayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'alarm_sound_preview'.tr,
                onPressed: () => AlarmSoundService.to.preview(effective),
                icon: Icon(Icons.play_circle_outline_rounded, color: accent),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
    });
  }
}

/// What the picker sheet hands back.
///
/// Wrapped so that "the user chose to follow the default" (`value == null`)
/// stays distinguishable from "the user dismissed the sheet" (no result).
class AlarmSoundChoice {
  const AlarmSoundChoice(this.value);

  final AlarmSound? value;
}

/// Opens the sound picker.
///
/// Returns `null` if dismissed.
Future<AlarmSoundChoice?> showAlarmSoundPicker({
  required BuildContext context,
  required AlarmSound? current,
  Color accent = AppColors.primary,
  bool allowInherit = true,
}) async {
  final result = await showModalBottomSheet<AlarmSoundChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AlarmSoundSheet(
      current: current,
      accent: accent,
      allowInherit: allowInherit,
    ),
  );
  // Whatever happens, nothing should still be playing once the sheet is gone.
  await AlarmSoundService.to.stopPreview();
  return result;
}

class _AlarmSoundSheet extends StatefulWidget {
  const _AlarmSoundSheet({
    required this.current,
    required this.accent,
    required this.allowInherit,
  });

  final AlarmSound? current;
  final Color accent;
  final bool allowInherit;

  @override
  State<_AlarmSoundSheet> createState() => _AlarmSoundSheetState();
}

class _AlarmSoundSheetState extends State<_AlarmSoundSheet> {
  late AlarmSound? _selected = widget.current;
  bool _importing = false;

  AlarmSoundService get _service => AlarmSoundService.to;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(isDark),
          _buildHeader(),
          const Divider(height: 1),
          Flexible(
            child: Obx(() {
              // Depend on the library revision so an import appears the moment
              // it lands, without this sheet being rebuilt from outside.
              _service.revision.value;
              final library = _service.library;

              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (widget.allowInherit)
                    _buildOption(
                      sound: null,
                      label: 'alarm_sound_use_default'.tr,
                      detail: 'alarm_sound_use_default_detail'.trParams(
                          {'sound': _service.defaultSound.displayLabel}),
                      isDark: isDark,
                    ),
                  _buildOption(
                    sound: AlarmSound.appDefault,
                    label: AlarmSound.appDefault.displayLabel,
                    detail: 'alarm_sound_app_default_detail'.tr,
                    isDark: isDark,
                  ),
                  _buildOption(
                    sound: AlarmSound.systemDefault,
                    label: AlarmSound.systemDefault.displayLabel,
                    detail: 'alarm_sound_system_default_detail'.tr,
                    isDark: isDark,
                  ),
                  if (library.isNotEmpty) ...[
                    _buildSectionLabel('alarm_sound_your_sounds'.tr),
                    // Eager `.map().toList()` — a lazy builder inside Obx would
                    // not register as a dependency.
                    ...library.map((sound) => _buildOption(
                          sound: sound,
                          label: sound.displayLabel,
                          detail: _service.isAvailable(sound)
                              ? 'alarm_sound_imported'.tr
                              : 'alarm_sound_missing'.tr,
                          isDark: isDark,
                          isMissing: !_service.isAvailable(sound),
                          onDelete: () => _remove(sound),
                        )),
                  ],
                  _buildSectionLabel('alarm_sound_add'.tr),
                  _buildImportRow(
                    icon: Icons.library_music_outlined,
                    label: 'alarm_sound_pick_ringtone'.tr,
                    detail: 'alarm_sound_pick_ringtone_detail'.tr,
                    onTap: () => _import(_service.importFromRingtonePicker),
                  ),
                  _buildImportRow(
                    icon: Icons.folder_open_rounded,
                    label: 'alarm_sound_pick_file'.tr,
                    detail: 'alarm_sound_pick_file_detail'.tr,
                    onTap: () => _import(_service.importFromFile),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'alarm_sound_scope_note'.tr,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) => Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(
          children: [
            Icon(Icons.music_note_rounded, size: 20, color: widget.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'alarm_sound'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_importing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      );

  Widget _buildSectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: Colors.grey.shade500,
          ),
        ),
      );

  Widget _buildOption({
    required AlarmSound? sound,
    required String label,
    required String detail,
    required bool isDark,
    bool isMissing = false,
    VoidCallback? onDelete,
  }) {
    final isSelected = _selected == sound;

    return InkWell(
      onTap: () {
        setState(() => _selected = sound);
        // Previewing on selection is the whole point of a sound picker; the
        // "follow the default" row previews whatever that default resolves to.
        _service.preview(_service.resolve(sound));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? widget.accent : Colors.grey.shade400,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isMissing
                          ? Colors.grey.shade500
                          : (isSelected ? widget.accent : null),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMissing
                          ? AppColors.danger
                          : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'delete'.tr,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.danger,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportRow({
    required IconData icon,
    required String label,
    required String detail,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _importing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: widget.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancel'.tr),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(AlarmSoundChoice(_selected)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
              ),
              child: Text('ok'.tr),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(Future<SoundImportResult> Function() importer) async {
    setState(() => _importing = true);
    try {
      final result = await importer();
      if (!mounted) return;

      if (result.isSuccess) {
        setState(() => _selected = result.sound);
        _service.preview(result.sound!);
        return;
      }
      if (result.wasCancelled) return;

      AppUtils.showError(_messageFor(result.failure!));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _remove(AlarmSound sound) async {
    final confirmed = await AppUtils.showConfirmDialog(
      title: 'alarm_sound_remove_title'.tr,
      message: 'alarm_sound_remove_message'
          .trParams({'sound': sound.displayLabel}),
      confirmText: 'delete'.tr,
    );
    if (!confirmed) return;

    await _service.removeFromLibrary(sound);
    if (!mounted) return;
    // Anything still pointing at the removed sound has to stop doing so, or
    // the sheet would show a tick against a row that no longer exists.
    if (_selected == sound) setState(() => _selected = null);
  }

  static String _messageFor(SoundImportFailure failure) {
    switch (failure) {
      case SoundImportFailure.tooLarge:
        return 'alarm_sound_too_large'.tr;
      case SoundImportFailure.unsupportedFormat:
        return 'alarm_sound_unsupported'.tr;
      case SoundImportFailure.unreadable:
        return 'alarm_sound_unreadable'.tr;
      case SoundImportFailure.cancelled:
      case SoundImportFailure.unavailable:
        return 'alarm_sound_unavailable'.tr;
    }
  }
}
