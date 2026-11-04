# أذكار المسلم — Azkar Al-Muslim

Free, ad-free Islamic azkar app for Android, fully in Arabic (RTL) and working offline.
Published on Google Play as package **`com.azk.azkarak`** (this release replaces the old
"اذكارنا" app as an update).

## Features

| Area | What it does |
|---|---|
| Azkar | 11 sections, 109 authentic azkar with tashkeel, repeat count, counter, virtue (only where a hadith states it) and source |
| Reader | One zekr per page, big tap counter, auto-advance, progress saved for the day, favorite, copy, share as image |
| Floating azkar | Native Kotlin foreground service shows a zekr over other apps every 5/10/15/30/60 min; active hours; skipped during calls, DND, screen off/locked; random or sequential; choose sections + own azkar; falls back to notifications without the overlay permission; restarts after reboot |
| Tasbih | Large counter, 33/100/500/1000/custom/open targets, vibration and sound toggles, custom tasbihat, saved sessions, daily/weekly history |
| Prayer times | `adhan` library (astronomical), 12 calculation methods, Hanafi Asr option, per-prayer manual offsets, countdown, per-prayer alerts (exact when allowed) |
| Qibla | Compass with bearing from location, angle, calibration hint, handles devices with no sensor |
| Reminders | Morning, evening, sleep, random zekr, istighfar, daily wird — each with its own time |
| Widget | Home-screen widget: zekr of the day + "another zekr" button, works without opening the app |
| Favorites & search | Favorites, diacritic-insensitive search with section filter, recently read, user azkar (clearly labelled) |
| Theme | Light / dark / system, Cairo UI font + Amiri for azkar text, adjustable size |

## Project layout

```
assets/data/azkar.json     generated content (do not edit by hand)
tool/build_azkar.py        content source of truth → regenerates azkar.json
tool/make_icon.py          launcher/adaptive/store icons
lib/core                   theme, Arabic helpers (digits, dates, normalisation)
lib/data                   SQLite schema, migrations, queries (sqflite)
lib/state                  settings (SharedPreferences) and app state (provider)
lib/services               notifications, prayer times, location, background work, native bridge
lib/screens                all screens
android/app/src/main/kotlin/com/azk/azkarak
    MainActivity.kt        method channel "azkarak/native"
    OverlayService.kt      floating azkar foreground service
    OverlayWindow.kt       floating card + notification fallback
    AzkarWidget.kt         home-screen widget
    BootReceiver.kt        restart after reboot/update
    AzkarSource.kt         reads the same bundled azkar.json
test/                      unit tests (content integrity, helpers, prayer times, qibla)
integration_test/          emulator walkthrough + floating window check (screenshots)
```

See [docs/BUILD.md](docs/BUILD.md) to build and release, [docs/PRIVACY.md](docs/PRIVACY.md)
for the privacy policy and [docs/TEST_REPORT.md](docs/TEST_REPORT.md) for test results.

## Database

SQLite tables: `categories`, `azkar` (with `search_text`, `is_verified`), `favorites`,
`recents`, `tasbeeh_sessions`, `custom_tasbeeh`, `user_settings`, `daily_progress`,
`custom_azkar`. Foreign keys with cascade, indexes on category/sort, created_at, used_at.
Schema migrations go in `AppDatabase._migrate` (one step per version). Bundled content is
versioned; azkar IDs are stable (`category * 1000 + index`) so favorites survive updates.

## Content policy

Texts come from Hisn al-Muslim, the Sahihayn and the Sunan, and the Mushaf. A virtue is shown
only where an authentic narration states it, always with its source. Edit content only in
`tool/build_azkar.py`, bump `version`, and run `python3 tool/build_azkar.py`.
