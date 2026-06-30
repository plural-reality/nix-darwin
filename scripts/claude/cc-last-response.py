#!/usr/bin/env python3
"""Extract the last assistant text response from the current Claude Code session."""

import json
import os
import sys
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude" / "projects"

def find_latest_jsonl() -> Path | None:
    candidates = sorted(
        CLAUDE_DIR.rglob("*.jsonl"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return candidates[0] if candidates else None

def extract_last_assistant_text(path: Path) -> str | None:
    last_text = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("type") != "assistant":
                continue
            content = d.get("message", {}).get("content", [])
            texts = (
                [c["text"] for c in content if isinstance(c, dict) and c.get("type") == "text"]
                if isinstance(content, list)
                else []
            )
            if texts:
                last_text = "\n".join(texts)
    return last_text

def main():
    path = find_latest_jsonl()
    if not path:
        print("No conversation found", file=sys.stderr)
        sys.exit(1)
    text = extract_last_assistant_text(path)
    if not text:
        print("No assistant response found", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(text)

if __name__ == "__main__":
    main()
