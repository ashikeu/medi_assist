# Production-readiness fixes

Audit and remediation pass over MediAssist covering reminder delivery, backup
integrity, Play Store eligibility, and UI robustness.

Every item below states the **symptom the user would have experienced**, the
**root cause**, and the **fix**. Verification status is at the bottom.

---

## 1. Notifications fired at the wrong time for every user outside UTC

**Severity:** Critical — the core function of the app was broken worldwide.

**Symptom.** A medicine reminder set for 08:00 arrived at 14:00 in Bangladesh
(UTC+6), at 03:00 in New York, and at 08:00 only in the UK in winter. Alarms
were unaffected, so `notification`-type reminders were wrong while
`alarm`-type ones were right — which would have looked random and unreproducible.

**Cause.** `notification_service.dart` scheduled with `tz.TZDateTime(tz.local, …)`,
but `tz.setLocalLocation()` was never called anywhere in the project. Only
`tzdata.initializeTimeZones()` was called, which loads the zone *database* but
does not select a zone. `tz.local` therefore stayed at its default of **UTC**,
and `zonedSchedule` interpreted every user-picked wall-clock time as a UTC
instant.

**Fix.**
- Added the `flutter_timezone` dependency.
- `NotificationService._setLocalTimeZone()` resolves the device's IANA zone
  identifier and calls `tz.setLocalLocation()`. It runs inside `initialize()`,
  before anything can be scheduled.
- Added `_setLocalTimeZoneFromOffset()` as a fallback for devices that report a
  zone name the database does not know: it picks any location matching the
  current UTC offset, so the wall-clock time is still correct.
- Added `NotificationService.refreshTimeZone()`, called on app resume, so a user
  who travels across zones or crosses a DST boundary while the app is closed has
  their reminders re-armed against the new zone rather than the old one.

**Files:** `lib/core/services/notification_service.dart`, `lib/app.dart`,
`pubspec.yaml`

---

## 2. Every notification-type reminder fired twice

**Severity:** Critical.

**Symptom.** Two identical "💊 Medicine Reminder" notifications for a single
medicine at a single time.

**Cause.** Two independent code paths delivered the same reminder with
**different notification IDs**, so Android treated them as two separate
notifications instead of one replacing the other:

| Path | ID formula |
|---|---|
| `ReminderScheduler` (`zonedSchedule`) | `medicineNotifBase + (hash % 100) * 10 + i` |
| `MediAssistTaskHandler` 60s poll | `medicineNotifBase + hash % 1000` |

The background isolate could not call into `ReminderScheduler` (no GetX in a
foreground-task isolate), so the arithmetic had been copy-pasted and had since
drifted. The poll also fired unconditionally whenever the clock matched, with no
check for whether the scheduled notification had already been delivered.

**Fix.** The polling service was removed entirely (see item 7), eliminating the
duplicate path. The ID helpers at the bottom of `ReminderScheduler` are now the
only copy of this arithmetic, and are documented as such in `CLAUDE.md` and the
README contribution rules.

**Files:** `lib/core/services/reminder_scheduler.dart`,
`lib/core/services/foreground_service.dart` *(deleted)*

---

## 3. Snoozing walked the daily alarm permanently later

**Severity:** Critical — silently drifting medication times.

**Symptom.** Snooze an 08:00 alarm by 10 minutes and from the next day it rang at
08:10. Snooze again and it became 08:20. The drift was permanent and cumulative,
and nothing in the UI showed the reminder time had changed.

**Cause.** In `main.dart`:
1. When an alarm rang, `_rescheduleAlarmForNextDay()` re-armed **the same alarm
   ID** for +24h.
2. Tapping Snooze then called `Alarm.set` with **that same ID** for `now + N`,
   overwriting the next-day schedule that had just been created.
3. When the snooze fired, step 1 ran again — now computing +24h from the
   *snooze* time.

**Fix.**
- Added a dedicated snooze ID range (9000–9999) with
  `AppConstants.snoozeIdFor(alarmId)` and `AppConstants.isSnoozeId(id)`. A snooze
  is now a distinct alarm, so it cannot overwrite the daily one.
