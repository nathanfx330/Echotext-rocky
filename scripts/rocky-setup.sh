#!/usr/bin/env bash
# scripts/rocky-setup.sh
set -euo pipefail
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  case "${ID:-}" in
    rocky|rhel|almalinux|centos|fedora) ;;
    *) echo "Warning: intended for Rocky/RHEL-family Linux (detected: ${ID:-unknown})." >&2 ;;
  esac
fi
# No system Piper install, CUDA, NVIDIA driver updates or container runtime.
sudo dnf install -y git curl unzip xz file findutils \
  clang cmake ninja-build gcc-c++ pkgconf-pkg-config gtk3-devel \
  gstreamer1-devel gstreamer1-plugins-base-devel \
  gstreamer1-plugins-base gstreamer1-plugins-good
echo "Prerequisites installed. Flutter SDK and the existing CPU Piper runtime are separate."
