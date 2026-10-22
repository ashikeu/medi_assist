part of 'app_pages.dart';

abstract class Routes {
  Routes._();

  static const home = '/home';
  static const medicine = '/medicine';
  static const addEditMedicine = '/medicine/add-edit';
  static const meal = '/meal';
  static const addEditMeal = '/meal/add-edit';
  static const medicalRecords = '/medical-records';
  static const medicalRecordDetail = '/medical-records/detail';
  static const addEditMedicalRecord = '/medical-records/add-edit';
  static const activity = '/activity';
  static const addEditActivity = '/activity/add-edit';
  static const prayer = '/prayer';
  static const prayerCalendar = '/prayer/calendar';
  static const prayerLocation = '/prayer/location';
  static const prayerSettings = '/prayer/settings';
  static const prayerReminders = '/prayer/reminders';
  static const addEditPrayerReminder = '/prayer/reminders/add-edit';
  static const addEditCustomPrayer = '/prayer/custom/add-edit';
  static const settings = '/settings';
  static const splash = '/splash';
}