- `_rescheduleAlarmForNextDay()` returns early for snooze IDs — a snooze is a
  one-off and must not roll forward.
- The mapping is stable, so re-snoozing replaces the pending snooze rather than
  stacking a second one.
- Also hardened the roll-forward: if the device was off and the alarm fired late,
  it now advances in day steps until the target is in the future, instead of
  silently skipping the reschedule.

**Files:** `lib/core/constants/app_constants.dart`, `lib/main.dart`,
`lib/core/widgets/alarm_ringing_dialog.dart`

---

## 4. "Clear All Data" left alarms ringing forever

**Severity:** Critical — unrecoverable without reinstalling.

**Symptom.** After Settings → Clear All Data, deleted medicines kept ringing
full-volume alarms daily. Because the medicine records were gone, no screen in
the app could cancel them. The only escape was reinstalling.

**Cause.** `SettingsController.clearAllData()` called
`NotificationService.cancelAll()` — which cancels notifications only — and then
wiped storage. Nothing ever called `Alarm.stop`, and the `alarm` package persists
its schedule independently of the app's own storage, including across reboots.

**Fix.** Added `ReminderScheduler.cancelEverything()`, which cancels all
notifications **and** iterates `Alarm.getAlarms()` stopping each one. Clear-data
now calls it before wiping storage. The same method is reused by the import flow.

**Files:** `lib/core/services/reminder_scheduler.dart`,
`lib/app/modules/settings/controllers/settings_controller.dart`

---

## 5. Importing a backup silently disabled every reminder

**Severity:** Critical — the restore path looked successful while leaving the
user with no working reminders at all.

**Symptom.** After importing, the medicine list looked right but nothing ever
reminded the user. Meanwhile alarms for medicines that had been *replaced* kept
firing. The UI also showed stale data until the app was restarted — the success
message literally said "Please restart the app."

**Cause.** `BackupService._restoreData()` wrote the new lists to storage and
stopped there. It did not cancel the outgoing data's reminders, did not schedule
the incoming data's reminders, and did not refresh the in-memory GetX
controllers.

**Fix.** `_restore()` now performs the full sequence:
1. Snapshot current data for rollback.
2. `ReminderScheduler.cancelEverything()` — clears the outgoing reminders.
3. Write the restored data.
4. On any write failure, roll back to the snapshot and re-arm its reminders, so
   a partial restore cannot leave the user with neither their old data nor the
   backup.
5. `ReminderScheduler.rescheduleAllFromStorage()` — arms the imported reminders.
6. `SettingsController._reloadLiveControllers()` refreshes whichever list
   controllers are alive, so the UI updates in place. The "restart the app"
   message is gone.

Also hardened parsing: the whole file is parsed and validated **before** any
existing data is touched, so a corrupt backup is rejected without data loss.

**Files:** `lib/core/services/backup_service.dart`,
`lib/app/modules/settings/controllers/settings_controller.dart`

---

## 6. Export reported failure on success

**Severity:** High — users would assume their backup had not been saved.

**Symptom.** "Failed to export backup" appeared after every export, including
successful ones.

**Cause.** `exportData()` returned `result.status == ShareResultStatus.success`.
On Android the system share sheet does not report which app received the file, so
`share_plus` returns `ShareResultStatus.unavailable` on success. The comparison
was therefore false almost always.

A second latent bug: the temp file was `delete()`d immediately after the share
sheet closed, while the receiving app may still be reading it — producing
truncated or empty backups.

**Fix.**
- Replaced the boolean return with a `BackupResult { success, cancelled, failed }`
  enum, so "user cancelled" is no longer reported as an error either.
- Only `ShareResultStatus.dismissed` is treated as cancellation; anything else is
  success. The file is written to disk regardless.
- Backups are written to a dedicated `backups/` subdirectory, and the **previous**
  export is cleaned up at the start of the *next* export rather than immediately
  after sharing.
- File picker widened from `FileType.custom(['json'])` to `FileType.any`, because
  some Android providers report `.json` as `application/octet-stream` and the
  filter was hiding users' own backup files.
