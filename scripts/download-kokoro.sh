#!/usr/bin/env bash
# scripts/download-kokoro.sh
# Downloads the official full-precision v1.0 model and v1.0 voice bank.
set -euo pipefail
if [[ ! -f "scripts/kokoro_worker.py" ]]; then
  echo "Run this from the Echotext-rocky repository root." >&2
  exit 1
fi
mkdir -p kokoro
BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"
for NAME in kokoro-v1.0.onnx voices-v1.0.bin; do
  TARGET="kokoro/$NAME"
  if [[ -s "$TARGET" ]]; then
    echo "Preserving existing $TARGET"
    continue
  fi
  echo "Downloading $NAME from the kokoro-onnx release..."
  curl --fail --location --retry 3 --show-error \
    --output "$TARGET.partial" "$BASE/$NAME"
  mv "$TARGET.partial" "$TARGET"
done
echo "Downloaded assets:"
ls -lh kokoro/kokoro-v1.0.onnx kokoro/voices-v1.0.bin
sha256sum kokoro/kokoro-v1.0.onnx kokoro/voices-v1.0.bin
echo "Next: bash scripts/test-kokoro.sh"
