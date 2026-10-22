# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

This is a Flutter app (Android-only; iOS/desktop targets exist as scaffolding but are not supported).

```bash
flutter pub get                     # install dependencies
flutter analyze                     # lint (rules: analysis_options.yaml, package:flutter_lints)
flutter test                        # run all tests
flutter test test/widget_test.dart  # run a single test file
flutter run                         # run on a connected Android device/emulator
flutter build apk --release         # release APK
flutter build appbundle --release   # .aab — what Play requires
```

Requires Flutter >=3.22.0 / Dart >=3.3.0, Gradle 8.14, AGP 8.11.1, compileSdk 36 / targetSdk 35.

**JDK:** Gradle 8.14 rejects JDK 25, which is what Android Studio bundles. Point Flutter at a JDK 17–23 once per machine: `flutter config --jdk-dir="<path>"`. This is user-level config, deliberately not committed — do not reintroduce `org.gradle.java.home` into `android/gradle.properties`, since a machine-specific absolute path there breaks every other machine and CI.

**Release signing:** `android/app/build.gradle.kts` reads `android/key.properties` (git-ignored; see `key.properties.example`). If absent, release builds fall back to debug signing and print a warning — such an artifact cannot be uploaded to Play.

## Architecture

### GetX module pattern

Each feature lives under `lib/app/modules/<name>/` with `bindings/`, `controllers/`, `views/` (mirrors the standard GetX CLI layout). Routes are declared in `lib/app/routes/app_pages.dart` (+ `app_routes.dart`, a `part` file with the `Routes` name constants) — every screen has a `GetPage` there wiring page + binding + transition.

The prayer module is the one with several screens sharing one controller (times, calendar, location, calculation settings, reminders), so `PrayerBinding` uses `fenix: true`: they navigate between each other freely, and a plain `lazyPut` leaves a disposed controller behind as soon as the first of them is popped.

Global singleton services are registered once in `lib/core/bindings/initial_binding.dart` (`InitialBinding`, set as `GetMaterialApp.initialBinding` in `lib/app.dart`) as `permanent: true`: `StorageService`, `NotificationService`, `AlarmService`, `PermissionService`, `BackupService`, `PrayerService`, `DeviceLocationService`. Controllers reach them via the `ClassName.to` static getter (`Get.find()`), not constructor injection. `PrayerService` reads its saved state in `onInit`, so it must stay registered after `StorageService`.

Per the project's own contribution rules (see README): Obx widgets must read `.obs` values directly, and `ListView.builder`/`GridView.builder` must not be used inside `Obx` (lazy `itemBuilder` breaks GetX's dependency tracking) — use eager `.map().toList()` instead. New code is meant to use relative imports rather than `package:medi_assist/...`, though a fair amount of existing code (e.g. `lib/app/modules/**/controllers/*.dart`) still uses the package-style form — don't be surprised by the mix.

### Storage: two isolated GetStorage boxes

`StorageService` (`lib/core/services/storage_service.dart`) wraps two `GetStorage` boxes:
- the **default box** — medicines, meals, activities, medical records, prayer reminders, custom prayer entries; wiped by "Clear All Data"
- the **settings box** (`AppConstants.settingsBoxName`) — first-launch flag, service-enabled flag, permission-asked flag, snooze duration, theme, pending notification route, last-reschedule date, prayer location / calculation settings / module-enabled flag / slot count; never cleared

The prayer **location and calculation settings live in the settings box on purpose**: they are things the user configured once about where they are, and "Clear All Data" sending the prayer screen back to the fallback city with no explanation would read as a bug. The reminders themselves are data and go in the data box, and `BackupService` carries them (`prayerReminders` / `customPrayers`, both optional so pre-prayer-module backups still import).

Both boxes are initialized in `main()` before `runApp`. Any new persisted field needs a key added to `AppConstants` and a typed getter/setter added to `StorageService`, mirroring the existing get/save/add/update/delete pattern per model type.

### Reminder scheduling

`ReminderScheduler` (`lib/core/services/reminder_scheduler.dart`) is the single entry point the UI/controllers call to schedule or cancel a medicine/meal/activity. Based on the item's `notificationType` (`notification` / `alarm` / `both` / `none`, see `AppConstants`) it fans out to `NotificationService` (daily exact `flutter_local_notifications`) and/or `AlarmService` (the `alarm` package, full-screen + sound). All schedule methods cancel-then-reschedule, so every call is idempotent.

