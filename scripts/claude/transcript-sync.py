#!/usr/bin/env python3
"""One local schedule target for all transcript providers."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent
JST = timezone(timedelta(hours=9))


def _command(name: str, args: list[str]) -> dict[str, object]:
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / name), *args],
        capture_output=True,
        text=True,
        timeout=3600,
    )
    state = (
        "取得済み"
        if result.returncode == 0
        else "認証が必要"
        if result.returncode == 2
        else "一時的に取得できません"
    )
    detail = (
        json.loads(result.stdout)
        if result.returncode == 0 and result.stdout.strip().startswith("{")
        else (result.stderr.strip().splitlines() or [""])[-1][:200]
    )
    return {"state": state, "detail": detail, "exit_code": result.returncode}


def sync() -> dict[str, object]:
    since = (datetime.now(JST) - timedelta(days=1)).strftime("%Y-%m-%d")
    root = Path(
        os.environ.get("LIFELOG_TRANSCRIPT_DIR", "~/.claude/data/pendant-export")
    ).expanduser()
    limitless_args = (
        ["export", "--source", "limitless", "--since", since]
        if any((root / "limitless").glob("????-??-??.jsonl"))
        else ["export-all", "--source", "limitless"]
    )
    results = {
        "mori": _command("mori.py", ["sync"]),
        "limitless": _command("pendant.py", limitless_args),
        "plaud": _command("plaud-sync.py", []),
    }
    return {
        "synced_at": datetime.now(timezone.utc).isoformat(),
        "sources": results,
        "ok": all(item["exit_code"] == 0 for item in results.values()),
    }


def main() -> int:
    result = sync()
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
