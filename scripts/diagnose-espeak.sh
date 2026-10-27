#!/usr/bin/env bash
# scripts/diagnose-espeak.sh
# Read-only investigation of actual eSpeak library/data installed on Rocky.
set -u
echo "== RPM packages =="
rpm -q espeak-ng espeak espeak-ng-libs 2>&1 || true
echo
echo "== Shared libraries found by dynamic linker =="
ldconfig -p 2>/dev/null | grep -E 'libespeak(-ng)?[.]so' || true
echo
echo "== Actual eSpeak NG libraries and dictionary data =="
for root in /usr/lib64 /lib64 /usr/local/lib64 "${CONDA_PREFIX:-}/lib"; do
  if [[ -d "$root" ]]; then
    find "$root" -maxdepth 1 \( -name 'libespeak-ng.so*' -o -name 'libespeak.so*' \) -print 2>/dev/null
  fi
done
for data in /usr/share/espeak-ng-data /usr/local/share/espeak-ng-data "${CONDA_PREFIX:-}/share/espeak-ng-data" "${CONDA_PREFIX:-}/share/espeak-ng/espeak-ng-data"; do
  if [[ -d "$data" ]]; then
    echo "DATA: $data"
    if [[ -f "$data/en_dict" ]]; then echo "  en_dict: present"; else echo "  en_dict: MISSING"; fi
    if [[ -f "$data/phontab" ]]; then echo "  phontab: present"; else echo "  phontab: MISSING"; fi
  fi
done
echo
echo "== Conda environment =="
conda run --no-capture-output -n echotext-kokoro python -c \
 'import os,espeakng_loader; print("CONDA_PREFIX:",os.environ.get("CONDA_PREFIX")); print("Bundled library:",espeakng_loader.get_library_path()); print("Bundled data:",espeakng_loader.get_data_path())' 2>&1 || true