Notification/alarm IDs are derived deterministically from each entity's string `id` via `id.hashCode.abs() % N` offset from per-module base constants in `AppConstants`. **The ID helpers at the bottom of `ReminderScheduler` are the only place this arithmetic may live.** A second copy elsewhere produces a different ID for the same entity and shows up as duplicate notifications rather than an error — that was a real bug. Medicine slot `i` uses `base + i` with bases spaced 10 apart, hence `ReminderScheduler.maxMedicineTimes`.

Prayer is the exception to the hashing: its IDs are indexed by **slot**, the reminder's position in the stored list at the moment it was scheduled, because hashed IDs would collide between two reminders with no per-entity spacing to hash into. `StorageService.prayerSlotCount` records how many slots the last run used, and scheduling cancels exactly that many before re-arming — which is how a *deleted* reminder stops firing without sweeping the whole 2000-ID range.

There is **no polling or foreground service**. Delivery rests entirely on OS-level exact alarms:

- `zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time)` repeats notifications daily and survives reboot via `ScheduledNotificationBootReceiver`. This is entirely native — it needs no Flutter engine.
- The `alarm` package has **no repeat mode**: each `Alarm.set` arms exactly one firing. The daily repeat comes from `DailyAlarmRearmReceiver` (see below), not from the plugin.
- `ReminderScheduler.rescheduleAllFromStorage()` runs on launch and on every resume (`app.dart`) as the safety net that re-arms anything the OS dropped.

#### Native alarm re-arm (`android/app/src/main/kotlin/com/mediassist/app/`)

Anything that keeps alarm-type reminders repeating has to work with **no Dart running at all** — the app being closed is the normal case, not the edge case. `Alarm.ringing` in `main.dart` is only a fast path for when the app happens to be open; never make it the only thing that re-arms an alarm.

- `AlarmService.scheduleAlarm` mirrors each alarm into `DailyAlarmStore` (plain SharedPreferences, over the `com.mediassist.app/daily_alarms` MethodChannel in `MainActivity.kt`) as an **hour + minute**, not an instant — which is also why reminders follow the device across timezone and DST changes for free.
- `DailyAlarmRearmReceiver` keeps a self-perpetuating AlarmManager "sweep" armed for 2 minutes after the earliest upcoming reminder. Each firing rolls every stored alarm to its next occurrence and schedules the next sweep. **Do not shorten that 2-minute lag**: re-arming before the alarm fires moves that firing to tomorrow and the user never hears it.
- The store is deliberately separate from the plugin's own: the plugin deletes an alarm as soon as it is stopped (including from the notification's Stop button), so it cannot say what tomorrow should look like. The sweep is also what repairs `Alarm.stop()` cancelling the next day's schedule along with the current ring.
- The same receiver handles `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`, and the plugin's own `BootReceiver` is removed with `tools:node="remove"` in the manifest — it re-armed alarms at their stale past `dateTime`, which `AlarmApiImpl` treats as "fire now", so every reminder rang at once on reboot. Don't restore it.
- Any new path that cancels alarms must clear the mirror too (`AlarmService.cancelAlarm` / `clearDailySpecs`), or the sweep resurrects them the next day.
- `DatedAlarmStore` is the second native store, for alarms that fire at a **list of instants** instead of daily at a fixed clock time — prayer reminders, which move a minute or two every day. Dart pushes a 45-day horizon of timestamps (`AlarmService.scheduleDatedAlarm` → `saveDated`) and the same sweep arms only the next one, so a long horizon still costs one OS alarm per reminder. Reproducing the astronomical maths in Kotlin was the alternative and would have meant two implementations drifting apart. `MainActivity`'s `remove` and `clear` clear both stores.

### Alarm sounds

`AlarmSound` (`lib/models/alarm_sound_model.dart`) is one of three things: the bundled tone, the device's default alarm (which the plugin picks when `assetAudioPath` is **null** — null is meaningful there, not missing), or a ringtone/audio file the user imported. Each reminder model carries a nullable `alarmSound`, where `null` means "follow the app-wide default" in the settings box. `AlarmSoundService.resolve`/`resolvedAudioPath` is the only place that fallback is applied, so it means the same thing on every screen and in the scheduler.

