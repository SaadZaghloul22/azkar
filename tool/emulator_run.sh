#!/usr/bin/env bash
# Runs on the CI emulator: UI walkthrough screenshots, then the floating-window check.
set -u
mkdir -p screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart > screenshots/drive.txt 2>&1
MAIN=$?
# flutter drive reinstalls the app, which resets app-ops; keep granting while the test runs
( while true; do adb shell appops set com.azk.azkarak SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1; sleep 2; done ) &
GRANT=$!
( for i in $(seq 1 40); do sleep 8; adb exec-out screencap -p > screenshots/overlay_$i.png; done ) &
CAP=$!
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/overlay_test.dart > screenshots/drive_overlay.txt 2>&1
OVL=$?
kill $CAP 2>/dev/null

# Demo video for the Play foreground-service declaration.
( while true; do adb shell pm grant com.azk.azkarak android.permission.POST_NOTIFICATIONS >/dev/null 2>&1; sleep 1; done ) &
NOTIF=$!
adb shell rm -f /sdcard/fgs-demo.mp4
: > screenshots/drive_fgs.txt
( until grep -q "Installing" screenshots/drive_fgs.txt; do sleep 1; done; sleep 6
  adb shell screenrecord --time-limit 90 --bit-rate 4000000 /sdcard/fgs-demo.mp4 ) &
REC=$!
( until grep -q "Installing" screenshots/drive_fgs.txt; do sleep 1; done; sleep 55
  adb shell cmd statusbar expand-notifications; sleep 7; adb shell cmd statusbar collapse ) &
SHADE=$!
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/fgs_demo_test.dart >> screenshots/drive_fgs.txt 2>&1
wait $REC
kill $SHADE $GRANT $NOTIF 2>/dev/null
adb pull /sdcard/fgs-demo.mp4 screenshots/fgs-demo.mp4 || true
# keep only captures that are not identical to the first (cheap dedupe by size)
echo "main=$MAIN overlay=$OVL" > screenshots/status.txt
tail -5 screenshots/drive.txt; tail -5 screenshots/drive_overlay.txt
[ $MAIN -eq 0 ] && [ $OVL -eq 0 ]