- The import confirmation dialog now shows the actual counts in the backup
  (medicines / meals / activities / records) so the user can sanity-check before
  overwriting.

**Files:** `lib/core/services/backup_service.dart`,
`lib/app/modules/settings/controllers/settings_controller.dart`

---

## 7. Foreground service removed (Play policy + Android 15 breakage)

**Severity:** Critical for Play approval; the service was also broken on
Android 15.

**Three separate problems with the `dataSync` foreground service:**

1. **Android 15 kills it daily.** A `dataSync` FGS is capped at 6 hours per
   24-hour period on Android 15, after which the system stops it. The "24/7
   service" would die every day.
2. **It crashed on boot on Android 15.** Android 15 forbids starting a `dataSync`
   FGS from a `BOOT_COMPLETED` receiver — `BootReceiver.kt` did exactly that and
   would throw `ForegroundServiceStartNotAllowedException`.
3. **Play Console requires a justification** for `dataSync`, and "health
   reminders" is not a valid `dataSync` use case. Likely rejection.

On top of that, the 60-second poll was the source of the duplicate-notification
bug (item 2) and showed a permanent notification in the shade.

**Fix.** Removed the foreground service and replaced it with OS-level scheduling,
which is both Play-compliant and more reliable than polling:

- Deleted `lib/core/services/foreground_service.dart`, `BootReceiver.kt`, and the
  `flutter_foreground_task` dependency.
- **Notifications** already used `zonedSchedule` with
  `AndroidScheduleMode.exactAllowWhileIdle` (fires in Doze) and
  `matchDateTimeComponents: DateTimeComponents.time` (repeats daily). Reboot
  recovery is handled by `ScheduledNotificationBootReceiver`, which is declared
  in the app manifest.
- **Alarms** are re-armed after reboot by the `alarm` package's own
  `BootReceiver`, which the plugin registers in its own manifest — verified
  against the installed source of `alarm 5.2.1`.
- **Safety net:** `ReminderScheduler.rescheduleAllFromStorage()` runs on launch
  and on every app resume. Scheduling is cancel-before-set, so this is idempotent
  and cannot double-fire.

**Replaced the UI that exposed the service.** The home "Background Service" card
and the settings toggle were replaced by `ReminderStatusCard`, which reports what
actually governs reliability now — notification permission, exact-alarm
permission, and battery optimization — with a Fix button that requests them.

**Files:** `lib/core/services/foreground_service.dart` *(deleted)*,
`android/.../BootReceiver.kt` *(deleted)*,
`lib/app/modules/home/views/widgets/service_status_card.dart` *(deleted)*,
`lib/app/modules/home/views/widgets/reminder_status_card.dart` *(new)*,
`lib/app.dart`, `lib/main.dart`, `lib/core/services/permission_service.dart`,
`lib/app/modules/home/controllers/home_controller.dart`,
`lib/app/modules/settings/views/settings_view.dart`, `pubspec.yaml`

---

## 8. Manifest declared alarm plugin classes that do not exist

**Severity:** Medium — dead manifest entries that would throw
`ClassNotFoundException` if ever reached.

**Cause.** The manifest declared:
- `com.gdelataillade.alarm.services.AlarmService`
- `com.gdelataillade.alarm.receivers.AlarmReceiver`

In `alarm 5.2.1` these live at `com.gdelataillade.alarm.alarm.AlarmService` and
`…alarm.AlarmReceiver`. Alarms worked only because the plugin declares the
correct ones in its own manifest, which the merger pulls in.

**Fix.** Removed both bogus declarations. Kept
`com.gdelataillade.alarm.services.NotificationOnKillService`, which *is* a real
class and is *not* declared by the plugin. Also kept the three
`flutter_local_notifications` receivers, which are likewise required — that
plugin's manifest declares permissions only, no receivers.

**Files:** `android/app/src/main/AndroidManifest.xml`

---

## 9. Play Store blockers

