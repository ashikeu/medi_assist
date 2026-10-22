# Play Store submission checklist

What the code now satisfies, and what still has to be done by hand in Play
Console. Items marked **YOU** cannot be done from the repo.

## Done in the project

| Item | State |
|---|---|
| Application ID | `com.mediassist.app` (was `com.example.medi_assist`, which Play rejects) |
| Release signing | Wired to `android/key.properties`; falls back to debug signing with a loud warning |
| `targetSdk` | Pinned to 35 (Play's current floor); `compileSdk` 36 |
| Code shrinking | R8 + `proguard-rules.pro`, with keeps for the alarm and notification plugins |
| Foreground service | Removed. No `dataSync` FGS, so no Android 15 6-hour cap and no FGS justification form |
| Permissions | Trimmed to the minimum; `READ_EXTERNAL_STORAGE` stripped from the alarm plugin at merge time |
| Backup | `allowBackup=false` + explicit `data_extraction_rules.xml` (no cloud backup, no device transfer) |
| Build output | `flutter build appbundle --release` produces the `.aab` Play wants |

## YOU — before first upload

1. **Generate the upload keystore** and create `android/key.properties`.
   See `android/key.properties.example`. Back the `.jks` up somewhere durable —
   losing it means you can never update the app again.

2. **Bump the version** in `pubspec.yaml` (`version: 1.0.0+1`) for every upload.
   `versionCode` (the `+N`) must strictly increase.

3. **Privacy Policy URL** — required, because the app handles health data.
   It must be a public URL and must state that data stays on-device and is only
   exported when the user chooses to.

4. **Data Safety form** — declare health data collection. The honest answers
   here are: data is collected/stored on-device, not transmitted, not shared,
   and the user can delete it in-app (Settings → Clear All Data).

5. **Health apps declaration** — Play asks for this for medical/health
   functionality. MediAssist is a reminder tool, not a diagnostic device; say so.

6. **Permission declarations** for the two sensitive permissions in use:
   - `USE_EXACT_ALARM` — justify as an alarm/reminder app whose core function is
     firing at an exact user-set time. If Play pushes back, the fallback is to
     drop `USE_EXACT_ALARM` and rely on `SCHEDULE_EXACT_ALARM` plus the in-app
     grant flow, which is already implemented.
   - `USE_FULL_SCREEN_INTENT` — justify as the alarm ringing screen.

7. **Store listing assets** — icon 512×512, feature graphic 1024×500, and at
   least 2 phone screenshots. The README's screenshot table is still empty.

8. **Content rating questionnaire** and target audience (not children).

## Known remaining risk

`USE_EXACT_ALARM` is the one item most likely to draw a review question. The app
qualifies on function, but medication reminders sit closer to the edge of the
policy than a plain alarm clock. Have the fallback in point 6 ready.