**An imported sound is copied into the app's documents directory** and stored as a path relative to it (`alarm_sounds/<id>.<ext>`). Not an optimisation — three things break otherwise: a `content://` ringtone URI is not reliably playable by `MediaPlayer.setDataSource(String)`, which is what the plugin calls; `DailyAlarmRearmReceiver` replays that same path days later with no Flutter engine and no URI grant; and the user can delete the original. It is also what keeps `READ_EXTERNAL_STORAGE` strippable in the manifest. If a custom sound's file has gone anyway, `resolvedAudioPath` falls back to the bundled tone — a silent alarm is the worst failure this app has, so nothing may resolve to nothing.

The ringtone picker, the `content://` copy and the preview player are native (`SoundChannel.kt`, `com.mediassist.app/sound`), because all three need a `Context`. Note that a **backup carries the sound choice but not the audio file**, so importing on another device lands on that same fallback.

Custom sounds apply to **alarm-type** reminders. A notification's sound is a property of its Android channel, so it cannot vary per notification; the picker says so rather than pretending otherwise.

### Prayer times

`lib/core/prayer/` is a self-contained port of the Adhan algorithm (Meeus solar position → `SolarTime` → `PrayerTimes`), deliberately **not a package dependency**: it is pure Dart with no Flutter, storage or locale, so `test/prayer_times_test.dart` can pin it against published timetables. The Raleigh 2015-07-12 case in that file is the reference suite's own; if a change moves it, the change is wrong.

`PrayerService` is the only thing that converts between the location's wall clock and a UTC instant. Everything the engine returns is a **UTC instant**: reminders are scheduled from those (so they are right whichever zone the phone is in), and the screens render `wallClock(...)` (so someone in London checking Makkah sees Makkah's clock). `PrayerLocation.utcOffsetMinutes` is `null` for "follow the device", which is both the common case and what handles daylight saving for free; it is only pinned when the chosen place is more than an hour off the device.

A prayer time can be `null` — polar day and night are real, and the UI shows a dash rather than inventing one. The high-latitude rules cover the ordinary cases below that.

A prayer reminder fires either at an offset from its prayer (the default, which tracks the sun through the year) or at a fixed clock time (`PrayerReminder.exactTime`), for a personal routine or a mosque whose jamaat runs to the clock. An exact time is read on the **location's** wall clock via `PrayerService.instantFromWallClock`, not the phone's, and needs no prayer time at all — which is why the scheduler checks that branch before looking one up.

Location comes from a **bundled catalogue** (`lib/core/data/location_catalog.dart`), never a geocoding API: prayer times have to work on a phone that has been offline for a month, and reverse-geocoding would ship the user's coordinates to a third party for nothing they asked for. GPS is one fix through the app's own `com.mediassist.app/location` channel over `LocationManager` — foreground only, no tracking, no plugin. A fix keeps its exact coordinate and borrows only the *name* of the nearest catalogue entry, and `nearest()` returns `null` past 150 km rather than mislabelling someone.

Four prayer notification channels exist because from Android 8 sound and vibration are fixed per channel, so "silent but vibrating" cannot be expressed on one — `AppConstants.prayerChannelFor` picks.

`notification_icon` is kept alive in release builds by `res/raw/keep.xml`; it is only ever referenced by name, so `shrinkResources` would otherwise be free to strip it.

Timezone is load-bearing: `NotificationService._setLocalTimeZone()` must run before any scheduling, or `tz.local` stays UTC and every reminder fires at the wrong wall-clock time. `refreshTimeZone()` is called on resume to handle travel and DST.

The `alarm` package's ringing stream is subscribed to at the top level in `main.dart`; it re-arms the fired alarm +24h and shows `showAlarmRingingDialog`. Snoozes deliberately use a **separate ID range** (`AppConstants.snoozeIdFor`) — reusing the alarm's own ID overwrites the next day's schedule and walks the daily reminder later on every snooze. The dialog offers both the fixed snooze from Settings and "Snooze until…", which picks a clock time; both go through `_snoozeUntil`, and both carry the fired alarm's own `assetAudioPath` across rather than re-resolving it, so a snooze always sounds like the alarm it came from.

### Models

