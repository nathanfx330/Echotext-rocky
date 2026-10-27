#!/usr/bin/env bash
# scripts/download-kokoro.sh
# Downloads and verifies official full-precision Kokoro v1.0 assets.
# SHA-256 digests are from the model-files-v1.1 GitHub release metadata.
set -euo pipefail
if [[ ! -f "scripts/kokoro_worker.py" ]]; then
  echo "Run this from the Echotext-rocky repository root." >&2
  exit 1
fi
mkdir -p kokoro
BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"

for NAME in kokoro-v1.0.onnx voices-v1.0.bin; do
  case "$NAME" in
    kokoro-v1.0.onnx) EXPECTED="beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a" ;;
    voices-v1.0.bin) EXPECTED="bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d" ;;
  esac
  TARGET="kokoro/$NAME"

  if [[ -s "$TARGET" ]]; then
    echo "Verifying existing $TARGET..."
    echo "$EXPECTED  $TARGET" | sha256sum --check --status || {
      echo "SHA-256 mismatch in $TARGET; not overwriting it." >&2
      exit 1
    }
    echo "$TARGET: verified"
    continue
  fi

  echo "Downloading $NAME from the official Kokoro ONNX release..."
  curl --fail --location --retry 3 --show-error \
    --output "$TARGET.partial" "$BASE/$NAME"
  echo "$EXPECTED  $TARGET.partial" | sha256sum --check --status || {
    echo "SHA-256 mismatch in downloaded $TARGET.partial" >&2
    rm -f "$TARGET.partial"
    exit 1
  }
  mv "$TARGET.partial" "$TARGET"
  echo "$TARGET: verified and installed"
done

ls -lh kokoro/kokoro-v1.0.onnx kokoro/voices-v1.0.bin
echo "Model and voice bank SHA-256: PASS"
echo "Next: bash scripts/test-kokoro.sh"
