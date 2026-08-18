#!/usr/bin/env python3
"""lifelogのtyped outcome・Codex archive scanのnetworkなし退行テスト。"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone
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


def _calendar_containers() -> list[dict[str, object]]:
    return [{"name": name, "id": f"id-{index}", "source": {"name": "test"}}
            for index, name in enumerate(ll.CHECKED_CALENDARS)]


def test_calendar_uses_eventkit_snapshot() -> None:
    original_run = ll.subprocess.run
    calls: list[tuple[list[str], dict[str, object]]] = []
    payload = {
        "ok": True,
        "events": [
            {"start": "2026-08-01T14:00:00Z", "allDay": False,
             "title": "前日から継続", "calendar": {"name": "Taka の予定"}},
            {"start": "2026-08-02T00:00:00Z", "allDay": False,
             "title": "集荷", "calendar": {"name": "Taka の予定"}},
            {"start": "2026-08-01T15:00:00Z", "allDay": True,
             "title": "終日", "calendar": {"name": "日本の祝日"}},
            {"start": "2026-08-01T15:00:00Z", "allDay": True,
             "title": "終日", "calendar": {"name": "日本の祝日"}},
        ],
        "containers": {"calendars": _calendar_containers()},
        "errors": {"events": None, "reminders": None},
    }
    try:
        ll.subprocess.run = lambda args, **kwargs: (
            calls.append((args, json.loads(kwargs["input"])))
            or CompletedProcess(args, 0, json.dumps(payload), ""))
        result = ll.fetch_calendar("2026-08-02")
        assert result.state == ll.OK_STATE
        assert result.data == [
            {"time": "00:00", "allday": True,
             "calendar": "日本の祝日", "summary": "終日"},
            {"time": "09:00", "allday": False,
             "calendar": "Taka の予定", "summary": "集荷"},
        ]
        assert calls == [([ll.EVKIT_BIN, "snapshot"], {
            "rangeStart": "2026-08-02T00:00:00+09:00",
            "rangeEnd": "2026-08-03T00:00:00+09:00",
            "calendars": {"names": ll.CHECKED_CALENDARS, "ids": []},
            "reminderLists": {"names": [], "ids": []},
            "includeCompleted": False,
        })]
    finally:
        ll.subprocess.run = original_run


def test_calendar_typed_eventkit_failures() -> None:
    original_run = ll.subprocess.run
    try:
        denied = {
            "events": [], "containers": {"calendars": []},
            "errors": {"events": {
                "code": "authorization_denied", "message": "events require full access"}},
        }
        ll.subprocess.run = lambda args, **_kwargs: CompletedProcess(
            args, 0, json.dumps(denied), "")
        result = ll.fetch_calendar("2026-08-02")
        assert result.state == ll.AUTH_STATE

        missing = {
            "events": [],
            "containers": {"calendars": _calendar_containers()[:-1]},
            "errors": {"events": None},
        }
        ll.subprocess.run = lambda args, **_kwargs: CompletedProcess(
            args, 0, json.dumps(missing), "")
        result = ll.fetch_calendar("2026-08-02")
        assert result.state == ll.TRANSIENT_STATE
        assert "日本の祝日" in result.detail
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


def test_gmail_uses_gws_metadata_without_himalaya() -> None:
    original_run = ll.subprocess.run
    day_timestamp = int(datetime(
        2026, 8, 15, 12, 0,
        tzinfo=timezone(timedelta(hours=9))).timestamp() * 1000)
    responses = iter([
        CompletedProcess([], 0, json.dumps({"emailAddress": "takagi@plural-reality.com"}), ""),
        CompletedProcess([], 0, json.dumps({"messages": [{"id": "m1"}]}), ""),
        CompletedProcess([], 0, json.dumps({
            "id": "m1", "internalDate": str(day_timestamp),
            "payload": {"headers": [
                {"name": "From", "value": "Alice <alice@example.com>"},
                {"name": "To", "value": "takagi@plural-reality.com"},
                {"name": "Subject", "value": "確認"},
            ]},
        }), ""),
    ])
    calls: list[list[str]] = []
    try:
        ll.subprocess.run = lambda args, **_kwargs: (
            calls.append(args) or next(responses))
        result = ll.fetch_gmail("2026-08-15")
        assert result.state == ll.OK_STATE
        assert result.data == [{
            "time": "12:00", "direction": "受信",
            "peer": "Alice <alice@example.com>",
            "from": "Alice <alice@example.com>", "subject": "確認",
            "id": "m1", "folder": "[Gmail]/すべてのメール",
        }]
        assert calls[0][0:4] == ["gws", "gmail", "users", "getProfile"]
        assert all("himalaya" not in arg for call in calls for arg in call)
    finally:
        ll.subprocess.run = original_run


test_collection()
test_calendar_uses_eventkit_snapshot()
test_calendar_typed_eventkit_failures()
test_calendar_bindings_match_calendar_app_names()
test_archived_codex()
test_transcript_archive_source()
test_gmail_uses_gws_metadata_without_himalaya()
print("ALL PASS")
