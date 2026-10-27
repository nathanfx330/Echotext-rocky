# Kokoro on Rocky Linux 8.10

## Runtime compatibility and stage

Development machine (Oct 26, 2026): Rocky Linux 8.10, glibc 2.28,
Intel Xeon E5-2667 v4 (AVX2), 62 GiB RAM, Python 3.12.13 and 3.11.13,
Conda installed, Flutter 3.44.6 / Dart 3.12.2.
No Python or graphics driver changes are required.

The Kokoro ONNX 0.6.1 Python package requires Python >=3.10,<3.14.
ONNX Runtime 1.23.2 publishes x86_64 CPython 3.12 wheels tagged for
glibc 2.27/2.28, and espeakng-loader 0.2.4 has a compatible manylinux
wheel. These are package compatibility claims, not a successful Rocky
runtime test.

## CPU-only smoke test (from project root)

    git pull
    bash scripts/setup-kokoro.sh
    bash scripts/download-kokoro.sh
    bash scripts/test-kokoro.sh

The setup uses **Conda exclusively for environment management**. It creates
(or reuses) a dedicated named environment, `echotext-kokoro`, containing
Python 3.12 and pip. Python packages are installed **only** by executing
`conda run -n echotext-kokoro python -m pip install ...`. The script
verifies the interpreter's Conda prefix before installation, so pip is never
run in the Rocky system Python or Conda base. No sudo, dnf, CUDA or
changes to DaVinci Resolve.

The download fetches the full-precision 326 MB kokoro-v1.0.onnx model
and 28 MB voices-v1.0.bin voice bank from the official model-files-v1.1
release. Both are excluded from Git and preserved on repeated runs.

The test generates a PCM 16-bit WAV as `kokoro_test.wav` in the project directory for listening.
Success requires importing the Python packages, loading ONNX + voices,
performing CPU inference, and writing a nonempty file.

## Integration: not done yet

The initial scripts/kokoro_worker.py implements a persistent JSON-lines
process with commands "voices" and "synthesize". This avoids reloading
the ONNX model for every sentence. Run it from the dedicated Conda environment:

    conda run --no-capture-output -n echotext-kokoro python -u scripts/kokoro_worker.py --serve

Flutter integration must launch the interpreter from this same Conda
environment. Do not use `/usr/bin/python3` or assume Conda base.

Next: implement Dart KokoroService lifecycle, integrate into Flutter,
preserve highlighting, sentence navigation, WAV/SRT export, and add
an engine/voice selection setting. Piper stays optional and isolated.

## Primary sources

- https://github.com/thewh1teagle/kokoro-onnx/blob/main/pyproject.toml
- https://github.com/thewh1teagle/kokoro-onnx/blob/main/examples/save.py
- https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1

## Environment policy

Do not install Kokoro packages into `base`, the Rocky system Python, or a standalone `venv`. All Python package actions belong in the `echotext-kokoro` Conda environment. Earlier `.venv-kokoro` setup instructions have been superseded.

## Rocky 8 phonemizer fix (after first real WAV test)

The first live test did produce 24 kHz mono audio, but the bundled `espeakng-loader` library required `GLIBC_2.29`, unavailable on Rocky 8 (glibc 2.28). Kokoro automatically fell back to a system library while still using incompatible bundled pronunciation data, producing `Bad rules data in 'en_dict'`.

The worker now selects a matching eSpeak NG shared library **and its associated dictionary folder** rather than silently mixing them. It **fails closed** if it cannot find a safe pair. It checks the Conda environment first, then installed Rocky paths. For unusual installations, set *both* `ECHOTEXT_ESPEAK_LIB` and `ECHOTEXT_ESPEAK_DATA` to the correct pair. Never change system glibc.

From the repository root:

```bash
git pull
bash scripts/diagnose-espeak.sh
bash scripts/test-kokoro.sh
```

A successful test now saves `kokoro_test.wav` in the current project directory rather than immediately deleting it, so the phoneme quality can be checked by listening. It will not overwrite an existing WAV without an explicit `KOKORO_TEST_WAV` name or `KOKORO_OVERWRITE_TEST=1`. If the diagnostic doesn't find a matching eSpeak NG library + data, report the output; we can install/build the pair **within the dedicated Conda environment**, not system wide.
