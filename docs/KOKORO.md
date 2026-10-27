# Kokoro CPU runtime on Rocky Linux 8.10

This document covers the **current, working Kokoro engine** used by
EchoText Rocky. The user confirmed successful Kokoro speech synthesis
and playback inside the Flutter desktop application.

## Tested environment

- Rocky Linux 8.10, x86_64, glibc 2.28
- Intel Xeon E5-2667 v4, AVX2, 62 GiB RAM
- Flutter 3.44.6 and Dart 3.12.2
- Conda-managed Python 3.12 (`echotext-kokoro`)
- `kokoro-onnx==0.6.1` with CPU ONNX Runtime 1.23.2
- `kokoro-v1.0.onnx` full-precision model and `voices-v1.0.bin`
- Rocky's eSpeak NG 1.49.2 shared library with its matching system data

This is a validated configuration on one Rocky 8 workstation.
Actual inference, intelligible WAV output, and Flutter GUI playback
were tested. The remaining application-level check is long-document
narration and exported WAV/SRT timing in a Resolve timeline.

## Setup (Conda only)

From the project root:

```bash
bash scripts/setup-kokoro.sh
bash scripts/download-kokoro.sh
bash scripts/test-kokoro.sh
bash scripts/run-dev.sh
```

`setup-kokoro.sh` creates or reuses the dedicated
`echotext-kokoro` Conda environment with Python 3.12. It installs pip
packages only by calling `conda run -n echotext-kokoro python -m pip`.
It verifies the interpreter's Conda prefix before the pip step.
It never installs packages into system Python or Conda `base`.

`download-kokoro.sh` fetches the full-precision ONNX model and voice
bank into `kokoro/`. Models and voices are not committed to Git.

`test-kokoro.sh` saves a PCM, 24 kHz, mono WAV
(`kokoro_test.wav`) in the current project directory. It refuses to
overwrite an existing test WAV unless you explicitly choose another
output with `KOKORO_TEST_WAV` or set
`KOKORO_OVERWRITE_TEST=1`.

If the application is already working, no reinstall or new downloads
are needed. Simply run `git pull` and `bash scripts/run-dev.sh`.

## Rocky 8 eSpeak NG compatibility

During initial testing the `espeakng-loader` wheel's embedded
`libespeak-ng.so` required `GLIBC_2.29`, but Rocky 8 ships glibc
2.28. The fallback system shared library then printed
`Bad rules data in 'en_dict'` because the phonemizer paired
incompatible library and dictionary versions.

The worker was changed to select the **same-version library and
pronunciation-data directory together**. On the tested machine it uses:

```text
/usr/lib64/libespeak-ng.so.1
/usr/share/espeak-ng-data
```

After this change the smoke test generated audio without either
previous error, and the user confirmed the speech sounded correct.

Inspect local paths without changing the system:

```bash
bash scripts/diagnose-espeak.sh
```

If autodetection fails, set **both**
`ECHOTEXT_ESPEAK_LIB` and `ECHOTEXT_ESPEAK_DATA` to a matching
library/data pair. Do not replace system glibc or mix the bundled
pronunciation files with an older shared library.

## How Flutter talks to Kokoro

`lib/services/kokoro_service.dart` launches
`scripts/kokoro_worker.py` with the Python interpreter from the
**dedicated Conda environment**. The worker loads the ONNX model
and voice bank once, explicitly chooses `CPUExecutionProvider`,
then communicates with Flutter over JSON Lines.

Supported worker messages include:

```json
{"id":1,"cmd":"voices"}
{"id":2,"cmd":"synthesize","text":"Hello from EchoText.","voice":"af_heart","speed":1.0,"path":"/tmp/narration.wav"}
```

The worker responds with voice IDs or the WAV path, sample rate, and
byte count (or an error). EchoText plays sentence WAVs, precaches
the next sentence, and can stitch the outputs into a narration WAV
with a sentence-aligned SRT.

For direct inspection, the worker can be launched using:

```bash
conda run --no-capture-output -n echotext-kokoro python -u scripts/kokoro_worker.py --serve
```

The app is Kokoro-first. The old Piper service source is retained
for possible future fallback, but is not used by the current UI.
Voice favorites, including the initial `af_heart` star, are
stored in Flutter SharedPreferences.

## Build and packaging

```bash
bash scripts/build.sh
```

The Linux bundle includes the worker script and installed Kokoro
model files, but **not** the Conda Python interpreter or packages.
The target machine needs its own compatible
`echotext-kokoro` environment.

For paths outside the normal checkout, the Flutter service accepts
`ECHOTEXT_KOKORO_ROOT` and `ECHOTEXT_KOKORO_PYTHON`.

## References

- [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx)
- [Kokoro ONNX release models](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1)
- [Example synthesis code](https://github.com/thewh1teagle/kokoro-onnx/blob/main/examples/save.py)
