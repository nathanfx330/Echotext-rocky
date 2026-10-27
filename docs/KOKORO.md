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

The setup creates .venv-kokoro with the existing python3.12 (not the
/usr/bin/python3 3.6.8 interpreter), and installs only CPU ONNX Runtime.
No sudo, no dnf, no CUDA, no modification to base Conda, and no changes
to DaVinci Resolve. If venv is unavailable, create a local Conda prefix
with Python 3.12 and pip, then rerun setup.

The download fetches the full-precision 326 MB kokoro-v1.0.onnx model
and 28 MB voices-v1.0.bin voice bank from the official model-files-v1.1
release. Both are excluded from Git and preserved on repeated runs.

The test generates a temporary PCM 16-bit WAV and deletes it afterward.
Success requires importing the Python packages, loading ONNX + voices,
performing CPU inference, and writing a nonempty file.

## Integration: not done yet

The initial scripts/kokoro_worker.py implements a persistent JSON-lines
process with commands "voices" and "synthesize". This avoids reloading
the ONNX model for every sentence.

Next: implement Dart KokoroService lifecycle, integrate into Flutter,
preserve highlighting, sentence navigation, WAV/SRT export, and add
an engine/voice selection setting. Piper stays optional and isolated.

## Primary sources

- https://github.com/thewh1teagle/kokoro-onnx/blob/main/pyproject.toml
- https://github.com/thewh1teagle/kokoro-onnx/blob/main/examples/save.py
- https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1
