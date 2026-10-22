import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'core/bindings/initial_binding.dart';
import 'core/localization/app_locales.dart';
import 'core/localization/app_translations.dart';
import 'core/localization/twelve_hour_material_localizations.dart';
import 'core/services/alarm_sound_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_scheduler.dart';
import 'core/themes/app_theme.dart';

/// Upper bound on the OS font scale.
///
/// Android allows up to 2.0x. The dashboard's fixed-ratio cards and the list
/// row layouts overflow past this, so clamp rather than ship visibly broken
/// screens to the users most likely to enlarge their font.
const double _kMaxTextScale = 1.3;

class MediAssistApp extends StatefulWidget {
  const MediAssistApp({super.key});

  @override
  State<MediAssistApp> createState() => _MediAssistAppState();
}

class _MediAssistAppState extends State<MediAssistApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Resolve the documents directory before anything is scheduled: the
      // scheduler asks whether a custom alarm sound's file still exists, and
      // that check is synchronous.
      await AlarmSoundService.to.initialize();

      // Re-arm everything from storage. Cheap, idempotent, and the only thing
      // standing between a wiped OS alarm table and a missed dose.
      await ReminderScheduler.rescheduleAllFromStorage();

      // Handle a notification tap that launched the app from a killed state.
      await NotificationService.consumePendingRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    // The device may have changed timezone or crossed a DST boundary while the
    // app was backgrounded; anything already scheduled is pinned to the old
    // zone and has to be re-armed against the new one.
    await NotificationService.refreshTimeZone();
    await ReminderScheduler.rescheduleAllFromStorage();

    await NotificationService.consumePendingRoute();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // `onGenerateTitle`, not `title`: a plain `title: 'app_name'.tr` is
      // evaluated here, as a constructor argument, and GetX only registers the
      // translations and sets `Get.locale` in GetMaterialApp's own initState.
      // `.tr` returns the raw key when `Get.locale` is null, and this build
      // method is not re-run by `Get.updateLocale` — so the Android recents
      // label would read "app_name" for the life of the process. MaterialApp
      // calls this callback during its build instead, and again on rebuild.
      onGenerateTitle: (_) => 'app_name'.tr,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      initialBinding: InitialBinding(),

      // ── Language ────────────────────────────────────────────────────────
      // `locale` seeds the app from the persisted choice; `AppLocales.change`
      // swaps it later via Get.updateLocale, which rebuilds from here down so
      // every `.tr` re-resolves without a restart. `fallbackLocale` is English,
      // which is also what a user who has never chosen gets.
      translations: AppTranslations(),
      locale: AppLocales.initial.locale,
      fallbackLocale: AppLocales.fallback.locale,
      // Translates Flutter's own widgets too — the date and time pickers, the
      // text-selection menu — which `translations` above does not cover.
      localizationsDelegates: const [
        // Must precede GlobalMaterialLocalizations.delegate — only the first
        // delegate per type is loaded. It wraps that one to pin the time picker
        // to a 12-hour dial, which Bengali's own locale data does not do.
        TwelveHourMaterialLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocales.supportedLocales,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: _kMaxTextScale),
            // Ignore the device's "use 24-hour format" system setting. This
            // only asks each locale for *its* default, which is 12-hour in
            // English but 24-hour in Bengali — pinning the picker to 12-hour
            // everywhere is TwelveHourMaterialLocalizations' job, above. This
            // line still covers widgets that read the flag directly.
            alwaysUse24HourFormat: false,
          ),
          // Under edge-to-edge the navigation bar overlaps the bottom of every
          // screen. Inset once here rather than auditing each Scaffold; `top`
          // is left alone so the gradient headers still run under the status
          // bar as designed.
          child: SafeArea(
            top: false,
            child: child!,
          ),
        );
      },
    );
  }
}
