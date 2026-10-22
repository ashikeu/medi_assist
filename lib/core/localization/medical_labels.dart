import 'package:get/get.dart';

import '../constants/app_constants.dart';

/// Display names for the medical-record tables in `AppConstants`.
///
/// Those tables stay English because their values are **stored** — a record
/// saved with `category: 'Fasting'` has to keep matching the dropdown after the
/// user switches language, and a backup taken in Bangla has to import in
/// English. So the English string remains the identity and this maps it to
/// whatever the current language calls it.
class MedicalLabels {
  MedicalLabels._();

  static const Map<String, String> _typeKeys = {
    AppConstants.recordBloodPressure: 'record_blood_pressure',
    AppConstants.recordHeartRate: 'record_heart_rate',
    AppConstants.recordOxygenLevel: 'record_oxygen_level',
    AppConstants.recordDiabetesLevel: 'record_diabetes_level',
    AppConstants.recordTemperature: 'record_temperature',
    AppConstants.recordWeight: 'record_weight',
  };

  static const Map<String, String> _hintKeys = {
    AppConstants.recordBloodPressure: 'record_hint_blood_pressure',
    AppConstants.recordHeartRate: 'record_hint_heart_rate',
    AppConstants.recordOxygenLevel: 'record_hint_oxygen_level',
    AppConstants.recordDiabetesLevel: 'record_hint_diabetes_level',
    AppConstants.recordTemperature: 'record_hint_temperature',
    AppConstants.recordWeight: 'record_hint_weight',
  };

  static const Map<String, String> _categoryKeys = {
    // Blood pressure
    'Normal': 'bp_normal',
    'Elevated': 'bp_elevated',
    'High Stage 1': 'bp_high_1',
    'High Stage 2': 'bp_high_2',
    'Hypertensive Crisis': 'bp_crisis',
    'Low': 'bp_low',
    // Heart rate
    'Normal (60–100 bpm)': 'hr_normal',
    'Bradycardia (<60 bpm)': 'hr_brady',
    'Tachycardia (>100 bpm)': 'hr_tachy',
    // Oxygen
    'Normal (95–100%)': 'ox_normal',
    'Acceptable (90–94%)': 'ox_acceptable',
    'Low (<90%)': 'ox_low',
    // Diabetes
    'Fasting': 'dia_fasting',
    'Post-meal (2hr)': 'dia_post_meal',
    'Random': 'dia_random',
    'HbA1c': 'dia_hba1c',
    // Temperature — 'Normal' is shared with blood pressure and resolves to the
    // same word in both languages, so one entry covers both.
    'Low-grade Fever': 'temp_low_fever',
    'Moderate Fever': 'temp_moderate_fever',
    'High Fever': 'temp_high_fever',
    'Hypothermia': 'temp_hypothermia',
    // Weight
    'Morning Weight': 'wt_morning',
    'Evening Weight': 'wt_evening',
    'After Workout': 'wt_after_workout',
    'After Meal': 'wt_after_meal',
  };

  /// e.g. `blood_pressure` → "Blood Pressure" / "রক্তচাপ".
  static String type(String recordType) {
    final key = _typeKeys[recordType];
    if (key != null) return key.tr;
    return AppConstants.medicalRecordLabels[recordType] ?? recordType;
  }

  /// Placeholder text for the result field of a given record type.
  static String hint(String recordType) =>
      (_hintKeys[recordType] ?? 'record_hint_default').tr;

  /// A stored category as the current language spells it. Unknown values —
  /// including any a future version adds — pass through unchanged rather than
  /// showing a raw key.
  static String category(String storedCategory) {
    final key = _categoryKeys[storedCategory];
    return key == null ? storedCategory : key.tr;
  }

  /// Units (`mmHg`, `bpm`, `kg`) are internationally written the same way and
  /// stay as they are; this exists so callers have one place to go.
  static String unit(String recordType) =>
      AppConstants.medicalRecordUnits[recordType] ?? '';
}
