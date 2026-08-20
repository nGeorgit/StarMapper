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


