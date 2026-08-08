#!/usr/bin/env python3
"""lifelogのtyped outcome・Codex archive scanのnetworkなし退行テスト。"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from subprocess import CompletedProcess
from pathlib import Path

HERE = Path(__file__).parent
spec = importlib.util.spec_from_file_location("lifelog_under_test", HERE / "lifelog.py")
ll = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = ll
spec.loader.exec_module(ll)


def test_collection() -> None:
    original = ll.SOURCES
    try:
        ll.SOURCES = {
            "calendar": lambda _d: ll.SourceResult([], ll.EMPTY_STATE, "0件"),
            "limitless": lambda _d: ll.SourceResult([], ll.TRANSIENT_STATE, "timeout"),
        }
        result = ll.gather("2026-08-02")
        assert result["calendar"] == [] and result["limitless"] == []
        assert result["collection"] == [
            {"name": "Apple Calendar", "state": "記録なし", "detail": "0件"},
            {"name": "Limitless", "state": "一時的に取得できません", "detail": "timeout"},
        ]
        ll.SOURCES = {"calendar": lambda _d: (_ for _ in ()).throw(PermissionError("denied"))}
        failed = ll.gather("2026-08-02")
        assert failed["collection"] == [
            {"name": "Apple Calendar", "state": "一時的に取得できません", "detail": "PermissionError"}
        ]
    finally:
        ll.SOURCES = original


def test_calendar_retries_connection_invalid_once() -> None:
    original_run = ll.subprocess.run
    attempts: list[list[str]] = []
    responses = iter([
        CompletedProcess(
            ["osascript"], 1, "",
            "Connection Invalid error for service com.apple.hiservices-xpcservice"),
        CompletedProcess(
            ["osascript"], 0,
            "__META__\t7\t0\nfalse\t08:00\tTaka の予定\t集荷\n", ""),
    ])
    try:
        ll.subprocess.run = lambda args, **_kwargs: (
            attempts.append(args) or next(responses))
        result = ll.fetch_calendar("2026-08-02")
        assert result.state == ll.OK_STATE
        assert result.data == [{
            "time": "08:00", "allday": False,
            "calendar": "Taka の予定", "summary": "集荷",
        }]
        assert len(attempts) == 2
    finally:
        ll.subprocess.run = original_run


def test_calendar_bindings_match_calendar_app_names() -> None:
    assert ll.CHECKED_CALENDARS == [
        "Taka の予定", "takagi@plural-reality.com", "Shunsuke Takagi (General)",
        "Business ", "ルーティーン", "Intervals.icu", "日本の祝日",
    ]


def test_archived_codex() -> None:
    original_home = ll.HOME
    with tempfile.TemporaryDirectory() as root:
        ll.HOME = root
        active = Path(root, ".codex/sessions/2026/06/19/a.jsonl")
        archived = Path(root, ".codex/archived_sessions/a.jsonl")
        active.parent.mkdir(parents=True)
        archived.parent.mkdir(parents=True)
        rows = [
            {"timestamp": "2026-06-19T01:00:00Z", "type": "session_meta",
             "payload": {"id": "same-session", "cwd": "/work/sample"}},
            {"timestamp": "2026-06-19T01:01:00Z", "type": "event_msg",
             "payload": {"type": "user_message", "message": "作業して"}},
            {"timestamp": "2026-06-19T01:02:00Z", "type": "event_msg",
             "payload": {"type": "agent_message", "phase": "final_answer", "message": "完了"}},
        ]
        payload = "\n".join(json.dumps(row, ensure_ascii=False) for row in rows)
        active.write_text(payload)
        archived.write_text(payload)
        os.utime(active, None)
        os.utime(archived, None)
        result = ll.fetch_sessions("2026-06-19")
        assert result.state == "取得済み" and len(result.data) == 1
        assert result.data[0]["session_id"] == "same-session"
    ll.HOME = original_home


def test_transcript_archive_source() -> None:
    original_run = ll.subprocess.run
    original_root = os.environ.get("LIFELOG_TRANSCRIPT_DIR")
    with tempfile.TemporaryDirectory() as root:
        os.environ["LIFELOG_TRANSCRIPT_DIR"] = root
        path = Path(root, "mori", "2026-08-03.jsonl")
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({
            "id": "m1", "title": "bad auto title",
            "start_time": "2026-08-03T09:00:00+09:00",
            "utterances": [{"text": "一次Transcript"}],
        }, ensure_ascii=False) + "\n")
        ll.subprocess.run = lambda *_args, **_kwargs: CompletedProcess([], 0, "{}", "")
        result = ll.fetch_mori("2026-08-03")
        assert result.state == ll.OK_STATE
        assert result.data[0]["text"] == "一次Transcript"
        assert result.data[0]["utterance_count"] == 1
    ll.subprocess.run = original_run
    os.environ.pop("LIFELOG_TRANSCRIPT_DIR", None)
    if original_root is not None:
        os.environ["LIFELOG_TRANSCRIPT_DIR"] = original_root


test_collection()
test_calendar_retries_connection_invalid_once()
test_calendar_bindings_match_calendar_app_names()
test_archived_codex()
test_transcript_archive_source()
print("ALL PASS")
