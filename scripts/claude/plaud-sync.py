#!/usr/bin/env python3
"""Archive full Plaud transcripts through Plaud's official CLI."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
from transcript_archive import read_archive, write_archive  # noqa: E402


DEFAULT_ARCHIVE = Path(
    os.environ.get("LIFELOG_TRANSCRIPT_DIR", "~/.claude/data/pendant-export")
).expanduser() / "plaud"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
SEGMENT = re.compile(r"\[(\d+:\d{2}) - (\d+:\d{2})\]\s*")
JST = timezone(timedelta(hours=9))
PAGE_SIZE = 100
ROW = re.compile(r"([0-9a-f]{32})\s+(.+?)\s{2,}(\d{4}-\d{2}-\d{2})\s{2,}(\S+)", re.S)
REPORTED = re.compile(r"Files on this page:\s*(\d+)")


class PlaudError(RuntimeError):
    pass


class PlaudAuthRequired(PlaudError):
    pass


def _run(args: list[str]) -> str:
    executable = shutil.which("plaud")
    if not executable:
        raise PlaudError("Plaud CLI is not installed")
    result = subprocess.run(
        [executable, *args],
        capture_output=True,
        text=True,
        timeout=120,
        env={
            **os.environ,
            "NO_COLOR": "1",
            "PLAUD_NO_UPDATE_NOTIFIER": "1",
        },
    )
    stderr = ANSI.sub("", result.stderr)
    if result.returncode == 2 or "AUTH_FAILED" in stderr:
        raise PlaudAuthRequired("Plaud authentication required: run `plaud login`")
    if result.returncode != 0:
        raise PlaudError(stderr.strip() or f"Plaud exited {result.returncode}")
    return ANSI.sub("", result.stdout)


def parse_file_rows(output: str) -> list[dict[str, str]]:
    """Match on row structure, not columns: the CLI wraps long CJK names onto a second line."""
    return [
        {
            "id": match.group(1),
            "name": " ".join(match.group(2).split()).removesuffix("…"),
            "date": match.group(3),
            "duration": match.group(4),
        }
        for match in ROW.finditer(output)
    ]


def list_files(page: int = 1) -> list[dict[str, str]]:
    output = _run(["files", "--page", str(page), "--page-size", str(PAGE_SIZE)])
    rows = parse_file_rows(output)
    reported = REPORTED.search(output)
    # Fail loud: a dropped row looks exactly like "the last page" and would silently
    # truncate the whole backfill at the pagination check below.
    if reported and int(reported.group(1)) != len(rows):
        raise PlaudError(
            f"Plaud listing drift on page {page}: CLI reported {reported.group(1)}, parsed {len(rows)}"
        )
    return rows


def list_all_files(page: int = 1) -> list[dict[str, str]]:
    batch = list_files(page)
    return batch + (list_all_files(page + 1) if len(batch) == PAGE_SIZE else [])


def parse_metadata(output: str) -> dict[str, str]:
    pairs = [
        match.groups()
        for line in output.splitlines()
        for match in [re.match(r"^\s{2}([a-z_]+):\s+(.*)$", line)]
        if match
    ]
    return dict(pairs)


def _offset_seconds(value: str) -> int:
    minutes, seconds = value.split(":")
    return int(minutes) * 60 + int(seconds)


def normalize_start(value: str) -> str:
    """Plaud reports naive UTC; the archive buckets by local day, so anchor to JST."""
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return value
    anchored = parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed
    return anchored.astimezone(JST).isoformat()


def _iso_offset(start: str, offset: str) -> str:
    try:
        origin = datetime.fromisoformat(start.replace("Z", "+00:00"))
        return (origin + timedelta(seconds=_offset_seconds(offset))).isoformat()
    except ValueError:
        return offset


def parse_transcript(text: str, start_at: str) -> list[dict[str, Any]]:
    matches = list(SEGMENT.finditer(text))

    def segment(index: int, match: re.Match[str]) -> dict[str, Any]:
        stop = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end():stop].strip()
        speaker, separator, content = body.partition(": ")
        return {
            "speaker": speaker if separator and len(speaker) <= 80 else "Unknown",
            "text": content if separator and len(speaker) <= 80 else body,
            "start_time": _iso_offset(start_at, match.group(1)),
            "end_time": _iso_offset(start_at, match.group(2)),
        }

    return (
        [segment(index, match) for index, match in enumerate(matches)]
        if matches
        else [
            {
                "speaker": "Unknown",
                "text": text.strip(),
                "start_time": start_at,
                "end_time": start_at,
            }
        ]
    )


def fetch_file(file_id: str) -> dict[str, Any] | None:
    """None means Plaud holds no transcript for this recording; a raise means the fetch failed."""
    metadata = parse_metadata(_run(["file", file_id]))
    if metadata.get("transcript") != "available":
        return None
    with tempfile.TemporaryDirectory() as root:
        target = Path(root) / "transcript.txt"
        _run(["transcript", file_id, "--output", str(target)])
        transcript = target.read_text() if target.exists() else ""
    if not transcript.strip():
        raise PlaudError(f"Transcript announced but empty: {file_id}")
    start = normalize_start(metadata.get("start_at") or metadata.get("created_at") or "")
    utterances = parse_transcript(transcript, start)
    return {
        "id": file_id,
        "source": "plaud",
        "title": metadata.get("name", ""),
        "summary": "",
        "category": "",
        "start_time": start,
        "end_time": utterances[-1].get("end_time", start),
        "utterances": utterances,
        "action_items": [],
        "markdown": "\n".join(
            f"- {item['speaker']} ({item['start_time']}): {item['text']}"
            for item in utterances
        ),
        "language": "",
        "geolocation": None,
        "is_starred": False,
    }


def sync(
    directory: Path = DEFAULT_ARCHIVE,
    from_date: str | None = None,
    to_date: str | None = None,
) -> dict[str, Any]:
    existing = read_archive(directory)
    listed = list_all_files()
    selected = [
        row
        for row in listed
        if (not from_date or row["date"] >= from_date)
        and (not to_date or row["date"] <= to_date)
    ]
    missing = [row for row in selected if row["id"] not in existing]
    merged = dict(existing)
    written: list[Path] = []

    def absorb(file_id: str) -> dict[str, Any] | None:
        """Persist each transcript as it lands so a mid-backfill failure keeps its progress."""
        record = fetch_file(file_id)
        merged.update({str(record["id"]): record} if record else {})
        # ponytail: rewrites every day file per record (O(n^2) writes). Fine at this
        # archive size; batch per day if a backfill ever gets slow.
        written.extend(write_archive(directory, merged) if record else [])
        return record

    fetched = [record for record in map(absorb, (row["id"] for row in missing)) if record]
    paths = sorted({str(path) for path in written})
    state = {
        "source": "plaud",
        "last_sync": datetime.now(timezone.utc).isoformat(),
        "listed": len(selected),
        "fetched": len(fetched),
        "skipped": len(missing) - len(fetched),
        "archived": len(merged),
        "files_written": paths,
    }
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    state_path = directory / "_state.json"
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
    state_path.chmod(0o600)
    return state


def main() -> int:
    parser = argparse.ArgumentParser(prog="plaud-sync")
    parser.add_argument("--from", dest="from_date")
    parser.add_argument("--to", dest="to_date")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_ARCHIVE)
    args = parser.parse_args()
    try:
        print(json.dumps(sync(args.output_dir, args.from_date, args.to_date), ensure_ascii=False, indent=2))
        return 0
    except PlaudAuthRequired as error:
        print(str(error), file=sys.stderr)
        return 2
    except (PlaudError, OSError, subprocess.SubprocessError) as error:
        print(f"Plaud sync error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
