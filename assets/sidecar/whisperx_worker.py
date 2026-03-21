#!/usr/bin/env python3

import contextlib
import gc
import json
import platform
import re
import sys
import traceback
import wave
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import torch
import whisperx
from whisperx.vads.pyannote import Pyannote


SAMPLE_RATE = 16000
ANSI_ESCAPE_RE = re.compile(r"\x1B[@-_][0-?]*[ -/]*[@-~]")
LANGUAGES_WITHOUT_SPACES = {"ja", "zh"}
SENTENCE_END_PUNCTUATION = frozenset("。！？!?")
SOFT_BREAK_PUNCTUATION = frozenset("、，,;；")
CLOSING_PUNCTUATION = frozenset("」』】》）〕〉〟'\"”’")
JOIN_WITHOUT_LEADING_SPACE = frozenset(".,!?;:%)]}。，、！？：；％）」』】》〕〉〟'\"”’")
JOIN_WITHOUT_TRAILING_SPACE = frozenset("([{「『【《（〔〈〝'\"“‘$")
DEFAULT_SEGMENTATION_OPTIONS: Dict[str, Any] = {
    "split_on_pause": True,
    "pause_threshold_sec": 0.8,
    "max_segment_duration_sec": 6.0,
    "max_segment_chars": 42,
    "min_split_chars": 10,
    "prefer_punctuation_split": True,
}
NO_SPACE_LANGUAGE_SEGMENTATION_OPTIONS: Dict[str, Any] = {
    "pause_threshold_sec": 0.65,
    "max_segment_duration_sec": 4.5,
    "max_segment_chars": 28,
    "min_split_chars": 6,
}
JAPANESE_SEGMENTATION_OPTIONS: Dict[str, Any] = {
    "pause_threshold_sec": 0.55,
    "max_segment_duration_sec": 4.0,
    "max_segment_chars": 24,
    "min_split_chars": 4,
}
DEFAULT_WHISPERX_VAD_OPTIONS: Dict[str, Any] = {
    "chunk_size": 30,
    "vad_onset": 0.500,
    "vad_offset": 0.363,
}


def configure_stdio() -> None:
    # The Flutter side expects UTF-8 JSON lines on stdio. On Windows, Python can
    # otherwise inherit a legacy code page for piped stdout/stderr, which breaks
    # decoding when transcript text or library logs contain non-ASCII characters.
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            reconfigure(encoding="utf-8", errors="backslashreplace", line_buffering=True)


configure_stdio()
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


def to_optional_float(value: Any) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def to_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
        return default
    if value is None:
        return default
    return bool(value)


def normalize_options(raw_options: Any) -> Dict[str, Any]:
    if not isinstance(raw_options, dict):
        return {}

    normalized: Dict[str, Any] = {}
    for key, value in raw_options.items():
        if value is None:
            continue
        normalized[str(key)] = value
    return normalized


def normalize_device(value: Any, default: str = "cpu") -> str:
    device = str(value or default).strip().lower()
    return device or default


def ensure_mps_available() -> None:
    mps_backend = getattr(torch.backends, "mps", None)
    if mps_backend is None or not mps_backend.is_built():
        raise RuntimeError("This PyTorch build does not include MPS support.")
    if not mps_backend.is_available():
        raise RuntimeError("MPS is not available on this machine.")


def build_vad_model_options(vad_options: Dict[str, Any]) -> Dict[str, Any]:
    model_options: Dict[str, Any] = {}
    for key in ("vad_onset", "vad_offset"):
        if key in vad_options:
            model_options[key] = vad_options[key]
    return model_options


def build_effective_vad_options(
    vad_options: Dict[str, Any], use_custom_vad: bool
) -> Dict[str, Any]:
    if not use_custom_vad:
        return dict(vad_options)

    effective = dict(DEFAULT_WHISPERX_VAD_OPTIONS)
    effective.update(vad_options)
    return effective


