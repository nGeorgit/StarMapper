---
name: deploy-android
description: >
  Build the StarMapper Godot project for Android and install+launch it on the
  USB-connected phone. Triggers on "run on my phone", "deploy to android",
  "build the apk", "test on device", "push to phone", or similar. Runs
  scripts/deploy_android.sh, which works standalone (no Claude needed) too.
---

Run `scripts/deploy_android.sh` from the project root (`debug` build by default; pass `release` for a release build, e.g. `scripts/deploy_android.sh release`).

This script assumes one-time machine setup is already done:
- Android SDK at `~/Android/Sdk` (platform-tools, build-tools, a platform) with licenses accepted
- Debug keystore configured in Godot's editor settings and/or `export_presets.cfg`
- Godot export templates installed matching the editor version exactly
- `export_presets.cfg` in the project root with an `Android` preset
- `textures/vram_compression/import_etc2_astc=true` in `project.godot` (required for Android export; without it Godot fails with an empty "configuration errors" message)

If any of that is missing (script errors out, or `export_presets.cfg` doesn't exist), redo the setup:
1. Install Android SDK cmdline-tools from `https://dl.google.com/android/repository/commandlinetools-linux-<version>_latest.zip` (get the current version number from `https://dl.google.com/android/repository/repository2-3.xml`, search for `commandlinetools-linux`) into `~/Android/Sdk/cmdline-tools/latest`.
2. `sdkmanager --licenses`, then install `platform-tools`, `build-tools;<ver>`, `platforms;android-<ver>`.
3. Generate a debug keystore with `keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`.
4. Set `export/android/android_sdk_path` and `export/android/java_sdk_path` in `~/.config/godot/editor_settings-4.5.tres` (paths only persist there reliably if the editor has run once with an Android preset open — Godot silently drops unknown keys on save otherwise). Prefer putting keystore info directly in `export_presets.cfg` under `[preset.N.options]` as `keystore/debug`, `keystore/debug_user`, `keystore/debug_password` — that's project-local and doesn't get clobbered.
5. Download matching export templates from `https://github.com/godotengine/godot/releases/download/<version>-stable/Godot_v<version>-stable_export_templates.tpz`, extract into `~/.local/share/godot/export_templates/<version>.stable/` (the `templates/` folder inside the zip gets renamed to the version).
6. `export_presets.cfg` needs a `[preset.0]` section with `platform="Android"` and a `[preset.0.options]` section; minimal required overrides are `architectures/*`, `version/code`, `version/name`, `package/unique_name`, `package/name`, `package/signed=true`, plus the keystore keys from step 4 if not using editor settings.
7. Add `textures/vram_compression/import_etc2_astc=true` under `[rendering]` in `project.godot`.

Phone-side: USB debugging enabled in Developer Options, phone plugged in, RSA debugging prompt accepted (`adb devices` should show `device`, not `unauthorized`).
