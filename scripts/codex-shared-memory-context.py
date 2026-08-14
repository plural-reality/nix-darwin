#!/usr/bin/env python3
"""Project Claude's canonical memory index into a Codex SessionStart hook."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


MAX_BYTES = 25 * 1024
MAX_LINES = 200
CHUNK_BYTES = 8 * 1024
CHUNK_COUNT = 4
PREFIX = """共有メモリの正本は Claude auto-memory です。以下は索引だけです。
このターンの依頼に関係する pointer があれば、回答や操作の前に同じディレクトリの対象 topic file だけを再読込してください。
Codex native memory を共有メモリの正本として扱わず、共有 memory の更新は self-learn skill 経由で Claude canonical store へ行ってください。

--- canonical MEMORY.md index ---
"""


def bounded_index(raw: bytes) -> str:
    """Return the earliest limit of 200 lines or 25 KiB, as UTF-8 text."""
    line_bounded = b"".join(raw.splitlines(keepends=True)[:MAX_LINES])
    return line_bounded[:MAX_BYTES].decode("utf-8", errors="ignore")


def utf8_chunk(raw: bytes, chunk_index: int) -> str:
    """Return one UTF-8-safe chunk below Codex's per-hook output limit."""
    text = bounded_index(raw)
    chunks = [text]
    while len(chunks[-1].encode("utf-8")) > CHUNK_BYTES:
        encoded = chunks.pop().encode("utf-8")
        split_at = min(CHUNK_BYTES, len(encoded))
        while split_at > 0 and (encoded[split_at] & 0xC0) == 0x80:
            split_at -= 1
        chunks.extend(
            [
                encoded[:split_at].decode("utf-8", errors="strict"),
                encoded[split_at:].decode("utf-8", errors="strict"),
            ]
        )
    return chunks[chunk_index] if chunk_index < len(chunks) else ""


def hook_output(raw: bytes, chunk_index: int) -> dict[str, object] | None:
    """Pure transform: canonical index bytes -> one SessionStart hook payload."""
    index = utf8_chunk(raw, chunk_index)
    if not index:
        return None
    return {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": f"{PREFIX}part {chunk_index + 1}/{CHUNK_COUNT}\n{index}",
        }
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-index", type=Path, required=True)
    parser.add_argument("--chunk-index", type=int, choices=range(CHUNK_COUNT), required=True)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        raw = args.memory_index.read_bytes()
    except OSError:
        return 0
    payload = hook_output(raw, args.chunk_index)
    if payload is None:
        return 0
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
