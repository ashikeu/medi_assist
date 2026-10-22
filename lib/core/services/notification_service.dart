import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../constants/app_constants.dart';

// ─── Pending notification route key (for background taps) ────────────────────
const String _kPendingRouteKey = 'pending_notification_route';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Whether the notification that launched this process has been routed yet.
  static bool _launchRouteConsumed = false;

  // ─── Initialize ──────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await _setLocalTimeZone();

    // Must be a white-on-transparent silhouette. A full-colour launcher icon
    // renders as a grey blob in the Android status bar.
    const androidInit =
        AndroidInitializationSettings('@drawable/notification_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      // ✅ Foreground tap — app is open
      onDidReceiveNotificationResponse: _onNotificationTap,
      // ✅ Background tap — app was killed, runs in separate isolate
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    if (Platform.isAndroid) {
      await _createChannels();
    }
  }

  // ─── Timezone ────────────────────────────────────────────────────────────────
  /// Points `tz.local` at the device's actual zone.
  ///
  /// Without this `tz.local` stays UTC, and every `zonedSchedule` call fires at
  /// the UTC instant of the wall-clock time the user picked — e.g. an 08:00
  /// reminder arrives at 14:00 in UTC+6.
  static Future<void> _setLocalTimeZone() async {
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('🌍 Local timezone set: $name');
    } catch (e) {
      debugPrint('⚠️ Could not resolve local timezone, falling back to device '
          'offset: $e');
      _setLocalTimeZoneFromOffset();
    }
  }

  /// Fallback for devices where the IANA zone name is unavailable or unknown to
  /// the timezone database. Picks any location matching the current UTC offset
  /// so reminders land on the right wall-clock time even without a zone name.
  static void _setLocalTimeZoneFromOffset() {
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final now = tz.TZDateTime.now(location);
      if (now.timeZoneOffset == offset) {
        tz.setLocalLocation(location);
        debugPrint('🌍 Local timezone approximated as ${location.name}');
        return;
      }
    }
  }

  /// Re-resolves the device timezone and re-arms everything that was scheduled
  /// against the old zone. Call when the app resumes — covers the user
  /// travelling across zones or a DST transition while the app was closed.
  static Future<bool> refreshTimeZone() async {
    final previous = tz.local.name;
    await _setLocalTimeZone();
    return tz.local.name != previous;
  }

  // ─── Notification tap handler (foreground — app is open) ──────────────────
  @pragma('vm:entry-point')
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    _handleNotificationNavigation(response.payload);
  }

  // ─── Background notification tap (app was killed) ─────────────────────────
  // Runs in a background isolate — cannot use GetX here
  // Save the route to storage, pick it up when app opens
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    debugPrint(
        '🔔 Background notification tapped: ${response.payload}');
    try {
      // Save pending route to storage — will be consumed on next app open
      final box = GetStorage();
      final route = _payloadToRoute(response.payload);
      if (route != null) {
        box.write(_kPendingRouteKey, route);
        debugPrint('📌 Pending route saved: $route');
      }
    } catch (e) {
      debugPrint('❌ Error saving pending route: $e');
    }
  }

  // ─── Navigate based on payload ────────────────────────────────────────────
  static void _handleNotificationNavigation(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final route = _payloadToRoute(payload);
    if (route != null) {
      // Small delay to ensure GetMaterialApp is ready
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.toNamed(route);
      });
    }
  }

  // ─── Convert payload to route string ─────────────────────────────────────
  static String? _payloadToRoute(String? payload) {
    if (payload == null) return null;
    if (payload.startsWith('medicine_')) return '/medicine';
    if (payload.startsWith('meal_')) return '/meal';
    if (payload.startsWith('activity_')) return '/activity';
    if (payload.startsWith('medical_')) return '/medical-records';
    if (payload.startsWith('prayer_')) return '/prayer';
    return null;
  }

  // ─── Check & consume pending route (call this on app start) ──────────────
  /// Routes a notification tap that happened while the app was not running.
  ///
  /// Two sources, because they cover different taps:
  ///  * `getNotificationAppLaunchDetails()` — the app was launched *by* the
  ///    tap. This is the ordinary case: tapping the body of a reminder while
  ///    the app is closed. The background-isolate handler below never sees it.
  ///  * the pending-route box — written by `_onBackgroundNotificationTap`,
  ///    which only fires for notification *action buttons*.
  static Future<void> consumePendingRoute() async {
    String? route;

    // Launch details describe how this *process* started and keep saying so
    // for its whole life, so consult them once — otherwise every resume would
    // re-navigate to the screen the launching tap asked for.
    if (!_launchRouteConsumed) {
      _launchRouteConsumed = true;
      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp ?? false) {
          route = _payloadToRoute(launchDetails!.notificationResponse?.payload);
          if (route != null) {
            debugPrint('📌 App launched from notification → $route');
          }
        }
      } catch (e) {
        debugPrint('❌ Error reading notification launch details: $e');
      }
    }

    try {
      final box = GetStorage();
      final stored = box.read<String>(_kPendingRouteKey);
      if (stored != null && stored.isNotEmpty) {
        box.remove(_kPendingRouteKey);
        route ??= stored;
        debugPrint('📌 Consuming pending route: $stored');
      }
    } catch (e) {
      debugPrint('❌ Error consuming pending route: $e');
    }

    if (route == null) return;
    // Give GetMaterialApp time to install its navigator before pushing.
    await Future.delayed(const Duration(milliseconds: 800));
    Get.toNamed(route);
  }

  // ─── Create notification channels (Android) ───────────────────────────────
  /// Re-applies the channel definitions in the current language.
  ///
  /// Safe to call repeatedly: Android matches on channel ID and refreshes an
  /// existing channel's name and description in place rather than creating a
  /// duplicate. That is what lets the channel list in Android's own settings
  /// follow a language change — the channels themselves are created once, by
  /// `initialize()`, which `main()` calls after seeding `Get.locale`.
  static Future<void> refreshChannels() async {
    if (!Platform.isAndroid) return;
    await _createChannels();
  }

  static Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.medicineChannelId,
        'channel_medicine_name'.tr,
        description: 'channel_medicine_desc'.tr,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF6366F1),
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.mealChannelId,
        'channel_meal_name'.tr,
        description: 'channel_meal_desc'.tr,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFEC4899),
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.activityChannelId,
        'channel_activity_name'.tr,
        description: 'channel_activity_desc'.tr,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFF59E0B),
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.medicalChannelId,
        'channel_medical_name'.tr,
        description: 'channel_medical_desc'.tr,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // ── Prayer ──────────────────────────────────────────────────────────────
    // One channel per sound/vibration combination: from Android 8 both are
    // properties of the channel and cannot be overridden per notification, so
    // a reminder configured as "vibrate, no sound" needs a channel that is
    // itself silent and vibrating. See AppConstants.prayerChannelFor.
    for (final variant in const [
      (
        AppConstants.prayerChannelId,
        'channel_prayer_name',
        'channel_prayer_desc',
        true,
        true,
      ),
      (
        AppConstants.prayerSoundOnlyChannelId,
        'channel_prayer_sound_name',
        'channel_prayer_sound_desc',
        true,
        false,
      ),
      (
        AppConstants.prayerVibrateOnlyChannelId,
        'channel_prayer_vibrate_name',
        'channel_prayer_vibrate_desc',
        false,
        true,
      ),
      (
        AppConstants.prayerSilentChannelId,
        'channel_prayer_silent_name',
        'channel_prayer_silent_desc',
        false,
        false,
      ),
    ]) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          variant.$1,
          variant.$2.tr,
          description: variant.$3.tr,
          // A silent channel still belongs at max importance: the user asked
          // for no sound, not for the reminder to be collapsed away.
          importance: Importance.max,
          playSound: variant.$4,
          enableVibration: variant.$5,
          enableLights: true,
          ledColor: const Color(0xFF0EA5E9),
        ),
      );
    }

    // Low importance — foreground service persistent notification
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.foregroundChannelId,
        'channel_service_name'.tr,
        description: 'channel_service_desc'.tr,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  // ─── Schedule daily repeating notification ────────────────────────────────
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        // ✅ Shows full content in notification shade
        styleInformation: BigTextStyleInformation(body),
        category: AndroidNotificationCategory.reminder,
        // ✅ Shows on lock screen
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        // ✅ Shows notification even when DND is active
        fullScreenIntent: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        // ✅ exactAllowWhileIdle — fires even when device is in Doze mode
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ✅ Repeats daily at same time
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      debugPrint(
          '✅ Notification scheduled: id=$id at $hour:$minute (payload: $payload)');
    } catch (e) {
      debugPrint('❌ Failed to schedule notification id=$id: $e');
    }
  }

  // ─── Schedule a one-off notification at an exact instant ──────────────────
  /// Schedules a single firing at [when], which is a device-local time.
  ///
  /// Unlike [scheduleDailyNotification] this passes no
  /// `matchDateTimeComponents`, so it fires once and is gone. That is what
  /// prayer reminders need: the times move by a minute or two every day, so
  /// "repeat daily at this clock time" would be wrong by the end of the week.
  /// The schedule is instead refilled a horizon at a time — see
  /// `ReminderScheduler.schedulePrayerReminders`.
  ///
  /// A [when] in the past is skipped rather than fired immediately.
  Future<bool> scheduleOneShotNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    try {
      final scheduledDate = tz.TZDateTime.from(when, tz.local);
      if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) return false;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule one-shot notification id=$id: $e');
      return false;
    }
  }

  // ─── Show immediate notification ─────────────────────────────────────────
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        visibility: NotificationVisibility.public,
        autoCancel: true,
      );

      const iosDetails =
          DarwinNotificationDetails(presentAlert: true, presentSound: true);

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Failed to show immediate notification id=$id: $e');
    }
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Medicine notifications ───────────────────────────────────────────────
  Future<void> scheduleMedicineNotifications({
    required String medicineId,
    required String medicineName,
    required List<TimeOfDay> times,
    required int baseId,
  }) async {
    await cancelMedicineNotifications(
        medicineId: medicineId, times: times, baseId: baseId);

    for (int i = 0; i < times.length; i++) {
      await scheduleDailyNotification(
        id: baseId + i,
        title: '💊 ${'notif_medicine_title'.tr}',
        body: 'alarm_medicine_body'.trParams({'name': medicineName}),
        hour: times[i].hour,
        minute: times[i].minute,
        channelId: AppConstants.medicineChannelId,
        channelName: AppConstants.medicineChannelName,
        payload: 'medicine_$medicineId',
      );
    }
  }

  Future<void> cancelMedicineNotifications({
    required String medicineId,
    required List<TimeOfDay> times,
    required int baseId,
  }) async {
    for (int i = 0; i < times.length; i++) {
      await cancelNotification(baseId + i);
    }
  }

  // ─── Meal notifications ───────────────────────────────────────────────────
  Future<void> scheduleMealNotification({
    required String mealId,
    required String mealName,
    required TimeOfDay time,
    required int notifId,
  }) async {
    await cancelNotification(notifId);
    await scheduleDailyNotification(
      id: notifId,
      title: '🍽️ ${'notif_meal_title'.tr}',
      body: 'alarm_time_for'.trParams({'name': mealName}),
      hour: time.hour,
      minute: time.minute,
      channelId: AppConstants.mealChannelId,
      channelName: AppConstants.mealChannelName,
      payload: 'meal_$mealId',
    );
  }

  // ─── Activity notifications ───────────────────────────────────────────────
  Future<void> scheduleActivityNotification({
    required String activityId,
    required String activityName,
    required TimeOfDay time,
    required int notifId,
  }) async {
    await cancelNotification(notifId);
    await scheduleDailyNotification(
      id: notifId,
      title: '🏃 ${'notif_activity_title'.tr}',
      body: 'alarm_time_for'.trParams({'name': activityName}),
      hour: time.hour,
      minute: time.minute,
      channelId: AppConstants.activityChannelId,
      channelName: AppConstants.activityChannelName,
      payload: 'activity_$activityId',
    );
  }

  // ─── Exact alarm permission (Android 12+) ─────────────────────────────────
  /// False means the OS will silently downgrade exact schedules to inexact
  /// ones, which can delay a reminder by minutes to hours.
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  // ─── Request permission ───────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  // ─── Get pending notifications ────────────────────────────────────────────
  Future<List<PendingNotificationRequest>> getPending() async {
    return await _plugin.pendingNotificationRequests();
  }
}