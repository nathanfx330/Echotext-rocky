#!/usr/bin/env bash
# scripts/install-piper-cpu.sh
# Install the original, pre-GPL Piper x86_64 CPU CLI into this project.
set -euo pipefail

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "This Piper archive is for x86_64 only." >&2
  exit 1
fi
if [[ -e piper/piper ]]; then
  echo "Existing piper/piper found. Not overwriting it." >&2
  exit 1
fi
command -v curl >/dev/null || { echo "curl missing" >&2; exit 1; }
command -v tar >/dev/null || { echo "tar missing" >&2; exit 1; }

url="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

echo "Downloading the original Piper CPU CLI from its official GitHub release..."
curl --fail --location --retry 2 --show-error --silent \
  --output "$temp_dir/piper.tar.gz" "$url"
if ! tar -tzf "$temp_dir/piper.tar.gz" | grep -Fx 'piper/piper' >/dev/null; then
  echo "Unexpected archive structure; refusing to extract." >&2
  exit 1
fi

mkdir -p piper
tar -xzf "$temp_dir/piper.tar.gz" --strip-components=1 --no-same-owner -C piper
chmod +x piper/piper
echo
echo "Downloaded Piper into the local piper/ directory."
echo "Checking shared libraries (Rocky 8 compatibility is not guaranteed):"
ldd piper/piper || true
echo
echo "Next: place your .onnx and .onnx.json voice files under model/"
echo "Then run: bash scripts/smoke-test-piper.sh"
