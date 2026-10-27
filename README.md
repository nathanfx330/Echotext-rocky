# EchoText Rocky

## Favorite Kokoro voices

Open **Settings → Voice** to browse and search the Kokoro voice bank.
Use the star next to any voice in the picker, or star the current voice
directly from Settings. Favorites always sort to the top, and **Starred only**
filters the list. Favorites persist in SharedPreferences under
`kokoro_favorite_voices` (stored as stable Kokoro voice IDs). On a fresh
installation, `af_heart` starts starred; removing it stays removed after
restarting. This feature does not change voice model files or the Conda runtime.

## Kokoro migration: CPU-only runtime stage (Rocky 8.10)

The primary TTS engine is now **Kokoro ONNX**. The original Piper service file
remains in the repository as a possible future fallback but is not selected by
the current UI.

From the repository root:

    git pull
    bash scripts/setup-kokoro.sh
    bash scripts/download-kokoro.sh
    bash scripts/test-kokoro.sh

This uses a dedicated **Conda environment named `echotext-kokoro`** with Python 3.12. Packages are installed through `conda run -n echotext-kokoro python -m pip`, never through system Python, base Conda, or standalone venv. It requires no sudo, system Python upgrade, or NVIDIA/CUDA installation.
See [the detailed Kokoro guide](docs/KOKORO.md).

**Status:** Full-quality Kokoro CPU synthesis and matching eSpeak NG
library/data **were verified by a real user playback test on Rocky 8.10**.
The Flutter integration has now been committed but **has not yet passed a
Rocky Flutter build/runtime test**. The persistent Python worker, voice list,
sentence playback, and WAV/SRT pipeline are connected in source.

### First run of the Kokoro-connected Flutter application

From your `Echotext-rocky` directory with the existing
`echotext-kokoro` Conda environment installed:

```bash
git pull
bash scripts/run-dev.sh
```

Try reading a sentence, switching the Kokoro voice, and exporting a short
paragraph with Audio + SRT. For a release build, run
`bash scripts/build.sh`; its bundle copies `scripts/kokoro_worker.py`
and your local `kokoro/` model files. The Conda environment stays external.

If the app cannot locate Conda Python, set `ECHOTEXT_KOKORO_PYTHON` to the
**Conda environment's** `bin/python` binary. If launched from an unusual
working directory, set `ECHOTEXT_KOKORO_ROOT` to the project or bundle root.


---


A separate, **CPU-only Rocky Linux desktop port** of [EchoText](https://github.com/nathanfx330/Echotext), based on the source as of `cd8b583` (April 24, 2026). The original repository has not been changed.

Preserves: Flutter text editor, read-along highlighting, sentence jumping, Kokoro voice selection, cleanup tools, WAV export and sentence-aligned SRT subtitles.

### Targets and constraints

- **Rocky Linux 8.10**, x86_64, matching the development workstation; build and runtime confirmation require a real Rocky machine. Rocky 9/10 may also work but are not the current target.
- Flutter Linux desktop SDK providing Dart **3.11.3+** (the upstream `pubspec.yaml` requirement).
- **Original CPU Piper CLI** compatible with `--json-input` and `--output_file`; *not* an arbitrary newer Piper release.
- No CUDA, NVIDIA toolkit, GPU toggle or driver changes.
- Only Linux, Flutter app, test, and auxiliary reader files are carried over; mobile/Windows/macOS shells are deliberately omitted.

### Get started (from repository root)

```bash
bash scripts/rocky-setup.sh
bash scripts/diagnose.sh
```

The setup installs build/audio development packages using `sudo dnf` and **may upgrade already-installed system packages**, as DNF did on the initial Rocky 8.10 test. Run it only when needed. It does **not** install Flutter, Piper or NVIDIA/CUDA dependencies. The tested Rocky machine already has Flutter 3.44.6 and Dart 3.12.2.

### Install the original CPU Piper runtime locally

The original Piper project has an archived Linux x86_64 CPU distribution. Install it into the repository's local `piper/` directory (no system-wide installation):

```bash
bash scripts/install-piper-cpu.sh
bash scripts/diagnose.sh
```

This installer uses the official [Piper 2023.11.14-2 release](https://github.com/rhasspy/piper/releases/tag/2023.11.14-2). On Rocky 8, its ELF/shared-library compatibility **still must be checked** with `ldd` and synthesis. If it fails, do not replace the system glibc: we'll build a CPU-compatible Piper on Rocky 8 instead. You can also provide your already-working Piper directory instead of downloading a new copy.

### Use your existing voices

Neither Piper nor voice models are kept in Git. Copy a known-working original CPU Piper runtime, including its shipped shared libraries and `espeak-ng-data`, and your existing voices into:

```text
piper/
  piper
  lib/                  # if present in distribution
  espeak-ng-data/
model/
  my_voice/
    voice.onnx
    voice.onnx.json
```

Models directly inside `model/` are supported too. Keep each `.onnx.json` beside its `.onnx`. You may also set `ECHOTEXT_PIPER` and `ECHOTEXT_MODEL_DIR` to point to an external executable or model directory.

The initial Rocky diagnostics found **no models** in `model/`. Locate your existing models (e.g., `find "$HOME" -type f -name '*.onnx' -print`) and copy each model and its JSON config under `model/`, or set `ECHOTEXT_MODEL_DIR` to the containing folder.

```bash
chmod +x piper/piper
bash scripts/diagnose.sh
bash scripts/smoke-test-piper.sh
```

The smoke test generates a short temporary WAV using **CPU synthesis** and deletes it when finished. A successful `ldd` by itself does not prove synthesis works. If you encounter `GLIBC_...` or `lib*.so not found` errors, use a Rocky-compatible CPU Piper build instead of replacing the system glibc.

### Run and build

```bash
bash scripts/run-dev.sh
bash scripts/build.sh
```

Release artifact: `build/linux/x64/release/bundle/echotext`. The build bundles the contents of `piper/` and `model/` when supplied before release compilation. A source-only build without local voices cannot speak until you add them.

### Differences from upstream

- GPU option removed from settings and no `--cuda` CLI flag is passed.
- Older saved GPU preferences ignored.
- Local Piper library paths are passed only to Piper's child process, not to the system.
- Model scanning supports a direct `model/*.onnx` voice, in addition to one-level folders.
- First checkout can compile without a bundled Piper executable or models.
- Rocky dependency installer and explicit diagnostics/synthesis smoke test.
- Replaces the upstream Flutter template's stale counter widget test with actual text utility tests.

### Status and provenance

Source has been ported for Rocky 8.10. The CI workflow targets `rockylinux:8` and Flutter 3.44.6. **No successful Rocky compilation or Piper execution is asserted.** Run the diagnostics, smoke test, and Flutter tests on your Rocky workstation to verify native dependencies.

EchoText upstream is MIT licensed, copyright (c) 2026 Nathaniel Westveer.
