# Test report — v2.0.0 (versionCode 3)

CI run: `41825293901 dace760` on GitHub Actions, Flutter 3.47.9 stable, Dart 3.13.7.

## Static analysis
`flutter analyze`: **0 issues**.

## Unit tests (`test/content_test.dart`) — 11/11 passed
| Test | Result |
|---|---|
| All 11 required azkar sections present | ✅ |
| Every zekr has text, repeat count > 0 and a source | ✅ |
| Content IDs stable and unique | ✅ |
| Arabic digits / diacritic-insensitive normalisation / repeat wording | ✅ |
| Daily wird progress ratio | ✅ |
| Prayer times ordered (Fajr → Isha), manual offset shifts time, none without location | ✅ |
| Qibla bearing from Riyadh ≈ 243.8° | ✅ |

## Emulator tests (Android 14, Pixel 6 profile, x86_64)
`integration_test/screenshots_test.dart` — **passed**
- Home dashboard renders (greeting, Hijri + Gregorian date, next prayer countdown, zekr of the day, daily wird).
- Morning azkar reader opens on Ayat al-Kursi; tapping the counter completes it and auto-advances to the next zekr.
- Categories, tasbih (5 taps counted against target 33), prayer times (Riyadh preset), More, floating-azkar settings, settings.
- Switching to dark theme and re-opening home and evening azkar.

`integration_test/overlay_test.dart` — **passed**
- With "display over other apps" granted, the floating zekr card is drawn over the app (captured with device-level screenshots) and rotates between azkar.

Screenshots: `store/screenshots/` and the `screens` branch.

## Bugs found and fixed during testing
1. Background daily worker closed the app's database connection (shared SQLite instance) → worker now uses its own connection.
2. Tasbih screen read app state while being disposed → reference captured at init.
3. Chip labels invisible (no text colour in chip theme) → fixed.
4. Quran pause marks rendered as floating glyphs under lines → removed from body text (letters and tashkeel unchanged).
5. Previous/next arrows pointed the wrong way in RTL → fixed.
6. Name clash between app `Category` model and Flutter annotation → fixed.

## Not covered by automated tests (needs a real phone)
- Prayer and reminder notifications firing at the scheduled time.
- Compass/qibla (the emulator has no magnetometer).
- Home-screen widget placement (launcher interaction).
- Overlay persistence after reboot and on aggressive battery managers (Xiaomi, Oppo, Huawei…).
- Share sheet to WhatsApp.
