#!/usr/bin/env python3

import contextlib
import json
import re
import sys
import traceback
import wave
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import whisperx


SAMPLE_RATE = 16000
ANSI_ESCAPE_RE = re.compile(r"\x1B[@-_][0-?]*[ -/]*[@-~]")
JSON_STDOUT = sys.stdout


def emit(message: Dict[str, Any]) -> None:
    JSON_STDOUT.write(json.dumps(message, ensure_ascii=False) + "\n")
    JSON_STDOUT.flush()


def emit_progress(request_id: str, progress: int) -> None:
    emit(
        {
            "type": "progress",
            "id": request_id,
            "progress": max(0, min(100, int(progress))),
        }
    )


def emit_status(request_id: str, status: str, detail: Optional[str] = None) -> None:
    payload: Dict[str, Any] = {
        "type": "status",
        "id": request_id,
        "status": status,
    }
    if detail:
        payload["detail"] = detail
    emit(payload)


def emit_log(request_id: str, line: str) -> None:
    emit(
        {
            "type": "log",
            "id": request_id,
            "line": line,
        }
    )


class ProgressLogStream:
    def __init__(self, request_id: str) -> None:
        self._request_id = request_id
        self._buffer = ""
        self._last_line: Optional[str] = None

    def write(self, data: Any) -> int:
        text = str(data)
        if not text:
            return 0
        self._buffer += text
        self._drain()
        return len(text)

    def flush(self) -> None:
        if not self._buffer:
            return
        self._emit_line(self._buffer)
        self._buffer = ""

    def isatty(self) -> bool:
        return False

    @property
    def encoding(self) -> str:
        return "utf-8"

    def _drain(self) -> None:
        start = 0
        for index, ch in enumerate(self._buffer):
            if ch == "\r" or ch == "\n":
                part = self._buffer[start:index]
                self._emit_line(part)
                start = index + 1
        self._buffer = self._buffer[start:]

    def _emit_line(self, raw: str) -> None:
        line = ANSI_ESCAPE_RE.sub("", raw).strip()
        if not line:
            return
        if line == self._last_line:
            return
        self._last_line = line
        emit_log(self._request_id, line)


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_wav_pcm_s16le(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wav_file:
        channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        sample_rate = wav_file.getframerate()
        frames = wav_file.readframes(wav_file.getnframes())

    if channels != 1:
        raise ValueError(f"Expected mono WAV, got channels={channels}")
    if sample_width != 2:
        raise ValueError(f"Expected 16-bit PCM WAV, got sample_width={sample_width}")
    if sample_rate != SAMPLE_RATE:
        raise ValueError(
            f"Expected {SAMPLE_RATE}Hz WAV, got sample_rate={sample_rate}"
        )

    audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    return audio


def normalize_segments(raw_segments: Any) -> List[Dict[str, Any]]:
    if not isinstance(raw_segments, list):
        return []

    segments: List[Dict[str, Any]] = []
    for item in raw_segments:
        if not isinstance(item, dict):
            continue

        start = to_float(item.get("start"), 0.0)
        end = to_float(item.get("end"), start)
        text = str(item.get("text") or "").strip()
        if not text:
            continue

        if end < start:
            end = start

        segments.append(
            {
                "start": start,
                "end": end,
                "text": text,
            }
        )

    return segments


class WhisperXWorker:
    def __init__(self) -> None:
        self.models: Dict[Tuple[str, str, str, Optional[str]], Any] = {}
        self.align_models: Dict[Tuple[str, str], Tuple[Any, Dict[str, Any]]] = {}

    def get_model(
        self,
        model_name: str,
        device: str,
        compute_type: str,
        language: Optional[str],
    ) -> Any:
        key = (model_name, device, compute_type, language)
        if key in self.models:
            return self.models[key]

        model = whisperx.load_model(
            model_name,
            device,
            compute_type=compute_type,
            language=language,
        )
        self.models[key] = model
        return model

    def get_align_model(self, language: str, device: str) -> Tuple[Any, Dict[str, Any]]:
        key = (language, device)
        if key in self.align_models:
            return self.align_models[key]

        model, metadata = whisperx.load_align_model(
            language_code=language,
            device=device,
        )
        self.align_models[key] = (model, metadata)
        return model, metadata

    def handle_transcribe(self, request_id: str, params: Dict[str, Any]) -> None:
        wav_path = str(params.get("wav_path") or "")
        if not wav_path:
            raise ValueError("Missing wav_path")

        model_name = str(params.get("model") or "small")
        language = params.get("language")
        language = str(language) if language else None
        device = str(params.get("device") or "cpu")
        compute_type = str(params.get("compute_type") or "int8")
        batch_size = int(params.get("batch_size") or 4)
        no_align = bool(params.get("no_align") or False)

        emit_status(request_id, "loading_audio")
        emit_progress(request_id, 8)
        audio = load_wav_pcm_s16le(wav_path)

        emit_status(request_id, "preparing_model")
        emit_progress(request_id, 20)
        model_logs = ProgressLogStream(request_id)
        with contextlib.redirect_stdout(model_logs), contextlib.redirect_stderr(
            model_logs
        ):
            model = self.get_model(
                model_name=model_name,
                device=device,
                compute_type=compute_type,
                language=language,
            )
        model_logs.flush()

        emit_status(request_id, "transcribing")
        emit_progress(request_id, 35)
        transcribe_logs = ProgressLogStream(request_id)
        with contextlib.redirect_stdout(
            transcribe_logs
        ), contextlib.redirect_stderr(transcribe_logs):
            result = model.transcribe(
                audio,
                batch_size=batch_size,
                print_progress=True,
                verbose=False,
            )
        transcribe_logs.flush()

        detected_language = str(result.get("language") or language or "unknown")
        normalized_segments = normalize_segments(result.get("segments"))

        if not no_align and normalized_segments:
            emit_status(request_id, "aligning")
            emit_progress(request_id, 72)
            align_model, align_metadata = self.get_align_model(detected_language, device)
            align_logs = ProgressLogStream(request_id)
            with contextlib.redirect_stdout(
                align_logs
            ), contextlib.redirect_stderr(align_logs):
                aligned = whisperx.align(
                    result["segments"],
                    align_model,
                    align_metadata,
                    audio,
                    device,
                    return_char_alignments=False,
                    print_progress=True,
                )
            align_logs.flush()
            detected_language = str(aligned.get("language") or detected_language)
            normalized_segments = normalize_segments(aligned.get("segments"))

        emit_status(request_id, "finalizing")
        emit_progress(request_id, 96)
        payload = {
            "language": detected_language,
            "duration_sec": float(len(audio)) / float(SAMPLE_RATE),
            "segments": normalized_segments,
        }
        emit_progress(request_id, 100)
        emit(
            {
                "type": "result",
                "id": request_id,
                "payload": payload,
            }
        )

    def dispatch(self, message: Dict[str, Any]) -> None:
        request_id = str(message.get("id") or "")
        method = str(message.get("method") or "")
        params = message.get("params")
        if not isinstance(params, dict):
            params = {}

        if not request_id:
            return

        if method == "transcribe":
            self.handle_transcribe(request_id, params)
            return

        if method == "shutdown":
            emit({"type": "result", "id": request_id, "payload": {"ok": True}})
            raise SystemExit(0)

        raise ValueError(f"Unknown method: {method}")


def main() -> None:
    worker = WhisperXWorker()
    emit({"type": "ready"})

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            decoded = json.loads(line)
            if not isinstance(decoded, dict):
                continue

            worker.dispatch(decoded)
        except SystemExit:
            return
        except Exception as exc:  # pylint: disable=broad-except
            request_id = ""
            try:
                maybe_msg = json.loads(line)
                if isinstance(maybe_msg, dict):
                    request_id = str(maybe_msg.get("id") or "")
            except Exception:
                request_id = ""

            emit(
                {
                    "type": "error",
                    "id": request_id,
                    "message": str(exc),
                    "trace": traceback.format_exc(),
                }
            )


if __name__ == "__main__":
    main()
