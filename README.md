💊 MediAssist

Your Personal Health Companion — Free & Open Source


A comprehensive health reminder Android app built with Flutter for patients who need to stay on top of their medicines, meals, medical records, and daily activities. MediAssist works 24/7, survives device reboots, and delivers reminders even when the app is closed.

⚠️ **Free for patients. Not for commercial use.** See [License](#-license) section.


## 📸 Screenshots

> _Coming soon — screenshots will be added after UI finalization_

| Home Screen | Medicine Reminder | Meal Reminder | Medical Records | Activity Reminder | Settings |
|:-----------:|:-----------------:|:-------------:|:---------------:|:-----------------:|:--------:|

## ✨ Features

### 💊 Medicine Reminder
- Add medicines with **multiple daily reminder times**
- Choose reminder type: **Notification**, **Alarm**, **Both**, or **None**
- Enable / disable individual medicines without deleting them
- Full CRUD — add, edit, delete with swipe gestures
- Smart time sorting (chronological order)

### 🍽️ Meal Reminder
- Set reminders for Breakfast, Lunch, Snack, Dinner, or any custom meal
- Quick preset times (one tap to set Breakfast 8AM, Lunch 1PM, etc.)
- Dynamic meal icon based on time of day (🌅🌙☀️☕)
- Notification or alarm support

### 📋 Medical Records
- Log **6 health metrics**: Blood Pressure, Heart Rate, Oxygen Level, Diabetes Level, Temperature, Weight
- Category dropdown per metric type (e.g., Fasting / Post-meal for diabetes)
- Automatic stats: **total entries, latest value, average, min–max range**
- Recent 5 entries shown on dashboard
- Full history per metric with date/time filter

### 🏃 Activity Reminder
- Add any physical activity (Running, Yoga, Gym, Cycling, Swimming, etc.)
- Smart icon auto-detection from activity name
- Activity category badge (Cardio, Strength, Flexibility, etc.)
- Quick suggestion chips for 8 common activities

### 🔔 Smart Notifications & Alarms
- **Exact alarms** using Android's `AlarmManager` — fires on time even in Doze mode
- **Daily repeating** — automatically reschedules for the next day after firing
- **Alarm screen** with Stop and Snooze buttons (shown over lock screen)
- **Stop from notification bar** — no need to open the app
- **Snooze** with user-configurable duration (5, 10, 15, 30 minutes)
- **Notification tap navigation** — tapping a notification opens the correct module

### 🛡️ Reliable Delivery Without a Background Service
- **OS-level exact alarms** — `AlarmManager` fires reminders even in Doze, with no
  persistent notification and no battery drain from polling
- **Survives reboot** — pending notifications and alarms are re-armed by the
  platform boot receivers, then re-verified from storage on next launch
- **Re-armed on every app resume** — catches anything the OS dropped
- **Timezone-aware** — reminders follow your wall clock across travel and DST
- **Battery optimization bypass** — guided setup for unrestricted background operation
- **MIUI/Xiaomi support** — handles aggressive MIUI battery management

### 💾 Local Storage & Persistence
- All data stored **locally on device** using `GetStorage` — no internet required, no cloud
- **Two separate storage boxes**: data box (clearable) + settings box (permanent)
- Settings **never reset** — snooze preference, service state, permissions all persist
- Clear all health data without losing app preferences

### 🎨 Professional UI/UX
- **Material 3** design system
- **Light & Dark theme** with system auto-switch
- **Smooth animations** — staggered list entries, card transitions, pulse effects
- Swipe-to-edit and swipe-to-delete via `flutter_slidable`
- Empty states with helpful call-to-action
- Color-coded modules (Indigo, Pink, Teal, Amber)

### 🌐 Language — English & বাংলা
- Switch language from **Settings → Language**; takes effect immediately, with
  no restart, and is remembered across app launches
- The choice lives in the settings box, so **"Clear All Data" does not reset it**
- **Complete** Bangla, not partial: screens, dialogs, validation messages,
  snackbars, and the reminder notifications and alarms themselves — including
  ones already scheduled, which are re-armed in the new language on the spot
- Natural Bangla conventions rather than a literal translation — times read
  "সকাল ৮:০০" (part of day first, Bengali digits), not "8:00 AM"
- Android's own notification-channel names in system Settings follow too
- Defaults to English until the user chooses otherwise


## 🏗️ Architecture & Tech Stack

### State Management

GetX (GetxController + Obx + RxList/RxInt/RxString)


### Project Structure (GetX CLI pattern)

lib/
├── main.dart                    # App entry, alarm listener, snooze logic
├── app.dart                     # GetMaterialApp, lifecycle observer
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   # All keys, IDs, types, asset paths
│   │   └── app_colors.dart      # Full color system (light/dark/gradients)
│   ├── themes/
│   │   └── app_theme.dart       # Material 3 light & dark themes
│   ├── services/
│   │   ├── storage_service.dart      # Dual-box GetStorage (data + settings)
│   │   ├── notification_service.dart # Daily exact notifications + timezone + tap nav
│   │   ├── alarm_service.dart        # alarm package wrapper + reschedule
│   │   ├── permission_service.dart   # Runtime permissions management
│   │   ├── backup_service.dart       # JSON export / import with rollback
│   │   └── reminder_scheduler.dart   # Central scheduler (notif + alarm)
│   ├── bindings/
│   │   └── initial_binding.dart # Permanent service registrations
│   ├── utils/
│   │   ├── id_generator.dart    # Unique ID + stable int ID generation
│   │   ├── time_utils.dart      # Time formatting, next occurrence, greeting
│   │   └── app_utils.dart       # Snackbars, confirm dialogs, helpers
│   └── widgets/
│       └── notif_type_selector.dart  # Reusable notification type picker
├── models/
│   ├── medicine_model.dart
│   ├── meal_model.dart
│   ├── medical_record_model.dart
│   └── activity_model.dart
├── routes/
│   ├── app_pages.dart
│   └── app_routes.dart
└── app/modules/
    ├── splash/
    ├── home/
    ├── medicine/
    ├── meal/
    ├── medical_records/
    ├── activity/
    └── settings/

### Key Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `get` | ^4.6.6 | State management, navigation, dependency injection |
| `get_storage` | ^2.1.1 | Local persistent storage (no SQLite overhead) |
| `alarm` | ^5.1.3 | Native exact alarms with full-screen intent & sound |
| `flutter_local_notifications` | ^19.5.0 | Daily scheduled notifications |
| `flutter_timezone` | ^5.1.0 | Resolves the device zone so reminders use local wall-clock time |
| `permission_handler` | ^12.0.1 | Runtime Android permissions |
| `flutter_slidable` | ^3.1.1 | Swipe-to-edit / swipe-to-delete list items |
| `timezone` | ^0.10.1 | Timezone-aware notification scheduling |
| `intl` | ^0.20.2 | Date/time formatting |


## 📱 Requirements

| Requirement | Minimum |
|-------------|---------|
| Android | 8.0 (API 26) |
| Flutter | 3.22.0 |
| Dart | 3.3.0 |
| Gradle | 8.14 |
| AGP | 8.11.1 |
| Kotlin | 2.2.20 |
| JDK | 17–23 (Gradle 8.14 rejects JDK 25) |

> Android Studio bundles JDK 25, which Gradle 8.14 refuses. Point Flutter at a
> supported JDK once per machine:
> `flutter config --jdk-dir="C:/path/to/jdk-20"`

> iOS is **not currently supported**. Android only.

When you open MediAssist for the first time, grant these permissions for full functionality:

| Permission | Why It's Needed |
|------------|----------------|
| **Notifications** | To show medicine and meal reminders |
| **Exact Alarms** | To fire alarms at the precise scheduled time |
| **Battery Optimization** | Disable it so the app runs 24/7 without being killed |
| **Autostart** (MIUI only) | Allow app to start after reboot on Xiaomi/Redmi devices |

### Xiaomi / MIUI Users (Extra Steps)

Settings → Apps → MediAssist → Battery → No Restrictions
Security App → Permissions → Autostart → MediAssist → Allow

## 🏥 How It Works

### Reminder Flow

User adds reminder
        │
        ▼
ReminderScheduler.schedule()
  (cancel-then-set, idempotent)
        │
   ┌────┴────┐
   │         │
Notification  Alarm
(zonedSchedule (alarm pkg,
 exactAllowWhileIdle,  full-screen
 repeats daily)         intent)
   │         │
   └────┬────┘
        ▼
  Android AlarmManager
  fires even in Doze

### Boot Recovery Flow

Device Reboots
       │
       ├──────────────────────────┐
       ▼                          ▼
ScheduledNotification      alarm pkg BootReceiver
BootReceiver               re-arms stored alarms
(re-arms notifications)
       │                          │
       └────────────┬─────────────┘
                    ▼
        Next app launch / resume
        rescheduleAllFromStorage()
        re-verifies everything

### Alarm Repeat Flow

Alarm fires at scheduled time
       │
       ▼
Alarm.ringing stream emits
       │
       ▼
_rescheduleAlarmForNextDay()
same ID, +24 hours
       │
       ▼
In-app screen shows (if app open)
Notification shows Stop button (always)
       │
   ┌───┴───┐
   Stop   Snooze
   │        │
  Done    +N min under a SEPARATE
          snooze ID, so the daily
          alarm never drifts

## 🔧 Configuration

### Notification ID Ranges

| Module | Notifications | Alarms |
|--------|---------------|--------|
| Medicine | 1000–1999 | 5000–5999 |
| Meal | 2000–2999 | 6000–6999 |
| Activity | 3000–3999 | 7000–7999 |
| Medical | 4000–4999 | 8000–8999 |
| Snooze | — | 9000–9999 |
| Test | 9999 | — |

Medicine slot `i` uses `base + i` and bases are spaced 10 apart, so a medicine is
capped at 10 reminder times (`ReminderScheduler.maxMedicineTimes`). Snoozes get
their own range so re-arming one never overwrites the daily alarm it came from.

### Storage Boxes

| Box | Contents | Cleared by "Clear Data"? |
|-----|----------|--------------------------|
| Default (data) | Medicines, meals, activities, records | ✅ Yes |
| `mediassist_settings` | Permissions asked, service state, snooze duration | ❌ No |


## 🤝 Contributing

Contributions are welcome! This project is maintained for the benefit of patients worldwide.

### How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m 'Add: your feature description'`
4. Push to branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

### Contribution Guidelines

- Follow the existing **GetX pattern** (controller / view / binding separation)
- Use **relative imports** — never `package:medi_assist/` inside the project
- All Obx widgets must access actual `.obs` Rx variables directly, via `.value`
  (interpolating the `Rx` object itself compiles but comparisons against it
  always fail)
- Do not use `GridView.builder` or `ListView.builder` inside `Obx` (lazy itemBuilder breaks GetX tracking — use eager `.map().toList()` instead)
- **Never duplicate reminder-ID arithmetic.** The helpers at the bottom of
  `ReminderScheduler` are the only copy; a second one silently produces a
  different ID for the same reminder and users get duplicate notifications
- Anything scheduled must go through `ReminderScheduler`, so cancel/reschedule
  stays symmetric — orphaned alarms cannot be stopped from the UI
- **No user-facing string may be hardcoded.** Add a key to both language maps in
  `AppTranslations` and read it with `.tr` (or `.trParams` when it carries a
  value — word order differs between English and Bangla, so interpolation is not
  interchangeable). `flutter test` fails if the two maps drift apart
- A `Text` displaying a `.tr` string cannot be `const` — it would keep whichever
  language it was first built in. Put the `const` on the `TextStyle` instead
- Test on a **physical Android device** before submitting, including at 1.3×
  system font size and on Android 15 (edge-to-edge is enforced there)
- Update `README.md` if you add new features or dependencies

### Roadmap / Planned Features

- [ ] iOS support
- [ ] Medicine stock tracking (remaining pills counter)
- [ ] PDF/CSV export of medical records
- [ ] Health trends chart (weekly/monthly graphs)
- [ ] Multiple user profiles (family mode)
- [ ] Backup & restore via Google Drive
- [ ] Doctor appointment reminders
- [ ] Medicine photo attachment
- [ ] Widget for home screen
- [ ] Wear OS companion


## 🐛 Known Issues & Troubleshooting

### Alarm not ringing after phone restart
> Go to Settings → Battery → MediAssist → **No Restrictions**
> On MIUI: Security → Permissions → Autostart → Enable for MediAssist

### Notifications not showing
> Settings screen → Permissions → Notifications → tap **Fix** → grant permission

### Alarm fires but no sound
> Make sure `assets/audio/alarm.mp3` is a valid audio file (not empty)
> Check device volume and Do Not Disturb settings

### App crashes on launch (missing alarm.mp3)
> Add a valid MP3 file to `assets/audio/alarm.mp3`

### "Exact alarms" permission missing on Android 12+
> Settings → Permissions → Exact Alarms → tap **Fix** → Allow


## 📄 License

MediAssist — Free Health Reminder App
Copyright (c) 2025 — Open Source for Patients

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software, to use, copy, modify, and distribute this
software for PERSONAL and NON-COMMERCIAL purposes only, subject to
the following conditions:

RESTRICTIONS — The following are STRICTLY PROHIBITED:
  1. Publishing this application or any derivative work to the
     Google Play Store, Apple App Store, or any other app marketplace
     for the purpose of earning money, revenue, or any financial gain.

  2. Selling, sublicensing, or commercially exploiting this software
     or any portion of it in any form.

  3. Using this software as a basis for a paid product or service.

PERMITTED — The following are explicitly allowed:
  ✅ Personal use by patients to manage their health
  ✅ Modifying the code for personal or non-commercial use
  ✅ Contributing improvements back to this repository
  ✅ Forking for open-source, non-commercial derivative projects
  ✅ Using as a learning resource or portfolio project
  ✅ Healthcare organizations providing it FREE to patients

This software is provided "as is", without warranty of any kind.
The authors are not liable for any health decisions made based on
this application. Always consult a licensed healthcare professional.

This is a PATIENT-FIRST project. It must remain free for patients.


## ⚕️ Medical Disclaimer

> MediAssist is a **reminder tool only**. It does not provide medical advice, diagnosis, or treatment. Always follow your doctor's instructions. Never rely solely on an app for critical medication management. The developers are not responsible for missed doses or health outcomes.


## 👨‍💻 Author

Built with ❤️ for patients who deserve reliable, free health tools.


**If MediAssist helped you, please ⭐ star the repository to help other patients find it.**


Made with Flutter · Powered by GetX · Free for patients forever
