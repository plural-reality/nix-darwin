"""Scrapbox の実行時 session を、秘密値を表示せず1か所で解決する adapter。"""
from __future__ import annotations

import json
import os
import urllib.request
import urllib.error
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


def _settings_sid() -> str:
    try:
        data = json.loads(Path.home().joinpath(".claude/settings.local.json").read_text())
        return str((data.get("env") or {}).get("SCRAPBOX_SID") or "")
    except Exception:
        return ""


@dataclass(frozen=True)
class SessionResolution:
    sid: str
    state: str
    detail: str = ""


def _check(sid: str) -> SessionResolution:
    try:
        request = urllib.request.Request(
            "https://scrapbox.io/api/users/me",
            headers={"Cookie": f"connect.sid={sid}", "User-Agent": "personal-ops/1.0"})
        data = json.loads(urllib.request.urlopen(request, timeout=8).read().decode())
        valid = bool(data.get("name")) and data.get("isGuest") is not True
        return SessionResolution(sid if valid else "", "取得済み" if valid else "認証が必要")
    except urllib.error.HTTPError as error:
        return SessionResolution("", "認証が必要" if error.code in (401, 403) else "一時的に確認できません",
                                 f"HTTP {error.code}")
    except Exception as error:
        return SessionResolution("", "一時的に確認できません", type(error).__name__)


@lru_cache(maxsize=1)
def resolve_session() -> SessionResolution:
    """settings の最新値を優先し、古い process env は検証に通ったときだけ使う。"""
    candidates = tuple(dict.fromkeys(x for x in (_settings_sid(), os.environ.get("SCRAPBOX_SID", "")) if x))
    checks = tuple(_check(sid) for sid in candidates)
    valid = next((result for result in checks if result.sid), None)
    return (valid if valid else
            SessionResolution("", "一時的に確認できません",
                              next((result.detail for result in checks if result.state == "一時的に確認できません"), ""))
            if any(result.state == "一時的に確認できません" for result in checks) else
            SessionResolution("", "認証が必要", "session候補がありません"))


def resolve_sid() -> str:
    return resolve_session().sid


def process_env() -> dict[str, str]:
    sid = resolve_sid()
    clean = {key: value for key, value in os.environ.items() if key != "SCRAPBOX_SID"}
    return clean | ({"SCRAPBOX_SID": sid} if sid else {})


def exec_with_sid(argv: list[str]) -> None:
    """秘密値をstdoutへ出さず、検証済みSIDを子processだけへ注入する。"""
    if not argv:
        raise SystemExit("usage: scrapbox_session.py exec <command> [args...]")
    allow_missing = "--dry-run" in argv or "-n" in argv
    if not resolve_sid() and not allow_missing:
        raise SystemExit("Scrapbox sessionを確認できません。書込みを中止しました")
    os.execvpe(argv[0], argv, process_env())


if __name__ == "__main__":
    sys.argv[1:2] == ["exec"] or (_ for _ in ()).throw(
        SystemExit("usage: scrapbox_session.py exec <command> [args...]"))
    exec_with_sid(sys.argv[2:])