| Problem | Fix |
|---|---|
| `applicationId = "com.example.medi_assist"` — Play rejects `com.example.*` outright, and the ID is permanent after first publish | Changed to `com.mediassist.app`; Kotlin package and directory moved to match |
| Release builds signed with the **debug key** — rejected on upload | `signingConfigs` now reads `android/key.properties` (git-ignored). Missing file falls back to debug signing **with a build warning**, so local builds still work but the limitation is loud. Added `key.properties.example` with the `keytool` command |
| `targetSdk` inherited from Flutter's default — Play requires API 35 | Pinned `targetSdk = 35`, `compileSdk = 36` (two plugins require 36) |
| No code shrinking | `isMinifyEnabled` + `isShrinkResources` + `proguard-rules.pro`, with keeps for the alarm/notification plugins and Gson field names (obfuscating those breaks pending notifications across an app update) |
| `SYSTEM_ALERT_WINDOW` requested but unnecessary — a Play-sensitive permission | Removed, along with the `requestSystemAlertWindowPermission()` code path. The alarm screen uses `USE_FULL_SCREEN_INTENT`, which is the correct mechanism |
| `usesCleartextTraffic="true"` on an app that makes no network calls | Removed |
| `requestLegacyExternalStorage="true"` — ignored on API 29+, meaningless at minSdk 26 | Removed |
| `READ_EXTERNAL_STORAGE` merged in from the `alarm` plugin — sensitive storage permission needing a Play declaration | Stripped at merge time with `tools:node="remove"`. The app only plays a bundled asset. Verified absent from the final merged manifest |
| `android:taskAffinity=""` on MainActivity — caused duplicate entries in Recents and odd back behaviour with full-screen-intent alarms | Removed |
| `RECEIVE_BOOT_COMPLETED` declared twice | Deduplicated |
| No backup rules — `allowBackup="false"` alone does not cover Android 12+ device-to-device transfer | Added explicit `data_extraction_rules.xml` disabling both cloud backup and device transfer, consistent with the app's on-device-only privacy claim |

**Files:** `android/app/build.gradle.kts`,
`android/app/src/main/AndroidManifest.xml`, `android/app/proguard-rules.pro`,
`android/app/src/main/res/xml/data_extraction_rules.xml`,
`android/key.properties.example`,
`android/app/src/main/kotlin/com/mediassist/app/MainActivity.kt`

---

## 10. The release build was already broken before this pass

**Symptom.** `flutter build apk --release` failed outright.

**Cause.** `android/gradle.properties` committed
`org.gradle.java.home=C:/JavaSDK/Java/jdk-17`. That directory no longer exists —
the machine now has `jdk-20`. With the stale pin removed, the build fell through
to Android Studio's bundled **JDK 25**, which Gradle 8.14 refuses.

**Fix.**
- Removed the hardcoded absolute path from the committed `gradle.properties`. A
  machine-specific path there breaks every other machine and any CI.
- Pointed Flutter at the installed JDK 20 via `flutter config --jdk-dir`, which
  is **user-level config, not committed**.
- Also removed `android.enableJetifier=true` (obsolete; slows every build).
- Documented the JDK constraint in `README.md` and `CLAUDE.md` so the next
  machine does not rediscover it the hard way.

**Files:** `android/gradle.properties`, `README.md`, `CLAUDE.md`

---

## 11. UI issues

### 11a. Layout broke at large system font sizes
**Symptom.** Yellow/black overflow stripes on the dashboard for users with
Android's font size turned up — i.e. precisely the elderly patients this app
targets.

**Cause.** The module grid used a fixed `childAspectRatio: 0.88` while
`ModuleCard` stacks a 48px icon, an emoji, a two-line title and a subtitle at
fixed font sizes. Nothing clamped `textScaler`, so at 1.3–2.0× the column
exceeded its cell.

**Fix.** Clamped `textScaler` to 1.3× app-wide in `GetMaterialApp.builder`; the
grid now computes `mainAxisExtent` from the current text scale instead of a
fixed ratio; the card title got `maxLines: 2` + ellipsis as a backstop.

### 11b. Content ran under the system bars on Android 15
**Symptom.** Bottom of lists and buttons obscured by the navigation bar.

