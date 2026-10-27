#!/usr/bin/env bash
# scripts/test-kokoro.sh
# Generate a genuine CPU-only WAV on Rocky without running the Flutter UI.
set -euo pipefail
if [[ ! -x ".venv-kokoro/bin/python" ]]; then
  echo "Missing .venv-kokoro Python. Run: bash scripts/setup-kokoro.sh" >&2
  exit 1
fi
if [[ ! -s "kokoro/kokoro-v1.0.onnx" || ! -s "kokoro/voices-v1.0.bin" ]]; then
  echo "Missing Kokoro model/voice files. Run: bash scripts/download-kokoro.sh" >&2
  exit 1
fi
OUT="$(mktemp --suffix=.wav)"
trap 'rm -f "$OUT"' EXIT
.venv-kokoro/bin/python scripts/kokoro_worker.py --smoke-test "$OUT"
test -s "$OUT"
file "$OUT"
echo "Kokoro CPU synthesis: PASS"
