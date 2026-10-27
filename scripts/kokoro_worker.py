#!/usr/bin/env python3
# scripts/kokoro_worker.py
"""CPU-only Kokoro ONNX worker. Each stdin JSON line gets one stdout JSON line."""
from __future__ import annotations

import argparse
import contextlib
import json
import sys
from pathlib import Path


def language_for_voice(voice: str) -> str:
    return {
        "a": "en-us", "b": "en-gb", "e": "es", "f": "fr-fr",
        "h": "hi", "i": "it", "j": "ja", "p": "pt-br", "z": "zh"
    }.get(voice[:1].lower(), "en-us")


def respond(data: dict) -> None:
    print(json.dumps(data, ensure_ascii=False), flush=True)


def initialize(model_path: Path, voices_path: Path):
    if not model_path.is_file():
        raise FileNotFoundError(f"Missing ONNX model: {model_path}")
    if not voices_path.is_file():
        raise FileNotFoundError(f"Missing voices: {voices_path}")
    with contextlib.redirect_stdout(sys.stderr):
        import onnxruntime as ort
        import soundfile as sf
        from kokoro_onnx import Kokoro
        session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        engine = Kokoro.from_session(session, str(voices_path))
    return engine, sf


def synthesize(engine, sf, *, text: str, voice: str, speed: float, path: str):
    if not text.strip():
        raise ValueError("Text is empty")
    if not (0.5 <= speed <= 2.0):
        raise ValueError("Speed outside 0.5–2.0")
    if not path:
        raise ValueError("Output path is missing")
    if voice not in engine.get_voices():
        raise ValueError(f"Unknown voice: {voice}")
    target = Path(path).expanduser().resolve()
    if target.suffix.lower() != ".wav":
        raise ValueError("Expected a .wav output path")
    target.parent.mkdir(parents=True, exist_ok=True)
    with contextlib.redirect_stdout(sys.stderr):
        audio, sample_rate = engine.create(
            text, voice=voice, speed=speed, lang=language_for_voice(voice)
        )
        sf.write(str(target), audio, sample_rate, subtype="PCM_16")
    if target.stat().st_size <= 44:
        raise RuntimeError("Kokoro returned no audio")
    return {"path": str(target), "sample_rate": sample_rate, "bytes": target.stat().st_size}


def execute(engine, sf, req: dict) -> dict:
    req_id = req.get("id")
    try:
        if req.get("cmd") == "voices":
            return {"id": req_id, "ok": True, "voices": sorted(engine.get_voices())}
        if req.get("cmd", "synthesize") != "synthesize":
            raise ValueError("Unknown command")
        result = synthesize(
            engine, sf,
            text=str(req.get("text", "")),
            voice=str(req.get("voice", "af_heart")),
            speed=float(req.get("speed", 1.0)),
            path=str(req.get("path", "")),
        )
        return {"id": req_id, "ok": True, **result}
    except Exception as exc:
        return {"id": req_id, "ok": False, "error": f"{type(exc).__name__}: {exc}"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="kokoro/kokoro-v1.0.onnx")
    parser.add_argument("--voices", default="kokoro/voices-v1.0.bin")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--serve", action="store_true")
    mode.add_argument("--list-voices", action="store_true")
    mode.add_argument("--smoke-test", metavar="WAV_PATH")
    parser.add_argument("--voice", default="af_heart")
    args = parser.parse_args()

    try:
        engine, sf = initialize(Path(args.model), Path(args.voices))
        if args.list_voices:
            respond({"ok": True, "voices": sorted(engine.get_voices())})
            return 0
        if args.smoke_test is not None:
            result = execute(engine, sf, {
                "id": 1, "cmd": "synthesize", "path": args.smoke_test,
                "voice": args.voice, "text": "Hello from EchoText on Rocky Linux.",
            })
            respond(result)
            return 0 if result["ok"] else 1

        respond({"id": 0, "ok": True, "ready": True,
                 "voices": sorted(engine.get_voices())})
        for line in sys.stdin:
            if not line.strip():
                continue
            try:
                req = json.loads(line)
                if not isinstance(req, dict):
                    raise ValueError("Expected JSON object")
                respond(execute(engine, sf, req))
            except Exception as exc:
                respond({"id": None, "ok": False,
                         "error": f"{type(exc).__name__}: {exc}"})
        return 0
    except Exception as exc:
        print(f"Kokoro failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