def build_segmentation_options(
    language: Optional[str], override_options: Dict[str, Any]
) -> Dict[str, Any]:
    options: Dict[str, Any] = dict(DEFAULT_SEGMENTATION_OPTIONS)
    if language in LANGUAGES_WITHOUT_SPACES:
        options.update(NO_SPACE_LANGUAGE_SEGMENTATION_OPTIONS)
    if language == "ja":
        options.update(JAPANESE_SEGMENTATION_OPTIONS)
    options.update(override_options)
    return options


def should_apply_custom_segmentation(language: Optional[str]) -> bool:
    return language == "ja"


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


def normalize_word_entries(raw_words: Any, language: Optional[str]) -> List[Dict[str, Any]]:
    if not isinstance(raw_words, list):
        return []

    words: List[Dict[str, Any]] = []
    for item in raw_words:
        if not isinstance(item, dict):
            continue

        raw_text = str(item.get("word") or "")
        text = raw_text if language in LANGUAGES_WITHOUT_SPACES else raw_text.strip()
        if not text:
            continue

        words.append(
            {
                "word": text,
                "start": to_optional_float(item.get("start")),
                "end": to_optional_float(item.get("end")),
            }
        )

    return words


def join_words(words: List[Dict[str, Any]], language: Optional[str]) -> str:
    tokens = [str(item.get("word") or "") for item in words]
    if language in LANGUAGES_WITHOUT_SPACES:
        return "".join(tokens).strip()

    rendered = ""
    for token in tokens:
        text = token.strip()
        if not text:
            continue
        if not rendered:
            rendered = text
            continue
        if text[0] in JOIN_WITHOUT_LEADING_SPACE or rendered[-1] in JOIN_WITHOUT_TRAILING_SPACE:
            rendered += text
        else:
            rendered += f" {text}"
    return rendered.strip()


def effective_char_count(text: str, language: Optional[str]) -> int:
    if language in LANGUAGES_WITHOUT_SPACES:
        return len(text.replace(" ", "").replace("\u3000", ""))
    return len(text)


def ends_with_sentence_boundary(text: str) -> bool:
    trimmed = text.strip()
    while trimmed and trimmed[-1] in CLOSING_PUNCTUATION:
        trimmed = trimmed[:-1].rstrip()
    return bool(trimmed) and trimmed[-1] in SENTENCE_END_PUNCTUATION


def ends_with_soft_break(text: str) -> bool:
    trimmed = text.strip()
    while trimmed and trimmed[-1] in CLOSING_PUNCTUATION:
        trimmed = trimmed[:-1].rstrip()
    return bool(trimmed) and trimmed[-1] in SOFT_BREAK_PUNCTUATION


