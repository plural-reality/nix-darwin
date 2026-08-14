#!/usr/bin/env python3
"""Small dependency-free check for the Codex shared-memory projection."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "codex-shared-memory-context.py"
SPEC = importlib.util.spec_from_file_location("codex_shared_memory_context", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def main() -> None:
    raw = (("日本語 pointer " * 40 + "\n") * 250).encode()
    bounded = MODULE.bounded_index(raw)
    chunks = [MODULE.utf8_chunk(raw, index) for index in range(MODULE.CHUNK_COUNT)]
    payload = MODULE.hook_output(raw, 0)
    assert len(bounded.encode()) <= MODULE.MAX_BYTES
    assert len(bounded.splitlines()) <= MODULE.MAX_LINES
    assert all(len(chunk.encode()) <= MODULE.CHUNK_BYTES for chunk in chunks)
    assert "".join(chunks) == bounded
    assert payload is not None
    assert payload["hookSpecificOutput"]["hookEventName"] == "SessionStart"
    assert chunks[0] in payload["hookSpecificOutput"]["additionalContext"]
    assert MODULE.hook_output(b"", 0) is None


if __name__ == "__main__":
    main()
