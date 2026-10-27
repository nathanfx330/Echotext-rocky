#!/usr/bin/env bash
# scripts/test-kokoro.sh
# Verify CPU-only WAV synthesis in the dedicated Conda environment.
set -euo pipefail
ENV_NAME="echotext-kokoro"
command -v conda >/dev/null 2>&1 || { echo "Conda required; run setup first." >&2; exit 1; }
conda run -n "$ENV_NAME" python -c 'import kokoro_onnx' >/dev/null || {
  echo "Kokoro is not installed in Conda environment $ENV_NAME." >&2
  echo "Run: bash scripts/setup-kokoro.sh" >&2
  exit 1
}
if [[ ! -s "kokoro/kokoro-v1.0.onnx" || ! -s "kokoro/voices-v1.0.bin" ]]; then
  echo "Missing Kokoro models. Run: bash scripts/download-kokoro.sh" >&2
  exit 1
fi
OUT="${KOKORO_TEST_WAV:-kokoro_test.wav}"
if [[ -e "$OUT" && -z "${KOKORO_OVERWRITE_TEST:-}" ]]; then
  echo "Refusing to overwrite existing $OUT. Set KOKORO_TEST_WAV to a new filename." >&2
  exit 1
fi
conda run --no-capture-output -n "$ENV_NAME" python \
  scripts/kokoro_worker.py --smoke-test "$OUT"
test -s "$OUT"
file "$OUT"
echo "Kokoro CPU synthesis: PASS ($ENV_NAME)"
echo "Listen to your test: $OUT"
