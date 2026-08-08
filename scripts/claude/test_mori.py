#!/usr/bin/env python3
"""Small offline check for Mori normalization and idempotent archive merge."""

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("mori_under_test", HERE / "mori.py")
MORI = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = MORI
SPEC.loader.exec_module(MORI)


def test_normalize_and_archive() -> None:
    session = {
        "id": "s1",
        "title": "ignored summary title",
        "started_at": "2026-08-03T09:00:00+09:00",
        "ended_at": "2026-08-03T09:02:00+09:00",
        "is_favorited": False,
    }
    transcript = {
        "id": "t1",
        "utterances": [
            {
                "speaker_name": "Speaker 0",
                "text": "全文",
                "started_at": "2026-08-03T09:00:00+09:00",
                "ended_at": "2026-08-03T09:00:02+09:00",
            }
        ],
    }
    row = MORI.normalize(session, transcript)
    assert row["source"] == "mori"
    assert row["utterances"][0]["text"] == "全文"
    assert "全文" in row["markdown"]
    with tempfile.TemporaryDirectory() as root:
        directory = Path(root)
        MORI.write_archive(directory, {"s1": row})
        MORI.write_archive(directory, {"s1": row})
        lines = (directory / "2026-08-03.jsonl").read_text().splitlines()
        assert len(lines) == 1
        assert json.loads(lines[0])["id"] == "s1"
        assert os.stat(directory / "2026-08-03.jsonl").st_mode & 0o777 == 0o600


def test_sse_decode() -> None:
    body = b'event: message\ndata: {"jsonrpc":"2.0","id":1,"result":{"ok":true}}\n\n'
    assert MORI._decode_rpc(body, "text/event-stream") == {"ok": True}


def test_rate_limit_retries_and_persists_each_record() -> None:
    """A rate-limited transcript is retried, and every record that lands is already on disk."""
    session = {"id": "s1", "started_at": "2026-08-03T09:00:00+09:00", "ended_at": "2026-08-03T09:02:00+09:00"}
    attempts = []

    def flaky(_client: object, _session_id: str) -> dict:
        attempts.append(1)
        if len(attempts) < 2:
            raise MORI.MoriError("mori MCP rate limited: fetch_transcript")
        return {"id": "t1", "utterances": []}

    original, MORI.fetch_transcript = MORI.fetch_transcript, flaky
    original_backoff, MORI.RATE_LIMIT_BACKOFF = MORI.RATE_LIMIT_BACKOFF, 0.0
    try:
        seen: list[dict] = []
        rows = MORI.fetch_conversations(None, [session], interval=0.0, on_record=seen.append)
        assert len(attempts) == 2, attempts
        assert [row["id"] for row in rows] == ["s1"]
        assert [row["id"] for row in seen] == ["s1"]
    finally:
        MORI.fetch_transcript = original
        MORI.RATE_LIMIT_BACKOFF = original_backoff


def test_non_rate_limit_error_is_not_retried() -> None:
    calls = []

    def broken(_client: object, _session_id: str) -> dict:
        calls.append(1)
        raise MORI.MoriError("transcript not found")

    original, MORI.fetch_transcript = MORI.fetch_transcript, broken
    try:
        MORI.fetch_conversations(None, [{"id": "s1"}], interval=0.0)
        raise AssertionError("expected the non-transient error to propagate")
    except MORI.MoriError:
        assert len(calls) == 1, calls
    finally:
        MORI.fetch_transcript = original


test_normalize_and_archive()
test_sse_decode()
test_rate_limit_retries_and_persists_each_record()
test_non_rate_limit_error_is_not_retried()
print("ok")
