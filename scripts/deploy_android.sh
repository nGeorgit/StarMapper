#!/usr/bin/env bash
# Build the Godot project for Android and install+launch it on a USB-connected phone.
# Usage: scripts/deploy_android.sh [debug|release]
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GODOT_BIN="${GODOT_BIN:-/home/nikolas/Godot_v4.5.1-stable_linux.x86_64}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
PRESET="${PRESET:-Android}"
BUILD_TYPE="${1:-${BUILD_TYPE:-debug}}"
APK_NAME="${APK_NAME:-$(basename "$PROJECT_DIR").apk}"

export PATH="$ANDROID_HOME/platform-tools:$PATH"
cd "$PROJECT_DIR"

if [ ! -f "export_presets.cfg" ]; then
  echo "No export_presets.cfg found. Open the project in Godot once and add an Android export preset (Project > Export > Add > Android), or ask Claude to set it up." >&2
  exit 1
fi

echo "==> Building $BUILD_TYPE APK (preset: $PRESET)"
if [ "$BUILD_TYPE" = "release" ]; then
  "$GODOT_BIN" --headless --export-release "$PRESET" "$APK_NAME"
else
  "$GODOT_BIN" --headless --export-debug "$PRESET" "$APK_NAME"
fi

adb start-server >/dev/null

FOUND_DEVICE=0
for _ in 1 2 3 4 5; do
  if adb devices | grep -qw "device"; then
    FOUND_DEVICE=1
    break
  fi
  sleep 1
done
if [ "$FOUND_DEVICE" -eq 0 ]; then
  echo "No authorized device found. Plug your phone in via USB, enable USB debugging, and accept the RSA prompt on screen." >&2
  adb devices
  exit 1
fi

AAPT_DIR=$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
if [ -z "$AAPT_DIR" ]; then
  echo "No build-tools found under $ANDROID_HOME/build-tools." >&2
  exit 1
fi
AAPT="${AAPT_DIR}aapt"

read -r PACKAGE LAUNCH_ACTIVITY < <("$AAPT" dump badging "$APK_NAME" 2>/dev/null | awk -F"'" '
  /^package:/ { pkg = $2 }
  /^launchable-activity:/ { act = $2 }
  END { print pkg, act }
')

if [ -z "$PACKAGE" ] || [ -z "$LAUNCH_ACTIVITY" ]; then
  echo "Could not read package/activity from $APK_NAME via aapt." >&2
  exit 1
fi

echo "==> Installing $PACKAGE"
adb install -r "$APK_NAME"

echo "==> Launching $PACKAGE/$LAUNCH_ACTIVITY"
adb shell am start -n "$PACKAGE/$LAUNCH_ACTIVITY"

echo "==> Done. Check your phone."
