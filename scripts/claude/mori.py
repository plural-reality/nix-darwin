#!/usr/bin/env python3
"""Read-only Mori Transcript CLI and idempotent local archive.

The provider boundary is Mori's Remote MCP.  This adapter deliberately ignores
Journal objects and emits the same conversation-shaped JSON used by pendant.py.

Commands:
  mori.py login
  mori.py sessions [--from YYYY-MM-DD] [--to YYYY-MM-DD]
  mori.py transcript <session-id|mori://transcript/session/...>
  mori.py date YYYY-MM-DD
  mori.py sync [--from YYYY-MM-DD] [--to YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import secrets
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
from transcript_archive import read_archive, write_archive  # noqa: E402


MCP_URL = os.environ.get("MORI_MCP_URL", "https://mcp.mori.to")
CLIENT_ID = os.environ.get(
    "MORI_CLIENT_ID",
    "https://codex-mori-oauth.tkgshn.com/.well-known/oauth-client-metadata/codex-mori.json",
)
REDIRECT_URI = os.environ.get(
    "MORI_REDIRECT_URI",
    "http://127.0.0.1:3118/callback/ZE14LTMDdY2I",
)
TOKEN_PATH = Path(
    os.environ.get("MORI_TOKEN_FILE", "~/.config/mori-cli/tokens.json")
).expanduser()
DEFAULT_ARCHIVE = Path(
    os.environ.get(
        "LIFELOG_TRANSCRIPT_DIR", "~/.claude/data/pendant-export"
    )
).expanduser() / "mori"
SCOPES = ("mori.sessions:read", "mori.transcripts:read")
PROTOCOL_VERSION = "2025-06-18"
TRANSCRIPT_INTERVAL = float(os.environ.get("MORI_TRANSCRIPT_INTERVAL", "6.2"))
RATE_LIMIT_BACKOFF = float(os.environ.get("MORI_RATE_LIMIT_BACKOFF", "65"))
RATE_LIMIT_ATTEMPTS = int(os.environ.get("MORI_RATE_LIMIT_ATTEMPTS", "4"))


class MoriError(RuntimeError):
    pass


class AuthRequired(MoriError):
    pass


@dataclass(frozen=True)
class HttpResult:
    body: bytes
    headers: dict[str, str]


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def _atomic_json(path: Path, value: dict[str, Any]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.parent.chmod(0o700)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.chmod(0o600)
    temporary.replace(path)
    return path


def _load_tokens(path: Path = TOKEN_PATH) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def _form_post(url: str, form: dict[str, str]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(form).encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    return json.loads(urllib.request.urlopen(request, timeout=30).read().decode())


def _save_token_response(
    response: dict[str, Any], previous: dict[str, Any] | None = None
) -> dict[str, Any]:
    merged = {
        **(previous or {}),
        **response,
        "obtained_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": time.time() + int(response.get("expires_in", 3600)),
    }
    _atomic_json(TOKEN_PATH, merged)
    return merged


def _refresh(tokens: dict[str, Any]) -> dict[str, Any]:
    refresh_token = tokens.get("refresh_token")
    if not refresh_token:
        raise AuthRequired("Mori authentication required: run `mori login`")
    try:
        response = _form_post(
            f"{MCP_URL}/oauth/token",
            {
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": CLIENT_ID,
                "resource": MCP_URL,
                "scope": " ".join(SCOPES),
            },
        )
        return _save_token_response(response, tokens)
    except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError) as error:
        raise AuthRequired("Mori authentication expired: run `mori login`") from error


def _access_token() -> str:
    tokens = _load_tokens()
    valid = tokens.get("access_token") and float(tokens.get("expires_at", 0)) > time.time() + 30
    refreshed = tokens if valid else _refresh(tokens)
    token = refreshed.get("access_token")
    if not token:
        raise AuthRequired("Mori authentication required: run `mori login`")
    return str(token)


class _CallbackHandler(BaseHTTPRequestHandler):
    result: dict[str, str] = {}
    expected_path = urllib.parse.urlparse(REDIRECT_URI).path

    def do_GET(self) -> None:  # noqa: N802 - stdlib callback name
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        self.__class__.result = {
            "path": parsed.path,
            "code": query.get("code", [""])[0],
            "state": query.get("state", [""])[0],
            "error": query.get("error", [""])[0],
        }
        ok = parsed.path == self.expected_path and bool(self.__class__.result["code"])
        body = (
            "<h1>Mori authorization complete</h1><p>You can close this tab.</p>"
            if ok
            else "<h1>Mori authorization failed</h1><p>Return to the terminal.</p>"
        )
        encoded = f"<!doctype html><meta charset=utf-8>{body}".encode()
        self.send_response(200 if ok else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, _format: str, *_args: Any) -> None:
        return None


def login(open_browser: bool = True, timeout: int = 300) -> dict[str, Any]:
    parsed = urllib.parse.urlparse(REDIRECT_URI)
    verifier = _b64url(secrets.token_bytes(48))
    challenge = _b64url(hashlib.sha256(verifier.encode()).digest())
    state = _b64url(secrets.token_bytes(24))
    params = {
        "response_type": "code",
        "client_id": CLIENT_ID,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "redirect_uri": REDIRECT_URI,
        "state": state,
        "scope": " ".join(SCOPES),
        "resource": MCP_URL,
    }
    authorize_url = f"{MCP_URL}/authorize?{urllib.parse.urlencode(params)}"
    _CallbackHandler.result = {}
    server = HTTPServer((parsed.hostname or "127.0.0.1", parsed.port or 3118), _CallbackHandler)
    server.timeout = timeout
    print(f"Open this URL to authorize Mori:\n{authorize_url}", file=sys.stderr)
    browser_opened = webbrowser.open(authorize_url) if open_browser else False
    print(
        "Waiting for the browser callback..." if browser_opened else "Waiting for the callback...",
        file=sys.stderr,
    )
    server.handle_request()
    server.server_close()
    result = _CallbackHandler.result
    valid = (
        result.get("path") == parsed.path
        and result.get("state") == state
        and bool(result.get("code"))
        and not result.get("error")
    )
    if not valid:
        raise AuthRequired("Mori authorization did not complete")
    response = _form_post(
        f"{MCP_URL}/oauth/token",
        {
            "grant_type": "authorization_code",
            "code": result["code"],
            "client_id": CLIENT_ID,
            "redirect_uri": REDIRECT_URI,
            "code_verifier": verifier,
            "resource": MCP_URL,
        },
    )
    return _save_token_response(response)


def _decode_rpc(body: bytes, content_type: str = "") -> dict[str, Any]:
    text = body.decode().strip()
    candidates = (
        [line.removeprefix("data:").strip() for line in text.splitlines() if line.startswith("data:")]
        if "text/event-stream" in content_type or text.startswith("event:") or text.startswith("data:")
        else [text]
    )
    decoded = [json.loads(item) for item in candidates if item and item != "[DONE]"]
    match = next((item for item in reversed(decoded) if isinstance(item, dict) and ("result" in item or "error" in item)), None)
    if not match:
        raise MoriError("Mori MCP returned no JSON-RPC result")
    if match.get("error"):
        raise MoriError(str(match["error"]))
    return match.get("result", {})


class MoriMCP:
    def __init__(self) -> None:
        self.session_id: str | None = None
        self.request_id = 0

    def _post(self, payload: dict[str, Any], expect_body: bool = True) -> dict[str, Any]:
        self.request_id += 1
        body = {"jsonrpc": "2.0", **payload}
        body = ({**body, "id": self.request_id} if expect_body else body)

        def send(token: str) -> HttpResult:
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
            }
            headers = ({**headers, "Mcp-Session-Id": self.session_id} if self.session_id else headers)
            request = urllib.request.Request(
                MCP_URL,
                data=json.dumps(body).encode(),
                headers=headers,
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                return HttpResult(response.read(), {k.lower(): v for k, v in response.headers.items()})

        try:
            response = send(_access_token())
        except urllib.error.HTTPError as error:
            response = send(_refresh(_load_tokens())["access_token"]) if error.code == 401 else (_ for _ in ()).throw(error)
        self.session_id = response.headers.get("mcp-session-id", self.session_id)
        return (
            _decode_rpc(response.body, response.headers.get("content-type", ""))
            if expect_body and response.body.strip()
            else {}
        )

    def initialize(self) -> "MoriMCP":
        self._post(
            {
                "method": "initialize",
                "params": {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {"name": "mori-cli", "version": "0.1.0"},
                },
            }
        )
        self._post({"method": "notifications/initialized", "params": {}}, expect_body=False)
        return self

    def tool(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        result = self._post(
            {"method": "tools/call", "params": {"name": name, "arguments": arguments}}
        )
        if result.get("isError"):
            raise MoriError(str(result.get("content", "Mori tool error")))
        structured = result.get("structuredContent")
        if isinstance(structured, dict):
            return structured
        texts = [part.get("text", "") for part in result.get("content", []) if part.get("type") == "text"]
        parsed = [json.loads(text) for text in texts if text.strip().startswith(("{", "["))]
        return next((item for item in parsed if isinstance(item, dict)), {})


def _client() -> MoriMCP:
    return MoriMCP().initialize()


def list_sessions(
    client: MoriMCP, from_date: str | None = None, to_date: str | None = None
) -> list[dict[str, Any]]:
    def page(offset: int = 0) -> list[dict[str, Any]]:
        arguments = {
            "limit": 50,
            "offset": offset,
            **({"from": from_date} if from_date else {}),
            **({"to": to_date} if to_date else {}),
        }
        batch = client.tool("list_sessions", arguments).get("sessions") or []
        return batch + (page(offset + len(batch)) if len(batch) == 50 else [])

    return sorted(page(), key=lambda item: (item.get("started_at", ""), item.get("id", "")))


def _transcript_uri(value: str) -> str:
    return value if value.startswith("mori://transcript/") else f"mori://transcript/session/{value.removeprefix('mori://session/')}"


def fetch_transcript(client: MoriMCP, session_or_uri: str) -> dict[str, Any]:
    value = client.tool("fetch", {"uri": _transcript_uri(session_or_uri)})
    transcript = (value.get("object") or {}).get("transcript")
    if not isinstance(transcript, dict):
        raise MoriError(f"Transcript not found: {session_or_uri}")
    return transcript


def _markdown(utterances: list[dict[str, Any]]) -> str:
    return "\n".join(
        f"- {item.get('speaker', 'Unknown')} ({item.get('start_time', '')}): {item.get('text', '')}"
        for item in utterances
    )


def normalize(session: dict[str, Any], transcript: dict[str, Any]) -> dict[str, Any]:
    utterances = [
        {
            "speaker": item.get("speaker_name") or "Unknown",
            "text": item.get("text") or "",
            "start_time": item.get("started_at"),
            "end_time": item.get("ended_at"),
        }
        for item in (transcript.get("utterances") or [])
    ]
    return {
        "id": session.get("id") or transcript.get("id", ""),
        "source": "mori",
        "title": session.get("title") or transcript.get("title") or "",
        "summary": "",
        "category": "",
        "start_time": session.get("started_at") or (utterances[0].get("start_time") if utterances else ""),
        "end_time": session.get("ended_at") or (utterances[-1].get("end_time") if utterances else ""),
        "utterances": utterances,
        "action_items": [],
        "markdown": _markdown(utterances),
        "language": "",
        "geolocation": session.get("location"),
        "is_starred": bool(session.get("is_favorited", False)),
    }


def _rate_limited(error: Exception) -> bool:
    return "rate limited" in str(error).lower()


def fetch_conversations(
    client: MoriMCP,
    sessions: list[dict[str, Any]],
    interval: float = TRANSCRIPT_INTERVAL,
    on_record: Callable[[dict[str, Any]], None] = lambda _: None,
    attempts: int = RATE_LIMIT_ATTEMPTS,
) -> list[dict[str, Any]]:
    def fetch_one(session: dict[str, Any], remaining: int) -> dict[str, Any]:
        try:
            return normalize(session, fetch_transcript(client, str(session.get("id", ""))))
        except MoriError as error:
            if remaining <= 1 or not _rate_limited(error):
                raise
            time.sleep(RATE_LIMIT_BACKOFF)
            return fetch_one(session, remaining - 1)

    def fetch_tail(items: list[dict[str, Any]], last_started: float | None = None) -> list[dict[str, Any]]:
        if not items:
            return []
        wait = max(0.0, interval - (time.monotonic() - last_started)) if last_started is not None else 0.0
        time.sleep(wait)
        started = time.monotonic()
        head, *tail = items
        record = fetch_one(head, attempts)
        on_record(record)
        return [record] + fetch_tail(tail, started)

    return fetch_tail(sessions)


def sync(
    from_date: str | None = None,
    to_date: str | None = None,
    directory: Path = DEFAULT_ARCHIVE,
    interval: float = TRANSCRIPT_INTERVAL,
) -> dict[str, Any]:
    client = _client()
    sessions = list_sessions(client, from_date, to_date)
    existing = read_archive(directory)
    missing = [item for item in sessions if str(item.get("id", "")) not in existing]
    merged = dict(existing)
    written: list[Path] = []

    def persist(record: dict[str, Any]) -> None:
        """Rate limits make a full backfill long; keep every transcript that already landed."""
        merged[str(record["id"])] = record
        # ponytail: rewrites every day file per record (O(n^2) writes). Cheap next to the
        # ~6s inter-request wait; batch per day if the archive ever outgrows it.
        written.extend(write_archive(directory, merged))

    fetched = fetch_conversations(client, missing, interval, persist)
    paths = sorted({str(path) for path in written})
    state = {
        "source": "mori",
        "last_sync": datetime.now(timezone.utc).isoformat(),
        "listed": len(sessions),
        "fetched": len(fetched),
        "archived": len(merged),
        "files_written": paths,
    }
    _atomic_json(directory / "_state.json", state)
    return state


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="mori", description="Read-only Mori Transcript CLI")
    sub = parser.add_subparsers(dest="command", required=True)
    login_parser = sub.add_parser("login", help="Authorize this CLI with Mori")
    login_parser.add_argument("--no-browser", action="store_true")
    sessions = sub.add_parser("sessions", help="List Session metadata")
    sessions.add_argument("--from", dest="from_date")
    sessions.add_argument("--to", dest="to_date")
    transcript = sub.add_parser("transcript", help="Fetch one full Transcript")
    transcript.add_argument("session_or_uri")
    date = sub.add_parser("date", help="Fetch every Transcript for one local date")
    date.add_argument("date")
    sync_parser = sub.add_parser("sync", help="Idempotently archive unseen Transcripts")
    sync_parser.add_argument("--from", dest="from_date")
    sync_parser.add_argument("--to", dest="to_date")
    sync_parser.add_argument("--output-dir", type=Path, default=DEFAULT_ARCHIVE)
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        result = (
            {"status": "ok"} if args.command == "login" and login(not args.no_browser)
            else list_sessions(_client(), args.from_date, args.to_date) if args.command == "sessions"
            else fetch_transcript(_client(), args.session_or_uri) if args.command == "transcript"
            else fetch_conversations(_client(), list_sessions(_client(), args.date, args.date)) if args.command == "date"
            else sync(args.from_date, args.to_date, args.output_dir) if args.command == "sync"
            else {}
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except AuthRequired as error:
        print(str(error), file=sys.stderr)
        return 2
    except urllib.error.HTTPError as error:
        print(f"Mori API error: HTTP {error.code}", file=sys.stderr)
        return 3
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"Mori network error: {type(error).__name__}", file=sys.stderr)
        return 4
    except (MoriError, OSError, ValueError) as error:
        print(f"Mori error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
