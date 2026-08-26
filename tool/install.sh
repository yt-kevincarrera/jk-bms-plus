#!/usr/bin/env bash
# Builds and installs straight onto a phone plugged into USB.
#
# This is the local path and it needs no GitHub token, no release and no
# internet: it is the same signing key as the published builds, so it installs
# over an installed release without uninstalling and without touching the ride
# history.
set -euo pipefail

cd "$(dirname "$0")/.."

ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
if ! [[ -x "$ADB" ]]; then
  ADB="$(command -v adb || true)"
fi
if [[ -z "$ADB" ]]; then
  echo "error: adb not found. Set ADB=/path/to/adb" >&2
  exit 1
fi

if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "error: no phone connected. Plug it in and allow USB debugging." >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "warning: android/key.properties is missing, so this build is signed" >&2
  echo "         with the debug key and will NOT install over a release one." >&2
  echo "         See docs/RELEASING.md." >&2
fi

# Only the ABI this phone actually runs, rather than all three.
ABI="$("$ADB" shell getprop ro.product.cpu.abi | tr -d '\r\n')"
echo "==> Phone reports $ABI"

flutter build apk --release --split-per-abi

APK="build/app/outputs/flutter-apk/app-$ABI-release.apk"
if [[ ! -f "$APK" ]]; then
  echo "error: no build for $ABI at $APK" >&2
  exit 1
fi

echo "==> Installing $(du -h "$APK" | cut -f1)"
# -r keeps the app's data. A failure here with INSTALL_FAILED_UPDATE_INCOMPATIBLE
# means the installed copy was signed with a different key.
"$ADB" install -r "$APK"

"$ADB" shell monkey -p dev.selector.jk_bms -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
echo "==> Installed and launched"
