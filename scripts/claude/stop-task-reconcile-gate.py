#!/usr/bin/env python3
"""Stop hook: block stopping while created tasks remain open (pending/in_progress).

Reconstructs task state from the session transcript by replaying TaskCreate
results (which assign "Task #N created successfully: <subject>") and TaskUpdate
inputs ({taskId, status}). Blocks ONCE per session if any created task's latest
status is pending or in_progress, nudging to mark them completed/deleted (or to
state an intentional deferral, after which the next Stop passes through).

Rationale: the harness only *reminds* about stale tasks (non-blocking); that soft
signal was empirically ignored, leaving the task tracker out of sync with reality.
This gate makes the reconcile step non-optional exactly once.

Self-check:
  python3 scripts/claude/stop-task-reconcile-gate.py --self-check

Contract:
  - Fail open on malformed input / parse errors (never wedge Stop).
  - Fire at most once per session (loud gate; the second Stop passes through).
  - stop_hook_active guard prevents re-entrancy loops.
  - Authoritative source is the replay of TaskUpdate inputs (last write wins), not
    the injected "existing tasks" reminder blocks (those go stale after later edits).
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path

OPEN_STATUSES = {"pending", "in_progress"}
CREATED_RE = re.compile(r"Task #(\d+) created successfully")
MARKER_DIR = Path(os.path.expanduser("~/.claude/.cache/stop-task-reconcile-gate"))


def _result_text(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        out = []
        for block in content:
            if isinstance(block, dict):
                out.append(str(block.get("text", "") or block.get("content", "")))
            else:
                out.append(str(block))
        return "\n".join(out)
    return str(content or "")


def open_tasks(path: Path) -> list[tuple[str, str]]:
    """Return [(task_id, subject)] for tasks whose latest status is still open."""
    create_uids: set[str] = set()          # tool_use_id of each TaskCreate
    results: dict[str, str] = {}           # tool_use_id -> result text
    updates: list[tuple[str, str]] = []    # (taskId, status) in transcript order

    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            content = (obj.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "tool_use":
                    name = str(block.get("name", ""))
                    if name == "TaskCreate":
                        create_uids.add(str(block.get("id")))
                    elif name == "TaskUpdate":
                        inp = block.get("input") or {}
                        tid = str(inp.get("taskId", "")).strip()
                        status = str(inp.get("status", "")).strip()
                        if tid and status:
                            updates.append((tid, status))
                elif btype == "tool_result":
                    uid = str(block.get("tool_use_id", ""))
                    if uid:
                        results[uid] = _result_text(block.get("content"))

    created: dict[str, str] = {}           # task_id -> subject
    for uid in create_uids:
        text = results.get(uid, "")
        match = CREATED_RE.search(text)
        if match:
            subject = text.split(":", 1)[1].strip() if ":" in text else ""
            created[match.group(1)] = subject

    final: dict[str, str] = {}
    for tid, status in updates:
        final[tid] = status

    open_list: list[tuple[str, str]] = []
    for tid in sorted(set(created) | set(final), key=lambda x: (len(x), x)):
        status = final.get(tid, "pending" if tid in created else "")
        if status in OPEN_STATUSES:
            open_list.append((tid, created.get(tid, "")))
    return open_list


def should_block(payload: dict) -> list[tuple[str, str]]:
    if payload.get("stop_hook_active"):
        return []
    transcript = Path(str(payload.get("transcript_path") or ""))
    if not transcript.exists():
        return []
    return open_tasks(transcript)


def run(payload: dict) -> int:
    session_id = str(payload.get("session_id") or "unknown")
    marker = MARKER_DIR / session_id
    if marker.exists():
        return 0
    open_list = should_block(payload)
    if not open_list:
        return 0
    MARKER_DIR.mkdir(parents=True, exist_ok=True)
    marker.write_text("fired\n", encoding="utf-8")
    ids = ", ".join(f"#{tid}" for tid, _ in open_list)
    print(
        f"未完了タスク({ids})が残ったまま停止しようとしている。"
        "完了しているなら TaskUpdate で completed に、不要なら deleted にしてから停止せよ。"
        "意図的な保留(相手ボール待ち等)なら、その旨を一言述べれば次の停止で通る(このゲートは1回のみ)。",
        file=sys.stderr,
    )
    return 2


def self_check() -> int:
    def line(obj: dict) -> str:
        return json.dumps(obj, ensure_ascii=False) + "\n"

    create_use = {"type": "assistant", "message": {"content": [
        {"type": "tool_use", "id": "U1", "name": "TaskCreate",
         "input": {"subject": "foo: bar", "description": "d"}}]}}
    create_res = {"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": "U1",
         "content": "Task #1 created successfully: foo: bar"}]}}
    upd = lambda s: {"type": "assistant", "message": {"content": [
        {"type": "tool_use", "id": "U2", "name": "TaskUpdate",
         "input": {"taskId": "1", "status": s}}]}}

    with tempfile.TemporaryDirectory() as tmp:
        tr = Path(tmp) / "s.jsonl"
        tr.write_text(line(create_use) + line(create_res), encoding="utf-8")
        assert open_tasks(tr) == [("1", "foo: bar")], "created-only task must be open"

        tr.write_text(line(create_use) + line(create_res) + line(upd("completed")), encoding="utf-8")
        assert open_tasks(tr) == [], "completed task must not be open"

        tr.write_text(line(create_use) + line(create_res) + line(upd("deleted")), encoding="utf-8")
        assert open_tasks(tr) == [], "deleted task must not be open"

        tr.write_text(line(create_use) + line(create_res) + line(upd("in_progress")), encoding="utf-8")
        assert open_tasks(tr) == [("1", "foo: bar")], "in_progress task must be open"

        assert should_block({"stop_hook_active": True, "transcript_path": str(tr)}) == [], "stop_hook_active must short-circuit"
        assert should_block({"transcript_path": str(tmp) + "/missing.jsonl"}) == [], "missing transcript must not block"
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
