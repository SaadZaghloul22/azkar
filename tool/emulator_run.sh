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
kill $CAP $GRANT 2>/dev/null
# keep only captures that are not identical to the first (cheap dedupe by size)
echo "main=$MAIN overlay=$OVL" > screenshots/status.txt
tail -5 screenshots/drive.txt; tail -5 screenshots/drive_overlay.txt
[ $MAIN -eq 0 ] && [ $OVL -eq 0 ]
