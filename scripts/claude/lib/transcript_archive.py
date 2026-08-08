"""Canonical JSONL transcript archive shared by provider adapters."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import Any


def read_archive(directory: Path) -> dict[str, dict[str, Any]]:
    rows = (
        [
            json.loads(line)
            for path in sorted(directory.glob("????-??-??.jsonl"))
            for line in path.read_text().splitlines()
            if line.strip()
        ]
        if directory.exists()
        else []
    )
    return {str(row.get("id")): row for row in rows if row.get("id")}


def write_archive(directory: Path, records: dict[str, dict[str, Any]]) -> list[Path]:
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)
    days = sorted(
        {
            str(row.get("start_time", ""))[:10]
            for row in records.values()
            if len(str(row.get("start_time", ""))) >= 10
        }
    )

    def write(day: str) -> Path:
        rows = sorted(
            (
                row
                for row in records.values()
                if str(row.get("start_time", ""))[:10] == day
            ),
            key=lambda row: (row.get("start_time", ""), row.get("id", "")),
        )
        with tempfile.NamedTemporaryFile("w", dir=directory, delete=False) as handle:
            handle.writelines(
                json.dumps(row, ensure_ascii=False) + "\n" for row in rows
            )
            temporary = Path(handle.name)
        temporary.chmod(0o600)
        target = directory / f"{day}.jsonl"
        temporary.replace(target)
        return target

    return [write(day) for day in days]