**Cause.** `targetSdk 35` makes edge-to-edge **mandatory** on Android 15, but
only 2 of the app's screens used `SafeArea`.

**Fix.** Opted into `SystemUiMode.edgeToEdge` explicitly so every Android version
renders identically (rather than only Android 15 users seeing the change), made
the system navigation bar transparent, and applied a single bottom `SafeArea`
above the navigator in `GetMaterialApp.builder` — one fix covering all screens
instead of auditing each `Scaffold`.

### 11c. Notification icon rendered as a grey blob
**Cause.** `AndroidInitializationSettings('@mipmap/ic_launcher')`. Android
renders the small notification icon as a silhouette, so a full-colour launcher
icon becomes a featureless shape.

**Fix.** Switched to `@drawable/notification_icon`, the white-on-transparent
vector already present and already used by the alarm package.

### 11d. Dashboard counters went stale
**Symptom.** Add a medicine, press back, and the dashboard still showed the old
count.

**Cause.** `refreshCounts()` ran only on controller init and pull-to-refresh, and
the controller survives navigation.

**Fix.** `ModuleCard` now awaits its navigation and refreshes `HomeController`
counts on return.

### 11e. Dead "Test Alarm" that claimed success
**Cause.** `SettingsController.sendTestAlarm()` showed "Test alarm set for 10
seconds from now!" and then called `_scheduleTestAlarm()`, an empty stub that
returned `true` and scheduled nothing. It was not wired to any button, so it was
unreachable dead code — but would have lied to the user if wired.

**Fix.** Removed both methods.

### 11f. "1 active reminders"
**Cause.** `medicine_list_view.dart` compared `RxInt != 1` — an
`unrelated_type_equality_checks` that is *always true*, so the plural "s" always
appeared.

**Fix.** Compare `.value`. Added a README contribution note about this class of
Rx mistake.

### 11g. Deprecated `WillPopScope`
**Cause.** The alarm dialog used `WillPopScope` while the manifest sets
`android:enableOnBackInvokedCallback="true"` — mutually inconsistent, and
predictive back would not work.

**Fix.** Migrated to `PopScope(canPop: false)`. The dialog was also extracted out
of `main.dart` into `lib/core/widgets/alarm_ringing_dialog.dart`, and its content
wrapped in `SingleChildScrollView` so it cannot overflow on short screens.

---

## 12. Medicine reminder-time cap

**Latent bug.** Medicine reminder IDs are `base + i` with bases spaced 10 apart,
so an 11th reminder time on one medicine would collide with another medicine's ID
block and silently overwrite its reminder.

**Fix.** Exposed `ReminderScheduler.maxMedicineTimes = 10` and enforced it in
`MedicineController.addTime()` with a clear message, instead of letting the
collision happen. Documented in the README ID table.

---

## 13. Test suite

`test/widget_test.dart` was the **unmodified Flutter counter-app template** — it
pumped a bare `GetMaterialApp` and looked for a "+" button and a "0" that this
app has never had. It would fail if anyone ran it.

**Replaced** with tests that cover the invariants this pass depends on:
- `Medicine` JSON round-trip, including `TimeOfDay` list serialization (the
  backup format depends on this).
- Snooze ID mapping: lands in the snooze range, never collides with its source
  alarm ID, and is stable so re-snoozing replaces rather than stacks.

---

## 14. Alarm-type reminders fired once and never again with the app closed

**Severity:** Critical — the reminder simply stopped, with nothing in the UI to
show it had.

**Symptom.** An alarm-type reminder rang the first time and then went silent.
Reopening the app made it work again for exactly one more day. Notification-type
reminders were unaffected, so a user with a mix of both would see half their
reminders keep working — which reads as random rather than as a bug.

**Cause.** Three separate places, all rooted in the same assumption that Dart
would be running:

1. The `alarm` package arms **one** firing per alarm and has no repeat mode. The
   roll-forward to the next day lived in `main.dart`'s `Alarm.ringing` listener,
   which exists only while a Flutter isolate is alive. Swipe the app away and
   the native `AlarmService` still rang, but `AlarmPlugin.alarmTriggerApi` was
   `null`, Dart never heard about it, and nothing re-armed the alarm.
