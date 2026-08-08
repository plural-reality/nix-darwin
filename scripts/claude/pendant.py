#!/usr/bin/env python3
"""Pendant API Integration Tool — Limitless CLI."""

from __future__ import annotations

import argparse
import json
import os
import sys
import tomllib
import urllib.parse
import urllib.request
import urllib.error
import tempfile
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------

@dataclass
class Utterance:
    speaker: str
    text: str
    start_time: str | None = None
    end_time: str | None = None


@dataclass
class ActionItem:
    description: str
    completed: bool = False


@dataclass
class Conversation:
    id: str
    source: str  # "limitless"
    title: str
    summary: str
    category: str
    start_time: str
    end_time: str
    utterances: list[Utterance] = field(default_factory=list)
    action_items: list[ActionItem] = field(default_factory=list)
    markdown: str = ""
    language: str = ""
    geolocation: dict[str, Any] | None = None
    is_starred: bool = False
    raw: dict[str, Any] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

class PendantConfig:
    def __init__(self, path: str | None = None):
        p = Path(path) if path else Path.home() / ".config" / "pendant" / "config.toml"
        if not p.exists():
            raise FileNotFoundError(f"Config not found: {p}")
        with open(p, "rb") as f:
            self._data = tomllib.load(f)

    @property
    def limitless_api_key(self) -> str:
        return self._data["limitless_api_key"]

    @property
    def export_dir(self) -> Path:
        return Path(self._data.get("export_dir", "~/.claude/data/pendant-export")).expanduser()

    @property
    def timezone(self) -> str:
        return self._data.get("timezone", "Asia/Tokyo")


# ---------------------------------------------------------------------------
# Limitless Client
# ---------------------------------------------------------------------------

class LimitlessClient:
    BASE = "https://api.limitless.ai/v1"

    def __init__(self, api_key: str, tz: str = "Asia/Tokyo"):
        self.api_key = api_key
        self.tz = tz
    def _get(self, path: str, params: dict | None = None) -> dict:
        query = urllib.parse.urlencode(params or {})
        request = urllib.request.Request(
            f"{self.BASE}{path}" + (f"?{query}" if query else ""),
            headers={"X-API-Key": self.api_key, "User-Agent": "pendant/1.0"})
        return json.loads(urllib.request.urlopen(request, timeout=30).read().decode())

    def search(self, query: str, limit: int = 5) -> list[Conversation]:
        data = self._get("/lifelogs", {
            "query": query, "limit": limit,
            "includeMarkdown": "true", "includeHeadings": "true",
        })
        return [self._to_conversation(l) for l in data.get("data", {}).get("lifelogs", [])]

    def get_lifelogs(self, limit: int = 10, date: str | None = None,
                     is_starred: bool | None = None,
                     cursor: str | None = None) -> tuple[list[Conversation], str | None]:
        params: dict[str, Any] = {
            "limit": limit,
            "includeMarkdown": "true",
            "includeHeadings": "true",
            "timezone": self.tz,
        }
        if date:
            params["date"] = date
        if is_starred is not None:
            params["isStarred"] = str(is_starred).lower()
        if cursor:
            params["cursor"] = cursor
        data = self._get("/lifelogs", params)
        logs = data.get("data", {}).get("lifelogs", [])
        # Limitless exposes pagination metadata separately from the payload:
        # {"data":{"lifelogs":[...]},"meta":{"lifelogs":{"nextCursor":...}}}.
        # Reading data.nextCursor silently stopped after the first page.
        next_cursor = data.get("meta", {}).get("lifelogs", {}).get("nextCursor")
        return [self._to_conversation(l) for l in logs], next_cursor

    def get_lifelog(self, lifelog_id: str) -> Conversation:
        data = self._get(f"/lifelogs/{lifelog_id}")
        return self._to_conversation(data.get("data", {}).get("lifelog", data))

    def _to_conversation(self, raw: dict) -> Conversation:
        contents = raw.get("contents", [])
        summary = ""
        utterances = []
        for c in contents:
            t = c.get("type", "")
            if t == "heading1" and not summary:
                summary = c.get("content", "")
            elif t == "blockquote":
                utterances.append(Utterance(
                    speaker=c.get("speakerName", "Unknown"),
                    text=c.get("content", ""),
                    start_time=c.get("startTime"),
                    end_time=c.get("endTime"),
                ))
        return Conversation(
            id=raw.get("id", ""),
            source="limitless",
            title=raw.get("title", ""),
            summary=summary,
            category="",
            start_time=raw.get("startTime", ""),
            end_time=raw.get("endTime", ""),
            utterances=utterances,
            action_items=[],
            markdown=raw.get("markdown", ""),
            language="",
            is_starred=raw.get("isStarred", False),
            raw=raw,
        )

    def close(self):
        return None


