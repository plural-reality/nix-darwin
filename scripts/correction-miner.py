#!/usr/bin/env python3
"""Extract likely user correction utterances from Claude project transcripts.

Self-check:
  python3 scripts/correction-miner.py --self-check

Default output:
  ~/.claude/.cache/correction-miner/report-<ISO-week>.md
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

CORRECTION_RE = re.compile(
    r"(違う|ちがう|誤り|間違|訂正|修正して|そうじゃない|ではなく|じゃなく|"
    r"前にも|何度も|また.*同じ|勝手に|やめて|しないで|指示.*守|確認してから|"
    r"読んでから|止まらず|止まらないで)"
)
TASK_PREFIXES = (
    "次の Claude Code セッションを要約",
    "Base directory for this skill",
    "Stop hook feedback:",
    "Codex Handoff",
    "You are tasked with",
)


@dataclass(frozen=True)
class Correction:
    session_id: str
    timestamp: str
    text: str


def event_text(obj: dict[str, object]) -> str:
    message = obj.get("message") or {}
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        return "\n".join(
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        ).strip()
    content_text = obj.get("content")
    return content_text.strip() if isinstance(content_text, str) else ""


def is_noise(obj: dict[str, object], text: str) -> bool:
    return (
        bool(obj.get("isMeta"))
        or not text
        or len(text) > 2000
        or text.startswith("<")
        or "system-reminder" in text[:200]
        or any(text.startswith(prefix) for prefix in TASK_PREFIXES)
    )


def parse_timestamp(value: str) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def iter_corrections(projects_root: Path, since: dt.datetime) -> list[Correction]:
    out: list[Correction] = []
    for path in sorted(glob.glob(str(projects_root / "*" / "*.jsonl"))):
        session_id = Path(path).stem
        with open(path, encoding="utf-8", errors="replace") as lines:
            for line in lines:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("type") != "user":
                    continue
                timestamp = str(obj.get("timestamp") or "")
                parsed = parse_timestamp(timestamp)
                text = event_text(obj)
                if parsed and parsed < since:
                    continue
                if is_noise(obj, text) or not CORRECTION_RE.search(text):
                    continue
                out.append(Correction(session_id=session_id, timestamp=timestamp, text=text))
    return out


def report_path(cache_dir: Path, now: dt.datetime) -> Path:
    year, week, _ = now.isocalendar()
    return cache_dir / f"report-{year}-W{week:02d}.md"


def render_report(corrections: list[Correction], days: int, now: dt.datetime) -> str:
    lines = [
        f"# correction-miner report {now.date().isoformat()}",
        "",
        f"- window: last {days} days",
        f"- corrections: {len(corrections)}",
        "",
    ]
    for item in corrections:
        lines.extend(
            [
                f"## {item.timestamp or '(no timestamp)'} `{item.session_id}`",
                "",
                item.text,
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def append_llm_summary(path: Path) -> None:
    prompt = path.read_text(encoding="utf-8") + "\n\n上記の訂正発話をテーマ別に3-7項目で要約してください。"
    result = subprocess.run(
        ["claude", "-p", "--model", "claude-haiku-4-5-20251001"],
        input=prompt,
        text=True,
        capture_output=True,
        check=False,
    )
    with path.open("a", encoding="utf-8") as fh:
        fh.write("\n## LLM theme clustering\n\n")
        fh.write(result.stdout.strip() if result.returncode == 0 else f"(claude failed: {result.stderr.strip()})")
        fh.write("\n")


def write_report(projects_root: Path, cache_dir: Path, days: int, use_llm: bool) -> Path:
    now = dt.datetime.now(dt.timezone.utc)
    since = now - dt.timedelta(days=days)
    corrections = iter_corrections(projects_root, since)
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = report_path(cache_dir, now)
    path.write_text(render_report(corrections, days, now), encoding="utf-8")
    if use_llm:
        append_llm_summary(path)
    return path


def self_check() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "projects" / "proj"
        root.mkdir(parents=True)
        session = root / "abc123.jsonl"
        session.write_text(
            json.dumps(
                {
                    "type": "user",
                    "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
                    "message": {"content": "それは違う。確認してから書いて。"},
                },
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )
        path = write_report(Path(tmp) / "projects", Path(tmp) / "cache", 7, False)
        text = path.read_text(encoding="utf-8")
        assert "abc123" in text
        assert "それは違う" in text
    print("ok")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--llm", action="store_true")
    parser.add_argument("--projects-root", default=os.path.expanduser("~/.claude/projects"))
    parser.add_argument("--cache-dir", default=os.path.expanduser("~/.claude/.cache/correction-miner"))
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args(argv)
    if args.self_check:
        return self_check()
    path = write_report(Path(args.projects_root), Path(args.cache_dir), args.days, args.llm)
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
