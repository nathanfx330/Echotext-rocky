# EchoText Rocky

A separate, **CPU-only Rocky Linux desktop port** of [EchoText](https://github.com/nathanfx330/Echotext), based on the source as of `cd8b583` (April 24, 2026). The original repository has not been changed.

Preserves: Flutter text editor, read-along highlighting, local Piper synthesis, sentence jumping, voice selection, cleanup tools, WAV export and aligned SRT subtitles.

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
