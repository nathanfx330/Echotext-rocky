#!/usr/bin/env bash
# scripts/smoke-test-piper.sh
set -euo pipefail
PIPER="${ECHOTEXT_PIPER:-piper/piper}"
MODEL_DIR="${ECHOTEXT_MODEL_DIR:-model}"
[[ -f "$PIPER" ]] || { echo "Piper not found: $PIPER" >&2; exit 1; }
[[ -x "$PIPER" ]] || { echo "Piper must be executable: chmod +x '$PIPER'" >&2; exit 1; }
VOICE="$(find "$MODEL_DIR" -maxdepth 2 -type f -name '*.onnx' -print -quit)"
[[ -n "$VOICE" ]] || { echo "No voice files found in $MODEL_DIR" >&2; exit 1; }
[[ -f "${VOICE}.json" ]] || { echo "Missing config ${VOICE}.json" >&2; exit 1; }
PIPER="$(realpath "$PIPER")"
VOICE="$(realpath "$VOICE")"
DIR="$(dirname "$PIPER")"
export LD_LIBRARY_PATH="$DIR:$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
TMP="$(mktemp --suffix=.wav)"
trap 'rm -f "$TMP"' EXIT
printf 'Hello from EchoText on Rocky Linux.\n' | "$PIPER" --model "$VOICE" --output_file "$TMP"
[[ -s "$TMP" ]] || { echo "No audio was produced" >&2; exit 1; }
file "$TMP"
echo 'CPU Piper synthesis: PASS'
