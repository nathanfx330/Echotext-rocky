#!/usr/bin/env bash
# scripts/diagnose.sh
set -u
echo '== OS =='
[[ -f /etc/os-release ]] && grep -E '^(PRETTY_NAME|ID|VERSION_ID)=' /etc/os-release
echo '== Toolchain =='
for tool in flutter dart clang cmake ninja pkg-config file ldd; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s: %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%s: MISSING\n' "$tool"
  fi
done
if command -v flutter >/dev/null 2>&1; then flutter --version; fi
echo '== GTK / GStreamer =='
if command -v pkg-config >/dev/null 2>&1; then
  for lib in gtk+-3.0 gstreamer-1.0 gstreamer-app-1.0; do
    if pkg-config --exists "$lib"; then pkg-config --modversion "$lib"
    else echo "$lib: MISSING"; fi
  done
fi
echo '== Piper (local or override) =='
PIPER="${ECHOTEXT_PIPER:-piper/piper}"
if [[ -f "$PIPER" ]]; then
  file "$PIPER"
  ldd "$PIPER" 2>&1 || true
else
  echo "MISSING: $PIPER"
fi
echo '== Voice models =='
MODEL_DIR="${ECHOTEXT_MODEL_DIR:-model}"
if [[ -d "$MODEL_DIR" ]]; then
  find "$MODEL_DIR" -maxdepth 2 -type f -name '*.onnx' -print
else
  echo "MISSING: $MODEL_DIR"
fi