2. Stopping the alarm — from the ringing dialog, or from the notification's Stop
   button — calls the plugin's `unsaveAlarm`, which deletes it from the plugin's
   own storage. So even a reboot could not recover it: the plugin's
   `BootReceiver` had nothing left to restore.
3. `Alarm.stop()` cancels the AlarmManager entry for that ID, which is the same
   ID the ringing listener had just re-armed for tomorrow. Tapping Stop undid
   the re-arm a second after it happened.

`ReminderScheduler.rescheduleAllFromStorage()` on launch/resume was masking all
of this — but only for users who open the app daily.

**Fix.** Move the daily repeat off the Flutter engine entirely.

- **`DailyAlarmStore.kt`** — the app's own SharedPreferences record of each
  alarm-type reminder as a *time of day*, written over a `MethodChannel` from
  `AlarmService.scheduleAlarm`. Separate from the plugin's store on purpose:
  this one is not deleted when an alarm is stopped, so it can still say what
  tomorrow should look like. Being SharedPreferences rather than GetStorage, it
  is readable from a broadcast receiver with no engine running.
- **`DailyAlarmRearmReceiver.kt`** — a self-perpetuating AlarmManager "sweep"
  set for 2 minutes after the earliest upcoming reminder. On each firing it
  rolls every stored alarm to its next occurrence, re-arms it through the
  plugin's own `AlarmApiImpl`, and schedules the next sweep. The 2-minute lag
  matters: re-arming *before* the alarm fires would push that firing to
  tomorrow. It leaves a ringing alarm ringing, and re-arming is idempotent, so
  it also repairs case 3 above.
- The same receiver handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, and the
  plugin's own `BootReceiver` is removed via `tools:node="remove"`. That
  receiver re-armed each alarm at the `dateTime` it was last saved with — always
  in the past by the time a device finishes booting, which `AlarmApiImpl` treats
  as "fire now", so every reminder rang at once on startup.
- `warningNotificationOnKill` is now `false`: the "reopen the app so your alarms
  can be rescheduled" nag described the old behaviour and is no longer true.
  `androidStopAlarmOnTermination` is `false` so swiping the app away cannot
  silence a reminder that is already ringing.
- The ringing dialog re-arms the daily reminders after Stop and after Snooze,
  rather than waiting up to 2 minutes for the sweep to notice.

Because the store holds an hour and minute rather than an instant, a reminder
also follows the device across timezone changes and DST without any extra work.

**Files:** `android/app/src/main/kotlin/com/mediassist/app/DailyAlarmStore.kt`
*(new)*, `.../DailyAlarmRearmReceiver.kt` *(new)*, `.../MainActivity.kt`,
`android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`,
`lib/core/services/alarm_service.dart`,
`lib/core/services/reminder_scheduler.dart`,
`lib/core/widgets/alarm_ringing_dialog.dart`, `lib/main.dart`

---

## 15. A reminder due within 10 seconds was skipped for a whole day

**Severity:** High.

**Symptom.** Occasionally an alarm just did not ring, with no pattern the user
could describe.

**Cause.** `AlarmService.scheduleAlarm` rolled the alarm to tomorrow if the
target time was `< 10` seconds away, not merely if it had passed. Since
`rescheduleAllFromStorage()` runs on every app resume, opening the app in the
ten seconds before a reminder time silently moved that reminder to the next day.

**Fix.** Roll forward only once the time has actually passed
(`!scheduledTime.isAfter(now)`).

**Files:** `lib/core/services/alarm_service.dart`

---

## 16. Tapping a reminder from a killed app opened the wrong screen

**Severity:** Medium.

**Symptom.** Tapping a medicine reminder while the app was closed opened the
dashboard instead of the medicine list. With the app already running it worked.

