# EchoText Rocky

A separate, **CPU-only Rocky Linux desktop port** of [EchoText](https://github.com/nathanfx330/Echotext), based on the source as of `cd8b583` (April 24, 2026). The original repository has not been changed.

Preserves: Flutter text editor, read-along highlighting, local Piper synthesis, sentence jumping, voice selection, cleanup tools, WAV export and aligned SRT subtitles.

### Targets and constraints

- Rocky Linux 9 or 10, x86_64; build and runtime confirmation require a real Rocky machine.
- Flutter Linux desktop SDK providing Dart **3.11.3+** (the upstream `pubspec.yaml` requirement).
- **Original CPU Piper CLI** compatible with `--json-input` and `--output_file`; *not* an arbitrary newer Piper release.
- No CUDA, NVIDIA toolkit, GPU toggle or driver changes.
- Only Linux, Flutter app, test, and auxiliary reader files are carried over; mobile/Windows/macOS shells are deliberately omitted.

### Get started (from repository root)

```bash
bash scripts/rocky-setup.sh
bash scripts/diagnose.sh
```

The setup installs basic build/audio development packages using `sudo dnf`. It does **not** install Flutter, Piper or NVIDIA/CUDA dependencies. Install or update Flutter separately if `flutter --version` lacks the required Dart SDK.

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

Source and CI-independent checks have been prepared. **No successful Rocky compilation or Piper execution is asserted.** Run the diagnostics, smoke test, and Flutter tests on your Rocky workstation to verify native dependencies.

EchoText upstream is MIT licensed, copyright (c) 2026 Nathaniel Westveer.