# ---------------------------------------------------------------------------
# Unified Facade
# ---------------------------------------------------------------------------

class PendantAPI:
    def __init__(self, config: PendantConfig):
        self.config = config
        self.limitless = LimitlessClient(config.limitless_api_key, config.timezone)

    def search(self, query: str, source: str = "all", limit: int = 5) -> list[Conversation]:
        results: list[Conversation] = []
        if source in ("all", "limitless"):
            try:
                results.extend(self.limitless.search(query, limit=limit))
            except Exception as e:
                print(f"[warn] Limitless search failed: {e}", file=sys.stderr)
        results.sort(key=lambda c: c.start_time or "", reverse=True)
        return results[:limit]

    def today(self, source: str = "all") -> list[Conversation]:
        tz = timezone(timedelta(hours=9))
        today_str = datetime.now(tz).strftime("%Y-%m-%d")
        return self.by_date(today_str, source)

    def by_date(self, date_str: str, source: str = "all") -> list[Conversation]:
        results: list[Conversation] = []
        if source in ("all", "limitless"):
            def all_pages(cursor: str | None = None,
                          seen: frozenset[str] = frozenset()) -> list[Conversation]:
                convos, next_cursor = self.limitless.get_lifelogs(
                    limit=10, date=date_str, cursor=cursor)
                return convos + (all_pages(next_cursor, seen | {next_cursor})
                                 if next_cursor and next_cursor not in seen else [])
            results.extend(all_pages())
        results.sort(key=lambda c: c.start_time or "", reverse=True)
        return results

    def config_check(self) -> dict[str, Any]:
        result: dict[str, Any] = {"limitless": {}}
        try:
            convos, _ = self.limitless.get_lifelogs(limit=1)
            result["limitless"] = {"status": "ok", "latest": convos[0].title if convos else "no data"}
        except Exception as e:
            result["limitless"] = {"status": "error", "message": str(e)}
        return result

    def close(self):
        self.limitless.close()


# ---------------------------------------------------------------------------
# Exporter
# ---------------------------------------------------------------------------

class Exporter:
    def __init__(self, api: PendantAPI, config: PendantConfig):
        self.api = api
        self.config = config

    def export_limitless(self, since: str | None = None) -> int:
        out_dir = self.config.export_dir / "limitless"
        out_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
        out_dir.chmod(0o700)
        meta_path = out_dir / "_metadata.json"
        meta = self._load_meta(meta_path)

        cursor = None
        records: dict[str, dict[str, dict]] = {}

        while True:
            convos, next_cursor = self.api.limitless.get_lifelogs(limit=10, cursor=cursor)
            if not convos:
                break

            for c in convos:
                date_key = c.start_time[:10] if c.start_time and len(c.start_time) >= 10 else "unknown"
                if since and date_key < since:
                    # Stop if we've gone past the since date
                    next_cursor = None
                    break

                record = {"unified": _conv_to_dict(c), "raw": c.raw}
                records.setdefault(date_key, {})[c.id] = record
            else:
                cursor = next_cursor
                if not cursor:
                    break
                continue
            break

        ordered = {day: sorted(day_records.values(), key=lambda row: (
            row["unified"].get("start_time", ""), row["unified"].get("id", "")))
                   for day, day_records in records.items()}
        for day, rows in ordered.items():
            with tempfile.NamedTemporaryFile("w", dir=out_dir, delete=False) as tmp:
                tmp.writelines(json.dumps(row, ensure_ascii=False) + "\n" for row in rows)
                path = Path(tmp.name)
            path.chmod(0o600)
            path.replace(out_dir / f"{day}.jsonl")

        count = sum(len(rows) for rows in ordered.values())

        meta["last_export"] = datetime.now(timezone.utc).isoformat()
        meta["total_exported"] = count
        self._save_meta(meta_path, meta)
        return count

    def _load_meta(self, path: Path) -> dict:
        if path.exists():
            return json.loads(path.read_text())
        return {}

    def _save_meta(self, path: Path, meta: dict):
        with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as tmp:
            tmp.write(json.dumps(meta, indent=2, ensure_ascii=False))
            temporary = Path(tmp.name)
        temporary.chmod(0o600)
        temporary.replace(path)


