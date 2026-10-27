#!/usr/bin/env bash
# scripts/build.sh
set -euo pipefail
command -v flutter >/dev/null || { echo "Flutter is not on PATH" >&2; exit 1; }
flutter config --enable-linux-desktop
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build linux --release
echo 'Build complete: build/linux/x64/release/bundle/echotext'