**Cause.** The pending-route mechanism was wired to
`onDidReceiveBackgroundNotificationResponse`, which fires for notification
*action buttons* only — and this app defines none, so that handler could never
run. A body tap launches the activity instead, and the payload has to be read
back with `getNotificationAppLaunchDetails()`, which nothing called.

**Fix.** `consumePendingRoute()` now checks the launch details first and falls
back to the stored pending route. Launch details describe the whole process
lifetime, so they are consulted once per process — otherwise every resume would
re-navigate to the screen the original tap asked for.

**Files:** `lib/core/services/notification_service.dart`, `lib/app.dart`

---

## 17. `notification_icon` could be stripped from release builds

**Severity:** Medium — latent.

**Symptom.** None observed, but the failure mode is that notifications stop
appearing in release builds while working fine in debug.

**Cause.** `notification_icon` is referenced only by name, from Dart and from
the alarm plugin's `NotificationSettings`. With `shrinkResources` on, nothing in
code or resources points at it. It happened to survive because AGP's shrinker
matches string-pool constants, which is a heuristic, not a guarantee.

**Fix.** Added `res/raw/keep.xml` with an explicit `tools:keep`. Verified in
`build/app/outputs/mapping/release/resources.txt` that the drawable is
`reachable=true`.

**Files:** `android/app/src/main/res/raw/keep.xml` *(new)*

---

## 18. Dead duplicate of the reminder-ID arithmetic

**Severity:** Low — but the same shape as item 2.

`AlarmService.rescheduleAll()` was unreferenced and carried its own copy of the
medicine/meal/activity ID formulas. Item 2 was caused by exactly this kind of
drift, and it would now also have bypassed the native alarm mirror. Deleted;
`ReminderScheduler.rescheduleAll` is the only caller path.

**Files:** `lib/core/services/alarm_service.dart`

---

## Verification performed

| Check | Result |
|---|---|
| `flutter analyze` | **0 errors, 0 warnings** (down from 4 warnings; 137 remaining items are all `withOpacity`/`prefer_const` style infos — see below) |
| `flutter test` | **4/4 passing** (was a template test that would fail) |
| `flutter build apk --release` | **Succeeds** — 55.6 MB universal APK (was failing before this pass) |
| `flutter build appbundle --release` | **Succeeds** — 53.7 MB `.aab` |
| R8 / minification | Enabled and building clean |
| Final merged manifest | Verified: no `FOREGROUND_SERVICE_DATA_SYNC`, no `SYSTEM_ALERT_WINDOW`, no `READ_EXTERNAL_STORAGE`; package is `com.mediassist.app` |

### Not verified — needs a physical device

I could not run the app on a device or emulator in this environment. These need
hands-on confirmation before you publish:

1. **A reminder actually fires at the right local time.** This is the fix with
   the widest blast radius. Set a reminder 2 minutes out and confirm.
2. **Alarm rings, snoozes, and still fires at the original time the next day.**
3. **Reboot recovery** — set a reminder, restart the phone, confirm it still fires.
4. **Edge-to-edge layout on Android 15**, and layout at 1.3× font size.
5. **Export → Import round trip**, confirming reminders fire after the import.

---

## Remaining known issues (not fixed)

| Item | Why it was left |
|---|---|
| 137 analyzer infos — mostly `withOpacity` → `withValues` | Purely mechanical deprecation churn across ~20 view files. Large diff, zero behavioural change. Say the word and I'll sweep it |
| Unused API in `StorageService` (`pendingRoute`, `themeMode`, `lastRescheduleDate`, generic `getBool`/`setString`/…) | Dead but harmless. `themeMode` in particular looks like scaffolding for a theme switcher that was never built — `app.dart` hardcodes `ThemeMode.system` |
| APK is 55 MB (universal, 3 ABIs) | Play serves per-ABI splits automatically from the `.aab`, so real download size is roughly a third. No action needed if you ship the bundle |
| AGP 8.11.1 / Kotlin 2.2.20 deprecation warnings from Flutter | Upgrading AGP and Kotlin is a separate, riskier change; current versions build fine |
| No `SafeArea`/inset audit per screen | Handled globally instead (11b). If a specific screen needs different treatment it can override locally |
