#!/usr/bin/env bash
# scripts/run-dev.sh
set -euo pipefail
command -v flutter >/dev/null || { echo "Flutter is not on PATH" >&2; exit 1; }
flutter config --enable-linux-desktop
flutter pub get
flutter run -d linux