def is_punctuation_only(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False

    punctuation_chars = (
        SENTENCE_END_PUNCTUATION
        | SOFT_BREAK_PUNCTUATION
        | CLOSING_PUNCTUATION
        | JOIN_WITHOUT_LEADING_SPACE
        | JOIN_WITHOUT_TRAILING_SPACE
    )
    return all(ch in punctuation_chars for ch in stripped)


def is_closing_token(text: str) -> bool:
    stripped = text.strip()
    return bool(stripped) and all(ch in CLOSING_PUNCTUATION for ch in stripped)


def merge_text_parts(left: str, right: str, language: Optional[str]) -> str:
    left_text = left.strip()
    right_text = right.strip()
    if not left_text:
        return right_text
    if not right_text:
        return left_text
    if language in LANGUAGES_WITHOUT_SPACES:
        return f"{left_text}{right_text}".strip()
    if (
        right_text[0] in JOIN_WITHOUT_LEADING_SPACE
        or left_text[-1] in JOIN_WITHOUT_TRAILING_SPACE
    ):
        return f"{left_text}{right_text}"
    return f"{left_text} {right_text}"


def resolve_span(
    words: List[Dict[str, Any]], fallback_start: float, fallback_end: float
) -> Tuple[float, float]:
    start = fallback_start
    end = fallback_end

    for item in words:
        word_start = item.get("start")
        if isinstance(word_start, float):
            start = word_start
            break

    for item in reversed(words):
        word_end = item.get("end")
        if isinstance(word_end, float):
            end = word_end
            break

    if end < start:
        end = start
    return start, end


def gap_after_word(
    current_word: Dict[str, Any], next_word: Optional[Dict[str, Any]]
) -> Optional[float]:
    if next_word is None:
        return None

    end = current_word.get("end")
    start = next_word.get("start")
    if not isinstance(end, float) or not isinstance(start, float):
        return None

    return max(0.0, start - end)


def resolve_explicit_span(words: List[Dict[str, Any]]) -> Tuple[Optional[float], Optional[float]]:
    start: Optional[float] = None
    end: Optional[float] = None

    for item in words:
        word_start = item.get("start")
        if isinstance(word_start, float):
            start = word_start
            break

    for item in reversed(words):
        word_end = item.get("end")
        if isinstance(word_end, float):
            end = word_end
            break

    if start is not None and end is not None and end < start:
        end = start
    return start, end


def build_segment_from_words(
    words: List[Dict[str, Any]],
    language: Optional[str],
    fallback_start: float,
    fallback_end: float,
    allow_fallback: bool = True,
) -> Optional[Dict[str, Any]]:
    text = join_words(words, language)
    if not text:
        return None

    start, end = resolve_explicit_span(words)
    if start is None or end is None:
        if not allow_fallback:
            return None
        start, end = resolve_span(words, fallback_start, fallback_end)

    return {
        "start": start,
        "end": end,
        "text": text,
    }


def should_commit_immediately(break_reason: str) -> bool:
    return break_reason == "sentence"


def classify_safe_break(
    text: str,
    current_word: Dict[str, Any],
    next_word: Optional[Dict[str, Any]],
    current_char_count: int,
    split_on_pause: bool,
    prefer_punctuation_split: bool,
    pause_threshold: float,
    min_split_chars: int,
) -> Optional[str]:
    if next_word is None or current_char_count < min_split_chars:
        return None

    next_text = str(next_word.get("word") or "")
    if (
        prefer_punctuation_split
        and not is_closing_token(next_text)
        and ends_with_sentence_boundary(text)
    ):
        return "sentence"

    if not is_closing_token(next_text) and ends_with_soft_break(text):
        return "soft"

    if split_on_pause:
        gap = gap_after_word(current_word, next_word)
        if gap is not None and gap >= pause_threshold:
            return "pause"

    return None


def find_segment_end_index(
    words: List[Dict[str, Any]],
    segment_start: int,
    language: Optional[str],
    fallback_start: float,
    fallback_end: float,
    split_on_pause: bool,
    prefer_punctuation_split: bool,
    pause_threshold: float,
    max_duration: float,
    max_chars: int,
    min_split_chars: int,
) -> int:
    last_safe_break: Optional[int] = None

    for index in range(segment_start, len(words)):
        current_words = words[segment_start : index + 1]
        current_text = join_words(current_words, language)
        if not current_text:
            continue

        current_char_count = effective_char_count(current_text, language)
        next_word = words[index + 1] if index + 1 < len(words) else None
        break_reason = classify_safe_break(
            current_text,
            words[index],
            next_word,
            current_char_count,
            split_on_pause,
            prefer_punctuation_split,
            pause_threshold,
            min_split_chars,
        )

        if break_reason is not None:
            candidate = build_segment_from_words(
                current_words,
                language,
                fallback_start,
                fallback_end,
                allow_fallback=False,
            )
            if candidate is not None and not is_punctuation_only(candidate["text"]):
                last_safe_break = index + 1
                if should_commit_immediately(break_reason):
                    return index + 1

        current_start, current_end = resolve_span(
            current_words, fallback_start, fallback_end
        )
        current_duration = max(0.0, current_end - current_start)
        has_hit_limit = (
            current_char_count >= max_chars or current_duration >= max_duration
        )
        if has_hit_limit and last_safe_break is not None:
            return last_safe_break

    return len(words)


def segment_duration(segment: Dict[str, Any]) -> float:
    return max(
        0.0,
        to_float(segment.get("end"), 0.0) - to_float(segment.get("start"), 0.0),
    )


def segment_gap(left: Dict[str, Any], right: Dict[str, Any]) -> float:
    return to_float(right.get("start"), 0.0) - to_float(left.get("end"), 0.0)


def has_suspicious_timing(segment: Dict[str, Any], language: Optional[str]) -> bool:
    text = str(segment.get("text") or "").strip()
    chars = effective_char_count(text, language)
    duration = segment_duration(segment)
    if chars <= 0:
        return True
    if is_punctuation_only(text):
        return duration >= 0.5
    if chars <= 2 and duration >= 2.5:
        return True
    return False


def merge_segments(
    base: Dict[str, Any],
    extra: Dict[str, Any],
    language: Optional[str],
    include_timing: bool,
) -> Dict[str, Any]:
    merged = {
        "start": to_float(base.get("start"), 0.0),
        "end": to_float(base.get("end"), 0.0),
        "text": merge_text_parts(
            str(base.get("text") or ""),
            str(extra.get("text") or ""),
            language,
        ),
    }
    if include_timing:
        merged["start"] = min(
            merged["start"], to_float(extra.get("start"), merged["start"])
        )
        merged["end"] = max(merged["end"], to_float(extra.get("end"), merged["end"]))
    return merged


def should_merge_into_previous(
    previous: Dict[str, Any],
    current: Dict[str, Any],
    language: Optional[str],
    min_split_chars: int,
) -> bool:
    text = str(current.get("text") or "").strip()
    if not text:
        return True

    chars = effective_char_count(text, language)
    duration = segment_duration(current)
    gap = segment_gap(previous, current)
    previous_text = str(previous.get("text") or "").strip()

    if is_punctuation_only(text):
        return True
    if has_suspicious_timing(current, language):
        return True
    if (
        chars <= 2
        and duration <= 0.2
        and gap <= 0.2
        and previous_text
        and not ends_with_sentence_boundary(previous_text)
    ):
        return True
    if (
        chars < min_split_chars
        and gap <= 0.05
        and previous_text
        and not ends_with_sentence_boundary(previous_text)
    ):
        return True
    if gap < -0.05 and chars <= max(2, min_split_chars):
        return True
    return False


def repair_split_segments(
    segments: List[Dict[str, Any]],
    language: Optional[str],
    segmentation_options: Dict[str, Any],
) -> List[Dict[str, Any]]:
    min_split_chars = max(
        1,
        to_int(segmentation_options.get("min_split_chars"), 4),
    )
    repaired: List[Dict[str, Any]] = []
    pending_prefix: Optional[Dict[str, Any]] = None

    for raw_segment in normalize_segments(segments):
        segment = {
            "start": to_float(raw_segment.get("start"), 0.0),
            "end": to_float(raw_segment.get("end"), 0.0),
            "text": str(raw_segment.get("text") or "").strip(),
        }
        if not segment["text"]:
            continue

        if pending_prefix is not None:
            if has_suspicious_timing(pending_prefix, language):
                segment["text"] = merge_text_parts(
                    str(pending_prefix.get("text") or ""),
                    segment["text"],
                    language,
                )
            else:
                segment = merge_segments(
                    pending_prefix,
                    segment,
                    language,
                    include_timing=True,
                )
            pending_prefix = None

        if not repaired:
            if is_punctuation_only(segment["text"]) or has_suspicious_timing(
                segment, language
            ):
                pending_prefix = segment
                continue
            repaired.append(segment)
            continue

        previous = repaired[-1]
        if should_merge_into_previous(previous, segment, language, min_split_chars):
            repaired[-1] = merge_segments(
                previous,
                segment,
                language,
                include_timing=not has_suspicious_timing(segment, language),
            )
            continue

        repaired.append(segment)

    if pending_prefix is not None:
        if repaired:
            if has_suspicious_timing(pending_prefix, language):
                repaired[-1]["text"] = merge_text_parts(
                    repaired[-1]["text"],
                    str(pending_prefix.get("text") or ""),
                    language,
                )
            else:
                repaired[-1] = merge_segments(
                    repaired[-1],
                    pending_prefix,
                    language,
                    include_timing=True,
                )
        else:
            repaired.append(pending_prefix)

    return normalize_segments(repaired)


def split_segment_by_words(
    raw_segment: Dict[str, Any],
    language: Optional[str],
    segmentation_options: Dict[str, Any],
) -> List[Dict[str, Any]]:
    start = to_float(raw_segment.get("start"), 0.0)
    end = to_float(raw_segment.get("end"), start)
    text = str(raw_segment.get("text") or "").strip()
    if not text:
        return []

    words = normalize_word_entries(raw_segment.get("words"), language)
    if not words:
        return [
            {
                "start": start,
                "end": end if end >= start else start,
                "text": text,
            }
        ]

    split_on_pause = to_bool(segmentation_options.get("split_on_pause"), True)
    prefer_punctuation_split = to_bool(
        segmentation_options.get("prefer_punctuation_split"), True
    )
    pause_threshold = max(
        0.0, to_float(segmentation_options.get("pause_threshold_sec"), 0.8)
    )
    max_duration = max(
        0.5, to_float(segmentation_options.get("max_segment_duration_sec"), 6.0)
    )
    max_chars = max(1, to_int(segmentation_options.get("max_segment_chars"), 42))
    min_split_chars = max(
        1,
        min(
            max_chars,
            to_int(segmentation_options.get("min_split_chars"), min(max_chars, 10)),
        ),
    )

    split_segments: List[Dict[str, Any]] = []
    segment_start = 0

    while segment_start < len(words):
        segment_end = find_segment_end_index(
            words,
            segment_start,
            language,
            start,
            end,
            split_on_pause,
            prefer_punctuation_split,
            pause_threshold,
            max_duration,
            max_chars,
            min_split_chars,
        )
        if segment_end <= segment_start:
            segment_end = segment_start + 1

        allow_fallback = segment_start == 0 and segment_end == len(words)
        segment = build_segment_from_words(
            words[segment_start:segment_end],
            language,
            start,
            end,
            allow_fallback=allow_fallback,
        )
        if segment is not None:
            split_segments.append(segment)
        segment_start = segment_end

    return split_segments or [{"start": start, "end": end, "text": text}]


def normalize_transcript_segments(
    raw_segments: Any,
    language: Optional[str],
    segmentation_options: Dict[str, Any],
) -> List[Dict[str, Any]]:
    if not isinstance(raw_segments, list):
        return []

    split_segments: List[Dict[str, Any]] = []
    for item in raw_segments:
        if not isinstance(item, dict):
            continue
        split_segments.extend(
            split_segment_by_words(item, language, segmentation_options)
        )

    return repair_split_segments(split_segments, language, segmentation_options)


class WhisperXWorker:
    def __init__(self) -> None:
        self.models: Dict[
            Tuple[str, str, str, str, Optional[str], str, str], Any
        ] = {}
        self.vad_models: Dict[Tuple[str, str], Any] = {}
        self.align_models: Dict[Tuple[str, str], Tuple[Any, Dict[str, Any]]] = {}

    def clear_device_resources(self, device: Optional[str] = None) -> None:
        if device is None:
            self.models.clear()
            self.vad_models.clear()
            self.align_models.clear()
        else:
            self.models = {
                key: value
                for key, value in self.models.items()
                if key[1] != device and key[2] != device
            }
            self.vad_models = {
                key: value for key, value in self.vad_models.items() if key[0] != device
            }
            self.align_models = {
                key: value
                for key, value in self.align_models.items()
                if key[1] != device
            }

        gc.collect()

        try:
            if device in (None, "cuda") and torch.cuda.is_available():
                torch.cuda.empty_cache()
            if device in (None, "mps"):
                empty_cache = getattr(getattr(torch, "mps", None), "empty_cache", None)
                if callable(empty_cache):
                    empty_cache()
        except Exception:
            return

    def get_vad_model(self, device: str, vad_options: Dict[str, Any]) -> Any:
        device = normalize_device(device)
        model_options = build_vad_model_options(vad_options)
        key = (
            device,
            json.dumps(model_options, sort_keys=True, ensure_ascii=False),
        )
        if key in self.vad_models:
            return self.vad_models[key]

        if device == "cuda":
            self.clear_device_resources(device="cuda")
        elif device == "mps":
            ensure_mps_available()

        model = Pyannote(torch.device(device), **model_options)
        self.vad_models[key] = model
        return model

    def get_model(
        self,
        model_name: str,
        asr_device: str,
        compute_type: str,
        language: Optional[str],
        asr_options: Dict[str, Any],
        vad_options: Dict[str, Any],
        vad_device: Optional[str] = None,
    ) -> Any:
        resolved_vad_device = normalize_device(vad_device, asr_device)
        use_custom_vad = resolved_vad_device != asr_device
        effective_vad_options = build_effective_vad_options(
            vad_options, use_custom_vad
        )
        key = (
            model_name,
            asr_device,
            resolved_vad_device,
            compute_type,
            language,
            json.dumps(asr_options, sort_keys=True, ensure_ascii=False),
            json.dumps(effective_vad_options, sort_keys=True, ensure_ascii=False),
        )
        if key in self.models:
            return self.models[key]

        if asr_device == "cuda" or resolved_vad_device == "cuda":
            self.clear_device_resources(device="cuda")

        load_kwargs: Dict[str, Any] = {
            "compute_type": compute_type,
            "language": language,
            "asr_options": asr_options,
        }
        if effective_vad_options:
            load_kwargs["vad_options"] = effective_vad_options
        if use_custom_vad:
            load_kwargs["vad_model"] = self.get_vad_model(
                resolved_vad_device, effective_vad_options
            )

        model = whisperx.load_model(
            model_name,
            asr_device,
            **load_kwargs,
        )
        self.models[key] = model
        return model

    def get_align_model(self, language: str, device: str) -> Tuple[Any, Dict[str, Any]]:
        device = normalize_device(device)
        key = (language, device)
        if key in self.align_models:
            return self.align_models[key]

        if device == "cuda":
            self.align_models = {
                cached_key: value
                for cached_key, value in self.align_models.items()
                if cached_key[1] != "cuda"
            }
            self.clear_device_resources(device="cuda")
        elif device == "mps":
            ensure_mps_available()

        model, metadata = whisperx.load_align_model(
            language_code=language,
            device=device,
        )
        self.align_models[key] = (model, metadata)
        return model, metadata

    def handle_probe_runtime(self, request_id: str) -> None:
        payload: Dict[str, Any] = {
            "platform": platform.system().lower(),
            "python_version": sys.version.split()[0],
            "whisperx_version": str(getattr(whisperx, "__version__", "")),
            "cuda_available": False,
            "cuda_device_count": 0,
            "cuda_device_name": None,
            "cuda_compute_types": [],
            "mps_built": False,
            "mps_available": False,
        }

        try:
            payload["torch_version"] = str(getattr(torch, "__version__", ""))
            payload["torch_cuda_version"] = getattr(torch.version, "cuda", None)
            payload["cuda_available"] = bool(torch.cuda.is_available())
            if payload["cuda_available"]:
                device_count = int(torch.cuda.device_count())
                payload["cuda_device_count"] = device_count
                if device_count > 0:
                    payload["cuda_device_name"] = str(torch.cuda.get_device_name(0))
            mps_backend = getattr(torch.backends, "mps", None)
            if mps_backend is not None:
                payload["mps_built"] = bool(mps_backend.is_built())
                payload["mps_available"] = bool(mps_backend.is_available())
        except Exception as exc:  # pylint: disable=broad-except
            payload["torch_error"] = str(exc)

        try:
            import ctranslate2

            payload["ctranslate2_version"] = str(
                getattr(ctranslate2, "__version__", "")
            )
            try:
                compute_types = ctranslate2.get_supported_compute_types("cuda")
                payload["cuda_compute_types"] = sorted(
                    str(item) for item in compute_types
                )
            except Exception as exc:  # pylint: disable=broad-except
                payload["ctranslate2_cuda_error"] = str(exc)
        except Exception as exc:  # pylint: disable=broad-except
            payload["ctranslate2_error"] = str(exc)

        emit({"type": "result", "id": request_id, "payload": payload})

    def handle_transcribe(self, request_id: str, params: Dict[str, Any]) -> None:
        wav_path = str(params.get("wav_path") or "")
        if not wav_path:
            raise ValueError("Missing wav_path")

        model_name = str(params.get("model") or "small")
        language = params.get("language")
        language = str(language) if language else None
        device = normalize_device(params.get("device"), "cpu")
        asr_device = normalize_device(params.get("asr_device"), device)
        vad_device = normalize_device(params.get("vad_device"), asr_device)
        align_device = normalize_device(params.get("align_device"), asr_device)
        compute_type = str(params.get("compute_type") or "int8")
        batch_size = int(params.get("batch_size") or 4)
        no_align = to_bool(params.get("no_align"), False)
        asr_options = normalize_options(params.get("asr_options"))
        vad_options = normalize_options(params.get("vad_options"))
        segmentation_overrides = normalize_options(params.get("segmentation_options"))

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
                asr_device=asr_device,
                compute_type=compute_type,
                language=language,
                asr_options=asr_options,
                vad_options=vad_options,
                vad_device=vad_device,
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
        if asr_device == "cuda" or vad_device == "cuda":
            del model
            self.clear_device_resources(device="cuda")

        detected_language = str(result.get("language") or language or "unknown")
        normalized_segments = normalize_segments(result.get("segments"))

        if not no_align and normalized_segments:
            emit_status(request_id, "aligning")
            emit_progress(request_id, 72)
            align_model, align_metadata = self.get_align_model(
                detected_language, align_device
            )
            align_logs = ProgressLogStream(request_id)
            with contextlib.redirect_stdout(
                align_logs
            ), contextlib.redirect_stderr(align_logs):
                aligned = whisperx.align(
                    result["segments"],
                    align_model,
                    align_metadata,
                    audio,
                    align_device,
                    return_char_alignments=False,
                    print_progress=True,
                )
            align_logs.flush()
            if align_device == "cuda":
                del align_model
                self.clear_device_resources(device="cuda")
            detected_language = str(aligned.get("language") or detected_language)
            if should_apply_custom_segmentation(detected_language):
                segmentation_options = build_segmentation_options(
                    detected_language, segmentation_overrides
                )
                normalized_segments = normalize_transcript_segments(
                    aligned.get("segments"),
                    detected_language,
                    segmentation_options,
                )
            else:
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
        if (
            asr_device == "cuda"
            or vad_device == "cuda"
            or align_device == "cuda"
        ):
            self.clear_device_resources(device="cuda")

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

        if method == "probe_runtime":
            self.handle_probe_runtime(request_id)
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