# ---------------------------------------------------------------------------
# Output Formatters
# ---------------------------------------------------------------------------

def _conv_to_dict(c: Conversation) -> dict:
    d = asdict(c)
    d.pop("raw", None)
    return d


class OutputFormatter:
    @staticmethod
    def format_conversations(convos: list[Conversation], fmt: str) -> str:
        if fmt == "json":
            return json.dumps([_conv_to_dict(c) for c in convos], indent=2, ensure_ascii=False)
        elif fmt == "compact":
            lines = []
            for c in convos:
                ts = c.start_time[:16].replace("T", " ") if c.start_time else "???"
                title = c.title[:60] or c.summary[:60]
                lines.append(f"[L] {ts}  {title}")
            return "\n".join(lines)
        elif fmt == "markdown":
            parts = []
            for c in convos:
                ts = c.start_time[:16].replace("T", " ") if c.start_time else "???"
                parts.append(f"## [Limitless] {c.title or '(untitled)'}")
                parts.append(f"**Time**: {ts} | **Category**: {c.category or 'N/A'}")
                if c.summary:
                    parts.append(f"\n{c.summary}")
                if c.action_items:
                    parts.append("\n**Action Items:**")
                    for ai in c.action_items:
                        check = "x" if ai.completed else " "
                        parts.append(f"- [{check}] {ai.description}")
                if c.geolocation:
                    addr = c.geolocation.get("address", "")
                    if addr:
                        parts.append(f"\n**Location**: {addr}")
                parts.append("")
            return "\n".join(parts)
        return json.dumps([_conv_to_dict(c) for c in convos], indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pendant.py", description="Pendant API Integration Tool")
    p.add_argument("-f", "--format", choices=["json", "compact", "markdown"], default="json",
                   help="Output format (default: json)")
    p.add_argument("--config", help="Path to config.toml")

    sub = p.add_subparsers(dest="command")

    # search
    s = sub.add_parser("search", help="Search Limitless lifelogs")
    s.add_argument("query", help="Search query")
    s.add_argument("--source", choices=["all", "limitless"], default="all")
    s.add_argument("--limit", type=int, default=5)

    # today
    t = sub.add_parser("today", help="Today's conversations")
    t.add_argument("--source", choices=["all", "limitless"], default="all")

    # date
    d = sub.add_parser("date", help="Conversations by date")
    d.add_argument("date_str", help="Date (YYYY-MM-DD)")
    d.add_argument("--source", choices=["all", "limitless"], default="all")

    # export
    e = sub.add_parser("export", help="Incremental export")
    e.add_argument("--since", help="Export since date (YYYY-MM-DD)")
    e.add_argument("--source", choices=["all", "limitless"], default="all")

    # export-all
    ea = sub.add_parser("export-all", help="Full export")
    ea.add_argument("--source", choices=["all", "limitless"], default="all")

    # config-check
    sub.add_parser("config-check", help="Verify API connectivity")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        config = PendantConfig(args.config)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    api = PendantAPI(config)
    fmt = args.format
    formatter = OutputFormatter()

    try:
        if args.command == "config-check":
            result = api.config_check()
            print(json.dumps(result, indent=2, ensure_ascii=False))

        elif args.command == "search":
            convos = api.search(args.query, source=args.source, limit=args.limit)
            print(formatter.format_conversations(convos, fmt))

        elif args.command == "today":
            convos = api.today(source=args.source)
            print(formatter.format_conversations(convos, fmt))

        elif args.command == "date":
            convos = api.by_date(args.date_str, source=args.source)
            print(formatter.format_conversations(convos, fmt))

        elif args.command == "export":
            exporter = Exporter(api, config)
            n = exporter.export_limitless(since=args.since)
            print(f"Limitless: exported {n} conversations", file=sys.stderr)
            print(f"Total: {n} conversations exported", file=sys.stderr)

        elif args.command == "export-all":
            exporter = Exporter(api, config)
            n = exporter.export_limitless()
            print(f"Limitless: exported {n} conversations", file=sys.stderr)
            print(f"Total: {n} conversations exported", file=sys.stderr)

    except urllib.error.HTTPError as e:
        print(f"API error: HTTP {e.code}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        api.close()


if __name__ == "__main__":
    main()
