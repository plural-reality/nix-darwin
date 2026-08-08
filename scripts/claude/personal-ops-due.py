#!/usr/bin/env python3
"""takalog 日付ページを唯一の完了印として、再処理が必要な日だけを返す。

別の watermark file を持たない。MacBook Airが停止していた期間も、復帰後に欠けた日付ページを
見つけて日次処理を追いつかせる。読み取り専用。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import re
from datetime import date, timedelta
from itertools import takewhile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SCRIPT_DIR, "lib"))
from scrapbox_session import resolve_sid

REQUIRED = ("Apple Calendar", "Limitless", "エージェント作業", "Gmail", "Beeper", "Scrapbox", "Coast Local")
OK_WORDS = ("取得済み", "記録なし")
_COLLECTION_LINE = re.compile(
    r"^\s*\[\( (Apple Calendar|Limitless|エージェント作業|Gmail|Beeper|Scrapbox|Coast Local): "
    r"(取得済み|記録なし|一時的に取得できません|認証が必要)(?:（[^\n]*）)?\]$")


def collection_state(lines: list[str]) -> str:
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == "[** 収集状況]") + 1
    except StopIteration:
        return "未処理"
    block = list(takewhile(lambda line: line.startswith(" ") or not line.strip(), lines[start:]))
    pairs = [match.groups() for line in block for match in [_COLLECTION_LINE.match(line)] if match]
    states = {name: state for name, state in pairs}
    complete = len(pairs) == len(states) and all(states.get(name) in OK_WORDS for name in REQUIRED)
    return "処理済み" if complete else "要再確認"


def _fetch(day: date) -> list[str] | None:
    sid = resolve_sid()
    title = f"{day.year}/{day.month}/{day.day}"
    url = f"https://scrapbox.io/api/pages/takalog/{urllib.parse.quote(title, safe='')}/text"
    request = urllib.request.Request(
        url, headers={"Cookie": f"connect.sid={sid}", "User-Agent": "personal-ops/1.0"})
    try:
        return urllib.request.urlopen(request, timeout=10).read().decode().splitlines()[1:]
    except urllib.error.HTTPError as error:
        return None if error.code == 404 else []
    except urllib.error.URLError:
        return []


def main() -> None:
    parser = argparse.ArgumentParser(description="Find daily personal-ops dates that need processing")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--through", help="YYYY-MM-DD (default: yesterday)")
    parser.add_argument("--since", help="YYYY-MM-DD (do not backfill before rollout start)")
    args = parser.parse_args()
    end = date.fromisoformat(args.through) if args.through else date.today() - timedelta(days=1)
    earliest = max(end - timedelta(days=max(1, args.days) - 1),
                   date.fromisoformat(args.since) if args.since else date.min)
    days = [earliest + timedelta(days=offset) for offset in range((end - earliest).days + 1)]
    fetched = [(day, _fetch(day)) for day in days]
    states = [{"date": day.isoformat(),
               "state": "未処理" if lines is None else
                        "一時的に確認できません" if not lines else collection_state(lines)}
              for day, lines in fetched]
    print(json.dumps({"through": end.isoformat(), "due": [x["date"] for x in states if x["state"] != "処理済み"],
                      "days": states}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
