#!/usr/bin/env python3
"""Limitless の JSON stream を、時間単位の全文ページへ決定的に変換する。

Pure core:
  stdin(JSON list) -> pages(JSON / Scrapbox text)

Explicit effect boundary:
  `write` だけが canonical `scrapbox-write --verbatim` を呼び、直後に Scrapbox API を
  readback して一致を確認する。ページ名は時刻から決まるため再実行は同じページの置換になる。

Usage:
  python3 pendant.py -f json date 2026-08-02 --source limitless |
    python3 limitless-takalog.py manifest --date 2026-08-02
  ... | python3 limitless-takalog.py render --date 2026-08-02
  ... | python3 limitless-takalog.py write --date 2026-08-02 [--dry-run]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
import urllib.error
import re
from datetime import datetime
from functools import reduce
from itertools import groupby
from typing import Any

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SCRIPT_DIR, "lib"))
from scrapbox_session import resolve_sid

MAX_PAGE_CHARS = 50_000
PROJECT = "takalog"
_OWNED_RE = re.compile(r"^\s*\[\( Limitlessの自動記録: (\d+)行 / sha256:([0-9a-f]{64})\]$")


def _when(item: dict[str, Any]) -> datetime:
    return datetime.fromisoformat(str(item.get("start_time") or "").replace("Z", "+00:00"))


def _identity(item: dict[str, Any]) -> str:
    raw = f"{item.get('start_time', '')}\0{item.get('markdown', '')}".encode()
    return str(item.get("id") or hashlib.sha256(raw).hexdigest())


def normalized(items: list[dict[str, Any]], date: str) -> list[dict[str, Any]]:
    valid = [item for item in items
             if item.get("start_time") and item.get("markdown")
             and str(item["start_time"])[:10] == date]
    unique = {(_identity(item), str(item.get("start_time"))): item for item in valid}
    return sorted(unique.values(), key=_when)


def _chunks(items: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    def add(chunks: tuple[tuple[dict[str, Any], ...], ...], item: dict[str, Any]):
        size = sum(len(str(x.get("markdown") or "")) for x in chunks[-1]) if chunks else 0
        return (chunks[:-1] + (chunks[-1] + (item,),)
                if chunks and size + len(str(item.get("markdown") or "")) <= MAX_PAGE_CHARS
                else chunks + ((item,),))
    return [list(chunk) for chunk in reduce(add, items, tuple())]


def _page_title(date: str, hour: int, part: int, total: int) -> str:
    y, m, d = (int(x) for x in date.split("-"))
    # chunk数が1→2へ変わっても1ページ目をrenameしない。2ページ目以降だけ安定suffixを持つ。
    suffix = "" if part == 0 else f" {part + 1}"
    return f"Limitless {y}/{m}/{d} {hour:02d}時{suffix}"


def _body(items: list[dict[str, Any]]) -> list[str]:
    first, last = _when(items[0]), datetime.fromisoformat(
        str(items[-1].get("end_time") or items[-1].get("start_time")).replace("Z", "+00:00"))
    ids = " ".join(f"`{_identity(item)}`" for item in items)
    transcript = [line for index, item in enumerate(items)
                  for line in (([f"--- {item.get('start_time', '')} ---"] if index else [])
                               + str(item.get("markdown") or "").splitlines())]
    return [
        "[limitless.icon] [codex.icon]",
        " [( Limitlessから自動取得した全文です。音声認識の誤り・話者の取り違えを含む未検証記録です。]",
        f" [( 収録: {first:%H:%M}〜{last:%H:%M} / {len(items)}件 / {sum(len(str(x.get('markdown') or '')) for x in items):,}文字]",
        f" [( 元データ: {ids}]",
        "",
        " code:limitless-transcript",
        *[f"  {line}" if line else "  " for line in transcript],
    ]


def pages(items: list[dict[str, Any]], date: str) -> list[dict[str, Any]]:
    hourly = [(int(hour), list(group)) for hour, group in groupby(
        normalized(items, date), key=lambda item: _when(item).hour)]
    return [
        {"title": _page_title(date, hour, part, len(parts)), "body": _body(chunk),
         "start": str(chunk[0].get("start_time")),
         "end": str(chunk[-1].get("end_time") or chunk[-1].get("start_time")),
         "count": len(chunk), "characters": sum(len(str(x.get("markdown") or "")) for x in chunk)}
        for hour, group in hourly for parts in [_chunks(group)] for part, chunk in enumerate(parts)
    ]


def manifest(page_list: list[dict[str, Any]], date: str) -> dict[str, Any]:
    return {"date": date, "project": PROJECT,
            "pages": [{k: page[k] for k in ("title", "start", "end", "count", "characters")}
                      | {"link": f"/{PROJECT}/{page['title']}"} for page in page_list]}


def _archive_titles(date: str) -> set[str]:
    y, m, d = (int(value) for value in date.split("-"))
    prefix = f"Limitless {y}/{m}/{d}"
    query = urllib.parse.urlencode({"q": prefix, "limit": 100})
    request = urllib.request.Request(
        f"https://scrapbox.io/api/pages/{PROJECT}/search/query?{query}",
        headers={"Cookie": f"connect.sid={resolve_sid()}", "User-Agent": "personal-ops/1.0"})
    data = json.loads(urllib.request.urlopen(request, timeout=15).read().decode())
    if int(data.get("count", 0)) > 100:
        raise RuntimeError("Limitless全文ページ検索が100件を超えたためstale確認を中止しました")
    title_re = re.compile(rf"^{re.escape(prefix)} \d{{2}}時(?: [1-9]\d*)?$")
    return {str(page.get("title")) for page in data.get("pages", []) if title_re.match(str(page.get("title") or ""))}


def _digest(lines: list[str]) -> str:
    payload = json.dumps(lines, ensure_ascii=False, separators=(",", ":")).encode()
    return hashlib.sha256(payload).hexdigest()


def _owned(lines: list[str]) -> list[str]:
    return [f" [( Limitlessの自動記録: {len(lines)}行 / sha256:{_digest(lines)}]", *lines]


def _merge(lines: list[str], existing: list[str] | None,
           migrate_legacy_exact: bool = False) -> list[str]:
    if existing is None:
        return _owned(lines)
    marker = _OWNED_RE.match(existing[0]) if existing else None
    if marker is None:
        if migrate_legacy_exact and existing[:len(lines)] == lines:
            return _owned(lines) + existing[len(lines):]
        raise RuntimeError("旧形式の全文ページです。注釈を守るため自動移行を中止しました")
    count, expected = int(marker.group(1)), marker.group(2)
    previous, human = existing[1:1 + count], existing[1 + count:]
    if len(previous) != count or _digest(previous) != expected or any(_OWNED_RE.match(line) for line in human):
        raise RuntimeError("Limitless自動記録範囲が編集されています。書込みを中止しました")
    return _owned(lines) + human


def _fetch(title: str) -> list[str] | None:
    sid = resolve_sid()
    url = f"https://scrapbox.io/api/pages/{PROJECT}/{urllib.parse.quote(title, safe='')}/text"
    request = urllib.request.Request(
        url, headers={"Cookie": f"connect.sid={sid}", "User-Agent": "personal-ops/1.0"})
    try:
        return urllib.request.urlopen(request, timeout=15).read().decode().rstrip("\n").splitlines()[1:]
    except urllib.error.HTTPError as error:
        return None if error.code == 404 else (_ for _ in ()).throw(error)


def _readback(title: str, expected: list[str]) -> bool:
    return _fetch(title) == expected


def _write(page: dict[str, Any], dry: bool, migrate_legacy_exact: bool) -> dict[str, Any]:
    try:
        existing = _fetch(page["title"])
        body = _merge(page["body"], existing, migrate_legacy_exact)
        base = [page["title"]] if existing is None else [page["title"], *existing]
        args = ["scrapbox-write", "--project", PROJECT, "--title", page["title"],
                "--mode", "replace", "--verbatim", "--expect-sha256", _digest(base)] \
            + (["--dry-run"] if dry else [])
        result = subprocess.run(args, input="\n".join(body) + "\n", capture_output=True, text=True)
        verified = result.returncode == 0 and (dry or _readback(page["title"], body))
        return {"title": page["title"], "state": "確認のみ" if dry else "保存・確認済み" if verified else "失敗",
                "verified": verified, "detail": (result.stderr or result.stdout).strip()[:240] if not verified else ""}
    except Exception as error:
        return {"title": page["title"], "state": "要手動確認", "verified": False,
                "detail": str(error)[:240]}


def main() -> None:
    parser = argparse.ArgumentParser(description="Archive full Limitless transcripts to takalog")
    parser.add_argument("command", choices=("manifest", "render", "write"))
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--allow-empty", action="store_true",
                        help="正常な記録なしを別経路で確認した場合だけ空入力を許可")
    parser.add_argument("--migrate-legacy-exact", action="store_true",
                        help="旧本文が今回の生成内容と完全一致する場合だけmarker形式へ移行")
    args = parser.parse_args()
    page_list = pages(json.load(sys.stdin), args.date)
    if args.command == "write" and not page_list and not args.allow_empty:
        raise SystemExit("Limitless入力が空です。API失敗との区別がないため書込みを中止しました")
    existing_titles = (_archive_titles(args.date)
                       if args.command == "write" and not args.dry_run else set())
    stale = sorted(existing_titles - {page["title"] for page in page_list})
    output = (manifest(page_list, args.date) if args.command == "manifest"
              else "\n\n".join(f"# {p['title']}\n" + "\n".join(p["body"]) for p in page_list)
              if args.command == "render"
              else manifest(page_list, args.date) | {"results": [
                  _write(page, args.dry_run, args.migrate_legacy_exact) for page in page_list],
                  "stale_pages": stale})
    print(output if isinstance(output, str) else json.dumps(output, ensure_ascii=False, indent=2))
    if args.command == "write" and (stale or not all(r["verified"] for r in output["results"])):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
