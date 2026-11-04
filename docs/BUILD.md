# Build and release

## Automatic (recommended)

Every push to `main` runs `.github/workflows/ci.yml` on GitHub:

1. `flutter analyze` and `flutter test`
2. `flutter build appbundle --release` → **unsigned** AAB
3. `flutter build apk --release` signed with a throwaway test key → `azkar-test.apk`
4. On an Android 14 emulator: walks through every main screen, captures screenshots,
   grants the overlay permission and checks the floating zekr window.

Outputs are pushed to two branches:

- `builds`: `app-release-unsigned.aab`, `azkar-test.apk`, `analyze.txt`, `test.txt`
- `screens`: emulator screenshots and logs

## Signing the AAB for Google Play

The upload key is **not** stored in the repo. Sign locally:

```bash
jarsigner -keystore azkarak-upload.jks -sigalg SHA256withRSA -digestalg SHA-256 \
  app-release-unsigned.aab upload
jarsigner -verify app-release-unsigned.aab
```

Then in Play Console: Test and release → Production → Create new release → upload the AAB.
The version code comes from `pubspec.yaml` (`version: 2.0.0+3` → versionCode 3). Increase the
number after `+` for every new upload.

## Local build (optional)

Requires Flutter stable (3.47+), Android SDK 35+, JDK 17.

```bash
flutter pub get
flutter test
flutter run                      # debug on a device
flutter build appbundle --release
```

## Play Console declarations for this version

- **Foreground service — special use**: "Shows short azkar reminders over other apps at the
  interval the user chose; enabled by the user, stoppable from the notification."
- **Display over other apps**: used only for the floating azkar the user enables.
- **Exact alarms**: prayer-time alerts at the exact time of each prayer.
- **Location**: approximate/precise, only to calculate prayer times and qibla on the device.
- **Data safety**: no data collected or shared.