`lib/models/*.dart` (`Medicine`, `Meal`, `Activity`, `MedicalRecord`, `PrayerReminder`, `CustomPrayerEvent`, plus `PrayerLocation` and `PrayerSettings` for the settings box) are plain Dart classes with `toJson`/`fromJson`/`copyWith`, serialized as `List<Map>` into the GetStorage data box — there is no database/ORM layer.

### UI constraints that are easy to regress

- The app renders **edge-to-edge** (forced by targetSdk 35 on Android 15+). `app.dart`'s `builder` applies one bottom `SafeArea` above the navigator — don't add per-screen bottom insets on top of it.
- The same `builder` clamps `textScaler` to 1.3×. The dashboard grid sizes its cells from the text scale rather than a fixed `childAspectRatio`, because a ratio-based cell clips its own content at large system font sizes.
- Notification icons must be white-on-transparent silhouettes (`@drawable/notification_icon`). Pointing `AndroidInitializationSettings` at `@mipmap/ic_launcher` renders a grey blob in the status bar.

### Localization (English / বাংলা)

`lib/core/localization/` holds the whole language system. `AppTranslations` (GetX `Translations`) carries one map per language keyed `en_US` / `bn_BD`; `AppLocales` is the catalogue of supported languages and the only place that switches one. Adding a language means an entry in `AppLocales.supported`, a matching map in `AppTranslations`, and its tag in `resourceConfigurations` in `android/app/build.gradle.kts` — nothing else.

- **Every user-facing string goes through `.tr`** (or `.trParams` when it interpolates a value — never string interpolation, because word order differs between the languages). `test/localization_test.dart` enforces that the two maps hold identical key sets, no blank values, and matching `@placeholder` sets; it fails the build rather than letting a missing key ship as a raw `medicine_add` on a button.
- **A `Text` showing a `.tr` string cannot be `const`** — it would keep whichever language it was first built in. Move the `const` onto the `TextStyle` instead.
- `AppLocales.change()` persists the choice (settings box, so "Clear All Data" leaves it alone) and calls `Get.updateLocale`, which rebuilds everything — no restart.
- **GetX registers translations and sets `Get.locale` inside `GetMaterialApp`'s `initState`, and until it does `.tr` silently returns the raw key.** That is later than it sounds, and it bites in three places, all already handled — don't undo them:
  - `main()` seeds `Get.addTranslations` / `Get.locale` / `Get.fallbackLocale` itself, before `NotificationService.initialize()` creates the notification channels. Without it those channels are named `channel_medicine_name` in Android's settings.
  - `AppLocales.initial` reads the settings box **directly rather than via `StorageService`** — it is a `GetMaterialApp` constructor argument, and `initialBinding.dependencies()` runs in that same late `initState`, so `StorageService.to` would throw on every cold start.
  - The window title uses `onGenerateTitle`, not `title`. A `title:` argument is evaluated in `_MediAssistAppState.build()`, which `Get.updateLocale` does not re-run.
- Three things live outside the widget tree and do **not** repaint themselves on a language switch, so `SettingsController.changeLanguage` handles them explicitly: the Android notification channels (`NotificationService.refreshChannels()` — Android updates an existing channel's name and description in place), every already-scheduled reminder, and the native alarm mirror. Forgetting these leaves the user's actual reminders in the old language indefinitely.
- Bangla is not just different words: `TimeUtils` names the part of the day and puts it *before* the clock ("সকাল ৮:০০"), and `localizedDigits` renders displayed numbers in Bengali digits. Anything the **user typed** — measurement values, search terms — and anything parsed back into a number is left in ASCII.
- Medical-record types and categories stay English in `AppConstants` because those values are **stored**, and a backup taken in Bangla has to import in English. `MedicalLabels` maps the stored string to its display name. The prayer enums work the same way: `PrayerKind`, `Madhab`, `HighLatitudeRule`, `CalculationMethod` and `PrayerLocationSource` each carry a stable `id` that is what gets persisted, with `nameKey` (`prayer_fajr`, `calc_method_karachi`, …) for display. Those keys are built from the id rather than written as literals, so `test/localization_test.dart` walks the enums to prove each one has a translation.

### Constants

`lib/core/constants/app_constants.dart` centralizes storage keys, notification channel IDs, notification/alarm ID base ranges, notification-type strings, and medical-record type/category/unit/icon lookup tables. `lib/core/constants/app_colors.dart` holds the light/dark color system. Prefer extending these tables over hardcoding new literals in views/controllers.
