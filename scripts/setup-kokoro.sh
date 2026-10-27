#!/usr/bin/env bash
# scripts/setup-kokoro.sh
# Kokoro packages are installed ONLY within the named Conda environment.
set -euo pipefail

if [[ ! -f "scripts/kokoro_worker.py" ]]; then
  echo "Run from the Echotext-rocky repository root." >&2
  exit 1
fi
if ! command -v conda >/dev/null 2>&1; then
  echo "Conda is not available. No packages were installed." >&2
  exit 1
fi

ENV_NAME="echotext-kokoro"
if conda env list | awk -v name="$ENV_NAME" '$1 == name {found=1} END {exit !found}'; then
  echo "Using existing Conda environment: $ENV_NAME"
else
  echo "Creating dedicated Conda environment: $ENV_NAME"
  conda create -y -n "$ENV_NAME" python=3.12 pip
fi

# Fail closed unless the interpreter is actually inside the named Conda env.
conda run --no-capture-output -n "$ENV_NAME" python -c \
  'import os,sys; prefix=os.environ.get("CONDA_PREFIX",""); assert prefix and sys.executable.startswith(prefix + "/"), "Not inside the target Conda environment"; assert sys.version_info[:2] == (3,12), "Expected Python 3.12"; print("Verified Conda environment:", prefix); print("Interpreter:",sys.executable)'

echo "Installing CPU-only Kokoro dependencies INSIDE $ENV_NAME (never base)..."
conda run --no-capture-output -n "$ENV_NAME" python -m pip install \
  "kokoro-onnx==0.6.1" "onnxruntime==1.23.2" \
  "espeakng-loader==0.2.4" "soundfile==0.14.0"

conda run --no-capture-output -n "$ENV_NAME" python -c \
  'import kokoro_onnx,onnxruntime,soundfile,espeakng_loader; assert "CPUExecutionProvider" in onnxruntime.get_available_providers(); print("Kokoro CPU dependencies: PASS"); print("ONNX providers:", onnxruntime.get_available_providers())'

echo "Ready. Next: bash scripts/download-kokoro.sh"
