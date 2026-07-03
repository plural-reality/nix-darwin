#!/usr/bin/env python3
"""Stop hook: block unverified completion claims after file edits.

Self-check:
  python3 scripts/claude/stop-verify-gate.py --self-check

Contract:
  - Fail open on malformed hook input or transcript parsing errors.
  - Fire at most once per session.
  - Block only when edit/write tools were used, no verification command appears,
    and the latest assistant text claims completion.
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
VERIFY_RE = re.compile(
    r"("
    r"\bnix\s+flake\s+check\b|"
    r"\b(bun|npm|pnpm|yarn)\s+(run\s+)?(test|typecheck|lint|build)\b|"
    r"\b(bun|pytest|shellcheck)\s+test\b|"
    r"\bpython3?\s+-m\s+(pytest|unittest|py_compile)\b|"
    r"\b(cargo|go)\s+test\b|"
    r"\b(test|typecheck|lint|build)\b"
    r")",
    re.IGNORECASE,
)
DONE_RE = re.compile(
    r"(完了|できました|出来ました|直りました|修正しました|実装しました|"
    r"作成しました|追加しました|コミットしました|通りました|done|fixed|complete|completed)",
    re.IGNORECASE,
)
REASON = "完了主張の前に検証コマンドを実行せよ"
MARKER_DIR = Path(os.path.expanduser("~/.claude/.cache/stop-verify-gate"))


def text_blocks(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    return ""


def transcript_signals(path: Path) -> tuple[bool, bool, str]:
    edited = False
    verified = False
    last_assistant = ""
    with path.open(encoding="utf-8", errors="replace") as lines:
        for line in lines:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") != "assistant":
                continue
            message = obj.get("message") or {}
            content = message.get("content")
            text = text_blocks(content)
            if text:
                last_assistant = text
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name = str(block.get("name", ""))
                edited = edited or name in EDIT_TOOLS
                if name == "Bash":
                    command = str((block.get("input") or {}).get("command", ""))
                    verified = verified or bool(VERIFY_RE.search(command))
    return edited, verified, last_assistant


def should_block(payload: dict[str, object]) -> bool:
    transcript = Path(str(payload.get("transcript_path") or ""))
    if payload.get("stop_hook_active") or not transcript.exists():
        return False
    edited, verified, last_text = transcript_signals(transcript)
    return edited and not verified and bool(DONE_RE.search(last_text))


def marker_path(session_id: str) -> Path:
    return MARKER_DIR / (session_id or "unknown")


def run(payload: dict[str, object]) -> int:
    session_id = str(payload.get("session_id") or "unknown")
    marker = marker_path(session_id)
    if marker.exists() or not should_block(payload):
        return 0
    MARKER_DIR.mkdir(parents=True, exist_ok=True)
    marker.write_text("fired\n", encoding="utf-8")
    print(REASON, file=sys.stderr)
    return 2


def self_check() -> int:
    assistant_edit = {
        "type": "assistant",
        "message": {
            "content": [
                {"type": "tool_use", "name": "Edit", "input": {"file_path": "x"}},
                {"type": "text", "text": "修正しました。完了です。"},
            ]
        },
    }
    assistant_verify = {
        "type": "assistant",
        "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {"command": "nix flake check"}}]},
    }
    with tempfile.TemporaryDirectory() as tmp:
        transcript = Path(tmp) / "session.jsonl"
        transcript.write_text(json.dumps(assistant_edit, ensure_ascii=False) + "\n", encoding="utf-8")
        assert should_block({"transcript_path": str(transcript)})
        transcript.write_text(
            json.dumps(assistant_edit, ensure_ascii=False)
            + "\n"
            + json.dumps(assistant_verify, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )
        assert not should_block({"transcript_path": str(transcript)})
    print("ok")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-check"]:
        return self_check()
    try:
        payload = json.load(sys.stdin)
        return run(payload if isinstance(payload, dict) else {})
    except Exception:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
