#!/usr/bin/env python3
"""Stream a privacy-minimized Codex call inventory; never execute logged code.

Time window is [since, until). A logged call is an invocation record, not proof
of successful execution. Embedded references and shell/UI tokens are lexical
hints only. Input logs are read-only; hashed dedup keys use temporary SQLite.
"""

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
from urllib.parse import urlsplit
import uuid


MAX_LINE_BYTES = 16 * 1024 * 1024
CALL_TYPES = frozenset({"function_call", "custom_tool_call", "tool_call"})
KNOWN_NON_CALL_TOP_TYPES = frozenset({
    "session_meta", "turn_context", "event_msg", "compacted", "message",
    "function_call_output", "custom_tool_call_output",
})
KNOWN_NON_CALL_RESPONSE_TYPES = frozenset({
    "message", "reasoning", "function_call_output", "custom_tool_call_output",
    "web_search_call", "image_generation_call", "compaction",
})
UUID_RE = re.compile(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
EMBEDDED_RE = re.compile(r"\btools\.([A-Za-z_][A-Za-z_0-9]*)")
URL_RE = re.compile(r"https?://[^\s\"'<>\\)\]}]+", re.IGNORECASE)
UI_METHODS = frozenset({
    "getState", "getBrowser", "getTab", "createBrowserTab", "getApp",
    "snapshot", "screenshot", "click", "dblclick", "fill", "type", "press",
    "hover", "scroll", "selectOption", "getByRole", "getByText", "locator",
    "evaluate", "goto", "navigate", "close", "reload", "waitFor", "drag",
    "domSnapshot", "getVisibleText", "getText", "innerText", "textContent",
})
UI_METHOD_RE = re.compile(r"\.([A-Za-z][A-Za-z0-9_]*)\s*\(")
GUI_ACTIONS = frozenset({
    "js", "js_reset", "run", "click", "double_click", "type", "type_text",
    "press_key", "key", "scroll", "drag", "screenshot", "snapshot",
    "navigate", "evaluate", "fill", "fill_form", "select_option", "hover",
    "wait_for", "tabs", "close", "resize", "upload_file", "file_upload",
    "handle_dialog", "console_messages", "network_requests", "get_state",
    "list_tabs", "read_page", "find", "javascript_tool", "computer",
    "navigate_page", "new_page", "list_pages", "select_page", "close_page",
    "take_snapshot", "take_screenshot", "evaluate_script", "wait_for_text",
    "browser_click", "browser_navigate", "browser_snapshot", "browser_type",
    "browser_evaluate", "browser_take_screenshot", "browser_tabs",
})
GUI_PROVIDERS = {
    "cua_repl": "cua", "cua": "cua", "computer": "computer",
    "computer_use": "computer", "browser": "browser", "playwright": "playwright",
    "chrome": "chrome", "chrome_devtools": "chrome", "claude_in_chrome": "chrome",
    "Claude_in_Chrome": "chrome",
}
EXACT_TOOLS = {
    "exec": "orchestration", "exec_command": "shell", "write_stdin": "shell",
    "Bash": "shell", "bash": "shell", "shell": "shell", "shell_command": "shell",
    "apply_patch": "file", "view_image": "file", "Read": "file", "Write": "file",
    "Edit": "file", "Glob": "file", "Grep": "file", "wait": "orchestration",
    "request_user_input": "orchestration", "run": "web",
    "js": "orchestration", "js_reset": "orchestration",
}
CODEX_ACTIONS = frozenset({
    "list_threads", "read_thread", "wait_threads", "create_thread", "fork_thread",
    "send_message_to_thread", "set_thread_title", "set_thread_archived",
    "list_archived_threads", "list_projects", "open_in_codex", "handoff_thread",
    "get_handoff_status", "automation_update", "capture_screen_context",
    "navigate_to_codex_page", "get_usage_limits", "load_workspace_dependencies",
})
HISTORY_ACTIONS = frozenset({
    "search", "search_history", "get_history", "get_screenshot", "get_activity",
    "query", "list_sessions", "get_session", "get_screenshots",
    "computer_history_get_settings", "computer_history_pause", "computer_history_resume",
    "computer_history_status", "computer_history_update_settings",
})
SERVICE_DOMAINS = {
    "drive.google.com": "google_drive", "docs.google.com": "google_drive",
    "sheets.google.com": "google_drive", "slides.google.com": "google_drive",
    "scrapbox.io": "cosense", "cosense.app": "cosense",
    "beeper.com": "beeper", "github.com": "github", "api.github.com": "github",
    "calendar.google.com": "calendar", "icloud.com": "calendar",
    "e-gov.go.jp": "egov", "shinsei.e-gov.go.jp": "egov", "laws.e-gov.go.jp": "egov",
    "netbk.co.jp": "bank", "rakuten-bank.co.jp": "bank", "bk.mufg.jp": "bank",
    "smbc.co.jp": "bank", "mizuhobank.co.jp": "bank", "jp-bank.japanpost.jp": "bank",
    "chatgpt.com": "codex",
    "note.com": "note", "freee.co.jp": "freee", "e-tax.nta.go.jp": "tax",
    "eltax.lta.go.jp": "tax", "yamap.com": "yamap", "tinder.com": "tinder",
}


def parse_time(value):
    """Require an explicit UTC offset; do not guess a missing event timezone."""
    if not isinstance(value, str):
        return None
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return result.astimezone(timezone.utc) if result.utcoffset() is not None else None
    except ValueError:
        return None


def iso(value):
    return value.isoformat().replace("+00:00", "Z") if value else None


def session_uuid(value):
    if not isinstance(value, str) or not UUID_RE.fullmatch(value):
        return None
    return str(uuid.UUID(value))


def safe_tool(name):
    """Only fixed known provider/action tokens may cross the output boundary."""
    if not isinstance(name, str):
        return {"tool": "unknown", "category": "unknown"}
    short = name.removeprefix("functions.")
    if short in EXACT_TOOLS:
        return {"tool": short, "category": EXACT_TOOLS[short]}
    normalized = short.removeprefix("mcp__")
    parts = normalized.split("__")
    if len(parts) == 2:
        provider, action = parts
    elif "." in normalized and len(normalized.split(".")) == 2:
        provider, action = normalized.split(".")
    else:
        provider, action = "", ""
    if provider in GUI_PROVIDERS and action in GUI_ACTIONS:
        family = GUI_PROVIDERS[provider]
        return {"tool": family + "." + action, "category": "gui", "gui_family": family}
    if provider == "codex_app" and action in CODEX_ACTIONS:
        return {"tool": "codex." + action, "category": "codex"}
    if provider == "node_repl" and action in {"js", "js_reset"}:
        return {"tool": "node_repl." + action, "category": "orchestration"}
    if provider in {"computer_history", "computer-history"} and action in HISTORY_ACTIONS:
        return {"tool": "computer_history." + action, "category": "history"}
    if short in HISTORY_ACTIONS and short.startswith("computer_history_"):
        return {"tool": "computer_history." + short, "category": "history"}
    if provider == "web" and action == "run":
        return {"tool": "web.run", "category": "web"}
    return {"tool": "unknown", "category": "unknown"}


def strings(value):
    """Traverse arguments without serializing object keys or values for output."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def lexical_hints(arguments):
    embedded, methods, services, shell = Counter(), set(), set(), set()
    for value in strings(arguments):
        for match in EMBEDDED_RE.finditer(value):
            tool = safe_tool(match.group(1))
            embedded[(tool["tool"], tool["category"], tool.get("gui_family"))] += 1
        methods.update(m.group(1) for m in UI_METHOD_RE.finditer(value) if m.group(1) in UI_METHODS)
        for match in URL_RE.finditer(value):
            try:
                host = (urlsplit(match.group()).hostname or "").lower()
            except ValueError:
                continue
            # Exact host or a real subdomain of a fixed allowlisted domain.
            services.add(next((category for domain, category in SERVICE_DOMAINS.items()
                               if host == domain or host.endswith("." + domain)), "other"))
        for token, pattern in (
            ("pw.mjs", r"(?<![\w.-])pw\.mjs\b"),
            ("osascript", r"(?<![\w.-])osascript\b"),
            ("screencapture", r"(?<![\w.-])screencapture\b"),
        ):
            if re.search(pattern, value):
                shell.add(token)
    refs = []
    for (name, category, family), count in sorted(embedded.items()):
        ref = {"tool": name, "category": category, "lexical_occurrences": count}
        if family:
            ref["gui_family"] = family
        refs.append(ref)
    return {"embedded_references": refs, "ui_method_hints": sorted(methods),
            "service_hints": sorted(services), "shell_ui_hints": sorted(shell)}


def extract_call(entry):
    kind = entry.get("type")
    payload = entry.get("payload")
    if kind == "response_item" and isinstance(payload, dict):
        return payload if payload.get("type") in CALL_TYPES else None
    if kind in CALL_TYPES:
        return payload if isinstance(payload, dict) else entry
    return None


def is_known_non_call(entry):
    """Keep unsupported record shapes visible without exposing their raw names."""
    if entry.get("type") in KNOWN_NON_CALL_TOP_TYPES:
        return True
    payload = entry.get("payload")
    return (entry.get("type") == "response_item" and isinstance(payload, dict)
            and payload.get("type") in KNOWN_NON_CALL_RESPONSE_TYPES)


def root_files(root):
    if root.is_file():
        yield root
    elif root.is_dir():
        for directory, dirs, files in os.walk(root, followlinks=False):
            dirs.sort()
            for name in sorted(files):
                path = Path(directory) / name
                if name.endswith(".jsonl") and not path.is_symlink():
                    yield path


def audit(roots, since, until, excluded, output):
    """Write one JSON document incrementally, retaining only summary counters."""
    if since >= until:
        raise ValueError("since must precede until")
    totals = Counter()
    outer_categories = Counter()
    embedded_categories = Counter()
    sources = []
    first = True
    output.write('{"schema_version":1,"calls":[')
    with tempfile.TemporaryDirectory(prefix="codex-tool-audit-") as temporary:
        db = sqlite3.connect(str(Path(temporary) / "dedup.sqlite"))
        db.execute("PRAGMA cache_size=-2048")
        db.execute("CREATE TABLE seen (key BLOB PRIMARY KEY) WITHOUT ROWID")
        for index, root in enumerate(roots):
            counts = Counter(unknown_record_shapes=0)
            earliest = latest = None
            source = {"source_index": index, "present": root.exists()}
            for path in root_files(root):
                counts["files_discovered"] += 1
                filename_ids = UUID_RE.findall(path.name)
                current_session = session_uuid(filename_ids[-1]) if filename_ids else None
                try:
                    stream = path.open("rb")
                except OSError:
                    counts["unreadable_files"] += 1
                    continue
                counts["files_read"] += 1
                file_has_window = False
                with stream:
                    line_number = 0
                    while True:
                        raw = stream.readline(MAX_LINE_BYTES + 1)
                        if not raw:
                            break
                        line_number += 1
                        counts["lines_read"] += 1
                        if len(raw) > MAX_LINE_BYTES:
                            while raw and not raw.endswith(b"\n"):
                                raw = stream.readline(MAX_LINE_BYTES + 1)
                            counts["oversized_lines"] += 1
                            continue
                        try:
                            entry = json.loads(raw)
                        except (ValueError, UnicodeDecodeError):
                            counts["invalid_lines"] += 1
                            continue
                        if not isinstance(entry, dict):
                            counts["invalid_lines"] += 1
                            continue
                        payload = entry.get("payload")
                        if entry.get("type") == "session_meta" and isinstance(payload, dict):
                            current_session = session_uuid(payload.get("id")) or current_session
                        stamp = parse_time(entry.get("timestamp"))
                        if stamp is None and isinstance(payload, dict):
                            stamp = parse_time(payload.get("timestamp"))
                        if stamp:
                            earliest = min(earliest, stamp) if earliest else stamp
                            latest = max(latest, stamp) if latest else stamp
                        call = extract_call(entry)
                        if call is None:
                            if not is_known_non_call(entry):
                                counts["unknown_record_shapes"] += 1
                            continue
                        counts["call_records_seen"] += 1
                        if stamp is None:
                            counts["calls_missing_valid_timestamp"] += 1
                            continue
                        if not since <= stamp < until:
                            counts["calls_outside_window"] += 1
                            continue
                        file_has_window = True
                        counts["calls_in_window_before_exclusion"] += 1
                        if current_session in excluded:
                            counts["excluded_session_calls"] += 1
                            continue
                        counts["calls_in_window_before_dedup"] += 1
                        call_id = call.get("call_id") or call.get("id")
                        if isinstance(call_id, str) and call_id:
                            key = hashlib.sha256(call_id.encode()).digest()
                            if not db.execute("INSERT OR IGNORE INTO seen VALUES (?)", (key,)).rowcount:
                                counts["duplicate_calls"] += 1
                                continue
                        else:
                            counts["calls_without_id_not_deduplicated"] += 1
                        safe = safe_tool(call.get("name"))
                        hints = lexical_hints(call.get("arguments", call.get("input", {})))
                        record = {"session_uuid": current_session, "timestamp": iso(stamp),
                                  "source_index": index, "line": line_number, **safe, **hints}
                        if not first:
                            output.write(",")
                        json.dump(record, output, ensure_ascii=False, separators=(",", ":"))
                        first = False
                        counts["unique_outer_calls"] += 1
                        outer_categories[safe["category"]] += 1
                        for ref in hints["embedded_references"]:
                            embedded_categories[ref["category"]] += ref["lexical_occurrences"]
                        if safe["category"] == "gui":
                            counts["outer_gui_calls"] += 1
                        if hints["ui_method_hints"] or hints["shell_ui_hints"] or any(r["category"] == "gui" for r in hints["embedded_references"]):
                            counts["calls_with_lexical_gui_hints"] += 1
                if file_has_window:
                    counts["files_with_window_calls"] += 1
                db.commit()
            source.update({"counts": dict(counts), "event_time_coverage": {
                "earliest": iso(earliest), "latest": iso(latest)}})
            sources.append(source)
            totals.update(counts)
        db.close()
    summary = {"window": {"since": iso(since), "until_exclusive": iso(until)},
               "sources": sources, "counts": dict(totals),
               "outer_call_categories": dict(outer_categories),
               "embedded_lexical_reference_categories": dict(embedded_categories),
               "semantics": {"outer_calls": "logged_invocations_not_success_proof",
                             "embedded_references": "lexical_hints_not_executed_calls",
                             "ui_and_service_hints": "lexical_only_not_verified_task_intent",
                             "dedup": "global_call_id_hash_in_window_first_record_wins",
                             "coverage": "all_jsonl_files_scanned_no_mtime_or_filename_date_filter"}}
    output.write('],"summary":')
    json.dump(summary, output, ensure_ascii=False, separators=(",", ":"))
    output.write("}\n")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, action="append", help="Local log root; repeatable. No remote access.")
    parser.add_argument("--since", required=True, help="Inclusive ISO timestamp with timezone")
    parser.add_argument("--until", required=True, help="Exclusive ISO timestamp with timezone")
    parser.add_argument("--exclude-session", action="append", default=[], help="Session UUID; repeatable")
    args = parser.parse_args()
    since, until = parse_time(args.since), parse_time(args.until)
    if not since or not until or since >= until:
        parser.error("--since/--until require timezone-qualified ISO timestamps with since < until")
    excluded = [session_uuid(item) for item in args.exclude_session]
    if any(item is None for item in excluded):
        parser.error("--exclude-session requires UUID values")
    codex = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    roots = args.root or [codex / "sessions", codex / "archived_sessions"]
    audit(roots, since, until, set(excluded), sys.stdout)


if __name__ == "__main__":
    main()
