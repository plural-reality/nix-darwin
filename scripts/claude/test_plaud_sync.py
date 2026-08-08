#!/usr/bin/env python3
"""Offline parser check for the official Plaud CLI adapter."""

import importlib.util
import sys
from pathlib import Path


HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("plaud_sync_under_test", HERE / "plaud-sync.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


line = "  " + "a" * 32 + "  " + "Meeting".ljust(36) + "  " + "2026-08-03".ljust(12) + "  " + "01:02:03"
rows = MODULE.parse_file_rows(line)
assert rows == [{"id": "a" * 32, "name": "Meeting", "date": "2026-08-03", "duration": "01:02:03"}]

# The CLI wraps a long CJK name onto the next line; the row must still be recovered.
wrapped = "  " + "b" * 32 + "    \n04-30 方言の恥ずかしさ、 セマンティックなデータ処理、 プレフ…  2025-04-30    44m03s"
assert MODULE.parse_file_rows(wrapped) == [
    {"id": "b" * 32, "name": "04-30 方言の恥ずかしさ、 セマンティックなデータ処理、 プレフ", "date": "2025-04-30", "duration": "44m03s"}
]

# A page whose parsed rows disagree with the CLI's own count must fail loud, not truncate silently.
MODULE._run = lambda args: "Files on this page: 2\n  " + "c" * 32 + "  n  2026-08-03  1s\n"
try:
    MODULE.list_files(1)
    raise AssertionError("expected listing drift to raise")
except MODULE.PlaudError as error:
    assert "drift" in str(error), error

segments = MODULE.parse_transcript(
    "[00:00 - 00:02] A: hello [00:02 - 01:03] B: world",
    "2026-08-03T09:00:00+09:00",
)
assert [item["text"] for item in segments] == ["hello", "world"]
assert segments[-1]["end_time"] == "2026-08-03T09:01:03+09:00"

# Plaud reports naive UTC; the archive buckets by local day, so 07-30 23:55Z is a 07-31 recording.
assert MODULE.normalize_start("2026-07-30T23:55:31") == "2026-07-31T08:55:31+09:00"
assert MODULE.normalize_start("2026-07-31T08:55:31+09:00") == "2026-07-31T08:55:31+09:00"
assert MODULE.normalize_start("") == ""

# A recording Plaud holds no transcript for is skipped, not an error that aborts the backfill.
MODULE._run = lambda args: "  transcript:   unavailable\n  name:         memo\n"
assert MODULE.fetch_file("deadbeef") is None
print("ok")
