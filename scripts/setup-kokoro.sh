#!/usr/bin/env bash
# scripts/setup-kokoro.sh
# Isolate all Kokoro dependencies; do not modify Rocky system Python or Conda.
set -euo pipefail
if [[ ! -f "scripts/kokoro_worker.py" ]]; then
  echo "Run this from the Echotext-rocky repository root." >&2
  exit 1
fi
PYBIN="python3.12"
ENV_DIR=".venv-kokoro"
if ! command -v "$PYBIN" >/dev/null 2>&1; then
  echo "Python 3.12 is missing. This setup expects the existing /usr/bin/python3.12." >&2
  exit 1
fi
echo "Using $("$PYBIN" --version) from $(command -v "$PYBIN")"
if [[ ! -x "$ENV_DIR/bin/python" ]]; then
  if ! "$PYBIN" -m venv "$ENV_DIR"; then
    echo "Rocky Python lacks venv/ensurepip. Alternative: conda create -p .venv-kokoro python=3.12 pip" >&2
    echo "Then rerun this script. No system-wide Python change is necessary." >&2
    exit 1
  fi
fi
"$ENV_DIR/bin/python" -m pip install --upgrade pip
"$ENV_DIR/bin/python" -m pip install \
  "kokoro-onnx==0.6.1" "onnxruntime==1.23.2" \
  "espeakng-loader==0.2.4" "soundfile==0.14.0"
"$ENV_DIR/bin/python" -c "import kokoro_onnx, onnxruntime, soundfile, espeakng_loader; print('Kokoro imports: PASS'); print('ONNX providers:', onnxruntime.get_available_providers()); assert 'CPUExecutionProvider' in onnxruntime.get_available_providers()"
echo
echo "Python dependencies ready without CUDA. Next: bash scripts/download-kokoro.sh"
