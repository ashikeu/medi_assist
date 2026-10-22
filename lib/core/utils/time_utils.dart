import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../localization/app_locales.dart';
import '../localization/localized_digits.dart';

class TimeUtils {
  TimeUtils._();

  /// Format TimeOfDay to "08:00 AM", or "সকাল ৮:০০" in Bangla.
  static String formatTimeOfDay(TimeOfDay time) =>
      _formatClock(time.hour, time.minute);

  /// Format DateTime to "08:00 AM", or "সকাল ৮:০০" in Bangla.
  static String formatDateTime(DateTime dt) => _formatClock(dt.hour, dt.minute);

  /// Bangla does not use AM/PM — it names the part of the day and puts that
  /// name *before* the clock time, so the two languages need different
  /// assembly, not just different words.
  static String _formatClock(int hour24, int minute) {
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minutes = minute.toString().padLeft(2, '0');

    if (!AppLocales.isBangla) {
      final period = hour24 >= 12 ? 'time_pm'.tr : 'time_am'.tr;
      return '$hour12:$minutes $period';
    }

    final clock = '$hour12:$minutes'.localizedDigits;
    return '${_banglaDayPart(hour24)} $clock';
  }

  static String _banglaDayPart(int hour24) {
    if (hour24 >= 4 && hour24 < 6) return 'time_period_dawn'.tr;
    if (hour24 >= 6 && hour24 < 12) return 'time_period_morning'.tr;
    if (hour24 >= 12 && hour24 < 16) return 'time_period_noon'.tr;
    if (hour24 >= 16 && hour24 < 18) return 'time_period_afternoon'.tr;
    if (hour24 >= 18 && hour24 < 20) return 'time_period_evening'.tr;
    return 'time_period_night'.tr;
  }

  /// Format DateTime to "12 Jan 2025" — day/month/year order is shared by both
  /// languages, so only the month name and the digits change.
  static String formatDate(DateTime dt) {
    final month = 'month_short_${dt.month}'.tr;
    return '${dt.day.localizedDigits} $month ${dt.year.localizedDigits}';
  }

  /// Format DateTime to full: "12 Jan 2025 • 08:00 AM"
  static String formatFull(DateTime dt) {
    return '${formatDate(dt)} • ${formatDateTime(dt)}';
  }

  /// Get next occurrence of a TimeOfDay from now
  /// If the time has already passed today, returns tomorrow
  static DateTime nextOccurrence(TimeOfDay time) {
    final now = DateTime.now();
    DateTime scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now) ||
        scheduled.difference(now).inSeconds < 5) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Convert TimeOfDay to minutes since midnight for comparison
  static int toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Check if current time matches a TimeOfDay (within same minute)
  static bool isNow(TimeOfDay time) {
    final now = TimeOfDay.now();
    return now.hour == time.hour && now.minute == time.minute;
  }

  /// Get greeting based on current time
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'greeting_morning'.tr;
    if (hour < 17) return 'greeting_afternoon'.tr;
    if (hour < 21) return 'greeting_evening'.tr;
    return 'greeting_night'.tr;
  }

  /// Format duration as "2h 30m"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final m = '${minutes.localizedDigits}${'unit_minute_short'.tr}';
    if (hours > 0) {
      return '${hours.localizedDigits}${'unit_hour_short'.tr} $m';
    }
    return m;
  }
}
