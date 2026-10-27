# EchoText Rocky

**Offline, CPU-only text-to-speech for Rocky Linux, powered by Kokoro ONNX.**

[EchoText Rocky](https://github.com/nathanfx330/Echotext-rocky) is a separate
Linux desktop port of the original [EchoText](https://github.com/nathanfx330/Echotext)
Flutter application. The original repository is unchanged.

Kokoro is the **active speech engine**. Piper code is retained only as a
legacy fallback for future development; the current UI does not use it.

## Features

- Full-quality Kokoro voices, synthesized locally on the CPU
- Persistent Python worker: loads the model once for sentence playback
- Read-along highlighting, read from cursor, and sentence navigation
- Search, editing, undo, and text-cleanup tools
- Save narration as PCM WAV, optionally with sentence-aligned SRT subtitles
- Searchable Kokoro voice picker with **starred favorites** and a
  **Starred only** filter
- Favorite voices and reading settings saved between launches
- Lossless sentence splitting for decimals, URLs, abbreviations, closing quotes, ordinal dates, and Unicode ellipses
- Adjustable additional silence (300 ms between sentences, 650 ms for blank-line paragraphs by default)
- Restart engine action if the Python worker exits unexpectedly

SRT timestamps are derived from generated sentence audio. They are not
word-level forced alignment and should be checked in an editor for final use.

## Verified status

- **Rocky Linux 8.10 on x86_64:** Full-precision Kokoro speech was generated
  and heard on the actual workstation, using ONNX Runtime's CPU provider.
- **Phonemizer:** The worker selected Rocky's eSpeak NG library together
  with the matching system dictionary, eliminating the earlier
  `GLIBC_2.29` / `en_dict` incompatibility.
- **Flutter GUI:** The user confirmed that Kokoro played successfully
  through the desktop application.
- **CI:** GitHub Actions' Rocky 8 container completed Flutter analysis,
  tests, and a desktop release build on the Kokoro integration and
  subsequent Favorites update.
- **Still to verify on a real project:** Long-document handling and
  sentence-aligned WAV/SRT export imported into DaVinci Resolve.

These confirmations cover the Rocky workstation and CI configuration used
during development; they are not a blanket guarantee for other distributions
or arbitrary Conda/Python versions.

## Requirements

- Rocky Linux 8.10, x86_64 (the tested target)
- A working Flutter Linux desktop SDK with Dart 3.11.3 or later
- Conda
- A local `echotext-kokoro` Conda environment containing Python 3.12
  and CPU-only Kokoro dependencies
- The `kokoro-v1.0.onnx` model and `voices-v1.0.bin` voice bank
- eSpeak NG shared library **and matching pronunciation data**
- GTK/GStreamer desktop dependencies for the Flutter application

The successful workstation used an Intel Xeon E5-2667 v4, glibc 2.28,
Flutter 3.44.6, and Python 3.12.13 inside Conda.

**No CUDA, NVIDIA SDK, GPU flag, glibc replacement, or changes to system
Python are necessary.** Never install Python packages in the system
interpreter or Conda `base` for this project.

## Install and run

Run commands from the **repository root**. If you've already installed the
Kokoro environment and downloaded the models, skip the setup and download
steps and just run the app.

```bash
bash scripts/setup-kokoro.sh
bash scripts/download-kokoro.sh
bash scripts/test-kokoro.sh
bash scripts/run-dev.sh
```

- `setup-kokoro.sh` creates or reuses the dedicated Conda environment
  `echotext-kokoro` and runs pip **only inside that environment**.
- `download-kokoro.sh` downloads the full-quality Kokoro ONNX model and
  voice bank to the ignored `kokoro/` folder and verifies both official SHA-256 digests (including previously downloaded files).
- `test-kokoro.sh` generates `kokoro_test.wav` for listening, and will
  **not overwrite** an existing test file by default. For a new smoke test,
  set `KOKORO_TEST_WAV` to a different filename.
- `run-dev.sh` launches the Flutter GUI. It does not install or activate
  a Python environment itself. The app locates the dedicated Conda
  interpreter when launching its child process.

For a returning checkout:

```bash
git pull
bash scripts/run-dev.sh
```

### Voice favorites

Open **Settings → Voice** to browse or search the available Kokoro voices.
Click a voice to select it, or click its **star** to favorite it without
changing the active voice. Starred voices sort first. Use **Starred only**
to display your shortlist.

On first use, `af_heart` is starred by default. Preferences are saved
under the `kokoro_favorite_voices` key in SharedPreferences, using stable
Kokoro voice IDs. If you unstar all voices, the list stays empty after
relaunching.

### WAV and SRT for DaVinci Resolve

The sentence and paragraph pause controls are in Settings. These pauses are
**additional** to Kokoro's natural silence. The export writes silence into
the WAV before the following sentence and adjusts SRT timestamps accordingly.
Paragraph boundaries require a blank line in the text.

Paste narration, then use **Save Audio** and select **Audio + SRT**.
Import the exported WAV as audio and SRT as subtitles in Resolve. This
provides sentence-level navigation and a starting point for editing the
narration. Check the timing and text against the audio before delivery.

### Language support

The verified narration workflow is English. Japanese and Chinese voices
currently use the worker's eSpeak phoneme path rather than a dedicated
Misaki G2P path; pronunciation quality is not validated for those languages.

### Release build

```bash
bash scripts/build.sh
```

Release executable:
`build/linux/x64/release/bundle/echotext`.

The Linux bundle includes the Kokoro worker script and, if present at
build time, the local `kokoro/` model and voice files. **It does not
bundle Python or the Conda environment.** The target machine must have
the `echotext-kokoro` environment installed separately.

For unusual installations or bundle launch paths, set:

- `ECHOTEXT_KOKORO_PYTHON`: the dedicated Conda environment's
  `bin/python`, not system Python
- `ECHOTEXT_KOKORO_ROOT`: project or release-bundle root containing
  `scripts/kokoro_worker.py` and `kokoro/`
- `ECHOTEXT_ESPEAK_LIB` and `ECHOTEXT_ESPEAK_DATA`: **both** paths
  for a matching eSpeak NG shared library and dictionary data, if the
  autodetection cannot locate a compatible pair

See [the Kokoro runtime guide](docs/KOKORO.md) for diagnostics and the
Rocky 8 phonemizer fix.

## Rocky native setup (only if needed)

A workstation that already builds and launches EchoText does **not** need
to rerun the native setup script.

```bash
bash scripts/diagnose.sh
```

`scripts/rocky-setup.sh` installs GTK, GStreamer, and build dependencies
using **sudo dnf**, and **may upgrade existing system packages**. It was
needed during the initial port, but is not part of normal Kokoro runtime
setup. Review it before using it on a working Resolve workstation.

## Legacy Piper fallback (not active)

The port initially carried forward the original Piper CPU engine.
`lib/services/piper_service.dart` and related diagnostic and installation
scripts remain in the repository for reference. **The current Flutter UI
uses Kokoro, not Piper**, and Piper assets are not required to launch it.

Developers working on a future optional Piper fallback can use:

- `scripts/install-piper-cpu.sh` for the old Piper CLI archive
- `scripts/smoke-test-piper.sh` to check an installed Piper runtime
- `piper/` for the legacy executable and its private libraries
- `model/` for Piper `.onnx` voice files and adjacent `.onnx.json`
  configurations

Piper's models are **not interchangeable** with Kokoro's `kokoro-v1.0.onnx`
and `voices-v1.0.bin`. The old Piper binaries still require their own
Rocky compatibility checks. Do not modify system glibc to make them run.

## Provenance and license

EchoText Rocky was initially ported from the upstream EchoText source
revision `cd8b583` (April 24, 2026), then migrated to Kokoro ONNX.
The original repository has not been changed by the Rocky work.

EchoText Rocky is published under the [MIT License](LICENSE).
Copyright (c) 2026 Nathaniel Westveer.

Kokoro, Flutter, and other third-party components retain their own licenses
and attribution requirements.
