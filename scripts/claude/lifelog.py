#!/usr/bin/env python3
"""lifelog.py — マルチソース日次ライフログ収集器（全ソース・ローカル/対話認証なし）。

Sources:
  calendar  : evkit snapshot → 署名済みEventKitBridge（有限範囲＋明示calendar selector。
              Calendar.app/Apple Eventsを経由せず、安定したbundle identityへTCCを閉じ込める）
  limitless : pendant.py へ委譲（指定日の全ページをJSON streamとして読む）
  mori      : Mori MCPからSession一覧→全文Transcriptだけを同期。Journalは取得しない。
  plaud     : Plaud公式CLI経由で全文Transcriptを同期。要約ではなく一次記録を使う。
  sessions  : Claude(~/.claude/projects/*/*.jsonl) + Codex(~/.codex/sessions/**/*.jsonl)
  typeless  : Typeless の音声入力DB（sqlite, refined_text + 入力先アプリ文脈）
  gmail     : himalaya(IMAP) の「すべてのメール」当日封筒メタ（送受信/time/相手/subject/id）。
              本文は転記せず index のみ。
              本文は `himalaya message read -a gmail <id>` で live 取得する契約（world-model.md）。
  beeper    : Beeper Desktop のローカル HTTP API（127.0.0.1:23373）。Slack/iMessage/
              Twitter/Telegram/Matrix 等を集約した当日メッセージ。MCP ランタイム不要
              （token を読んで直接叩く）。低優先(bot等)除外。これが日次の canonical な
              「自分の1日」に含まれる5番目のソース（要約/書込は beeper-to-scb skill が担う）。
  scrapbox  : Scrapbox API の当日更新ページメタ（private/plural/takalog）。本文は日付ページ側で
              必要なものだけ読み、ここでは title/time/link の index に留める。
  coast     : Coast Local CLI の当日利用メタ（録画時間/session/top app/domain）。OCR/画像は取得しない。

各 source は `fetch_<name>(date) -> JSON value`。失敗時は空値を返し stderr に warn（gather を壊さない）。
出力は JSON（daily-report skill が分類・キュレートして日付ページへ転記）。

Usage:
  python3 lifelog.py gather [YYYY-MM-DD] [--pretty]
  python3 lifelog.py calendar|limitless|mori|plaud|sessions|typeless|gmail|beeper|scrapbox|coast [YYYY-MM-DD]
"""
from __future__ import annotations
import argparse, glob, json, os, re, shlex, sqlite3, subprocess, sys
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass
from pathlib import Path
from typing import Any

JST = timezone(timedelta(hours=9))
HOME = os.path.expanduser("~")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SCRIPT_DIR, "lib"))
from scrapbox_session import resolve_session, resolve_sid

# Calendar.app で「チェック済（可視）」のカレンダーだけ取り込む allowlist（他人/別用途は除外）。
# Calendar.app のサイドバーのチェック状態に対応。変えたい時はここを編集。
# 本人の予定として扱うのは Calendar.app でチェックしているこの一覧だけ。
# Intervals.icu はトレーニング計画（可動）だが、その日の行動記録には含める。
CHECKED_CALENDARS = [
    "Taka の予定", "takagi@plural-reality.com", "Shunsuke Takagi (General)",
    "Business ", "ルーティーン", "Intervals.icu", "日本の祝日",
]

OK_STATE = "取得済み"
EMPTY_STATE = "記録なし"
TRANSIENT_STATE = "一時的に取得できません"
AUTH_STATE = "認証が必要"


@dataclass(frozen=True)
class SourceResult:
    data: Any
    state: str
    detail: str = ""


def _present(data: Any, detail: str = "") -> SourceResult:
    empty = data == [] or data == {} or data is None
    return SourceResult(data if data is not None else [], EMPTY_STATE if empty else OK_STATE, detail)


def _failed(state: str, detail: str, data: Any = None) -> SourceResult:
    return SourceResult([] if data is None else data, state, detail)


def _today() -> str:
    return datetime.now(JST).strftime("%Y-%m-%d")


# ---------- calendar : signed EventKitBridge → JSON stream ----------
EVKIT_BIN = os.environ.get("LIFELOG_EVKIT_BIN", "evkit")


def _calendar_range(d: str) -> tuple[datetime, datetime]:
    start = datetime.strptime(d, "%Y-%m-%d").replace(tzinfo=JST)
    return start, start + timedelta(days=1)


def _calendar_snapshot_spec(d: str) -> dict[str, Any]:
    start, end = _calendar_range(d)
    return {
        "rangeStart": start.isoformat(),
        "rangeEnd": end.isoformat(),
        "calendars": {"names": CHECKED_CALENDARS, "ids": []},
        "reminderLists": {"names": [], "ids": []},
        "includeCompleted": False,
    }


def _parse_instant(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _calendar_projection(row: dict[str, Any]) -> dict[str, Any]:
    start = _parse_instant(str(row["start"])).astimezone(JST)
    calendar = row.get("calendar") if isinstance(row.get("calendar"), dict) else {}
    return {
        "time": "00:00" if bool(row.get("allDay")) else start.strftime("%H:%M"),
        "allday": bool(row.get("allDay")),
        "calendar": str(calendar.get("name", "")).strip(),
        "summary": str(row.get("title", "")).strip(),
    }


def _deduplicate_calendar_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique = {
        (row["time"], row["allday"], row["calendar"], row["summary"]): row
        for row in rows
    }
    return sorted(unique.values(), key=lambda row: (
        row["time"], row["calendar"], row["summary"], row["allday"]))


def fetch_calendar(d: str) -> SourceResult:
    try:
        r = subprocess.run(
            [EVKIT_BIN, "snapshot"],
            input=json.dumps(_calendar_snapshot_spec(d), ensure_ascii=False),
            capture_output=True, text=True, timeout=15)
    except Exception as e:
        print(f"[warn] calendar (evkit) failed: {type(e).__name__}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(e).__name__)
    if r.returncode != 0:
        print(f"[warn] calendar (evkit) error: {r.stderr.strip()[:200]}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, "EventKitBridgeへ接続できませんでした")
    try:
        payload = json.loads(r.stdout)
        events = payload["events"]
        containers = payload["containers"]["calendars"]
        event_error = payload.get("errors", {}).get("events")
        if not isinstance(events, list) or not isinstance(containers, list):
            raise TypeError("events/containers")
    except Exception:
        return _failed(TRANSIENT_STATE, "EventKit応答を解釈できませんでした")
    if event_error:
        code = str(event_error.get("code", "")) if isinstance(event_error, dict) else ""
        state = AUTH_STATE if code.startswith("authorization_") else TRANSIENT_STATE
        detail = (str(event_error.get("message", "")) if isinstance(event_error, dict)
                  else "EventKitの予定読取に失敗しました")
        return _failed(state, detail[:200])
    resolved = {
        str(item.get("name", "")) for item in containers if isinstance(item, dict)
    }
    missing = [name for name in CHECKED_CALENDARS if name not in resolved]
    if missing:
        return _failed(
            TRANSIENT_STATE,
            "EventKitの対象カレンダーが見つかりません: " + " / ".join(missing))
    start, end = _calendar_range(d)
    try:
        within_day = [
            row for row in events
            if isinstance(row, dict)
            and start <= _parse_instant(str(row["start"])).astimezone(JST) < end
        ]
        out = _deduplicate_calendar_rows([
            _calendar_projection(row) for row in within_day
        ])
    except Exception:
        return _failed(TRANSIENT_STATE, "EventKitの予定データを解釈できませんでした")
    return _present(out, f"{len(out)}件")


# ---------- limitless : delegate to pendant.py ----------
def fetch_limitless(d: str) -> SourceResult:
    # リポジトリ直実行と Home Manager 投影後の両方で、同じ sibling adapter を使う。
    pend = os.path.join(SCRIPT_DIR, "pendant.py")
    try:
        result = subprocess.run(
            ["python3", pend, "-f", "json", "date", d, "--source", "limitless"],
            capture_output=True, text=True, timeout=120)
    except Exception as e:
        print(f"[warn] limitless fetch failed: {type(e).__name__}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(e).__name__)
    if result.returncode != 0:
        print(f"[warn] limitless fetch error: {result.stderr.strip()[:200]}", file=sys.stderr)
        state = AUTH_STATE if "401" in result.stderr or "403" in result.stderr else TRANSIENT_STATE
        return _failed(state, "Limitless APIから取得できませんでした")
    try:
        items = json.loads(result.stdout)
    except Exception:
        return _failed(TRANSIENT_STATE, "Limitless応答を解釈できませんでした")
    seen = {u.get("id"): u for u in items if u.get("id")}
    # `title`/`headings` は Limitless の自動生成サマリで品質が低い(同じ "新しい仕事について" が
    # 量産される・STTノイズや他者私事をそのまま見出し化する)。鵜呑み禁止。LLM が実際に要約できるよう
    # 生トランスクリプト本文(`text`)も渡す。daily-report skill はこの `text` を読んで要約する。
    out = [{"time": (u.get("start_time", "") or "")[11:16],
            "title": u.get("title", ""),
            "headings": re.findall(r"(?m)^##\s+(.+?)\s*$", u.get("markdown", "") or ""),
            "text": _limitless_text(u.get("markdown", "") or "")}
           for u in seen.values()]
    out.sort(key=lambda e: e["time"])
    return _present(out, f"{len(out)}件")


def _limitless_text(md: str, cap: int = 1800) -> str:
    """markdown から話者/タイムスタンプの定型 prefix を剥がし、要約に使える素のトランスクリプトにする。
    `## 見出し` はそのまま改行で残し(文脈の区切り)、`- Speaker (ts): 発話` は発話だけ残す。"""
    strip = lambda s: re.sub(r"^-\s+.*?\):\s*", "", re.sub(r"^##\s+", "", s.strip()))
    body = [t for t in (strip(ln) for ln in md.splitlines()) if t]
    return "\n".join(body)[:cap]


# ---------- Mori / Plaud : provider sync -> canonical daily JSONL ----------
def _transcript_archive_root() -> Path:
    return Path(os.environ.get(
        "LIFELOG_TRANSCRIPT_DIR", "~/.claude/data/pendant-export")).expanduser()


def _archived_transcripts(source: str, d: str) -> list[dict]:
    path = _transcript_archive_root() / source / f"{d}.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def _transcript_preview(row: dict, cap: int = 1800) -> str:
    text = "\n".join(
        str(item.get("text", "")) for item in row.get("utterances", [])
        if item.get("text"))
    return text[:cap]


def _fetch_synced_transcripts(source: str, d: str, command: list[str]) -> SourceResult:
    result = subprocess.run(command, capture_output=True, text=True, timeout=900)
    rows = _archived_transcripts(source, d)
    out = [{"time": str(row.get("start_time", ""))[11:16],
            "title": row.get("title", ""),
            "text": _transcript_preview(row),
            "utterance_count": len(row.get("utterances", [])),
            "archive": str(_transcript_archive_root() / source / f"{d}.jsonl")}
           for row in rows]
    if result.returncode == 0:
        return _present(out, f"{len(out)}件 / 全文はarchive")
    state = AUTH_STATE if result.returncode == 2 else TRANSIENT_STATE
    detail = (result.stderr.strip().splitlines() or [f"{source} sync failed"])[-1][:200]
    return _failed(state, detail, out)


def fetch_mori(d: str) -> SourceResult:
    return _fetch_synced_transcripts(
        "mori", d,
        [sys.executable, os.path.join(SCRIPT_DIR, "mori.py"), "sync", "--from", d, "--to", d])


def fetch_plaud(d: str) -> SourceResult:
    return _fetch_synced_transcripts(
        "plaud", d,
        [sys.executable, os.path.join(SCRIPT_DIR, "plaud-sync.py"), "--from", d, "--to", d])


# ---------- sessions : Claude + Codex ----------
KNOWN_PROJECTS = {"tkgshn-private", "plural-reality", "takalog"}
_DATE_TITLE = re.compile(r"^\d{4}/\d{1,2}/\d{1,2}$")


# scrapbox-write はオプション式 CLI: -p/--project <name>(既定 plural-reality) / -t/--title <title>。
# 本文は stdin・位置引数は無い。よって scrapbox-write トークンの直後に続く「自分のオプション列」だけを
# 読む(値を取らないフラグは読み飛ばし、未知トークン=次のコマンド/リダイレクトに当たったら打ち切る)。
_SBW_TITLE_OPT = {"-t", "--title"}
_SBW_PROJ_OPT = {"-p", "--project"}
_SBW_VAL_OPT = _SBW_TITLE_OPT | _SBW_PROJ_OPT | {"--mode"}
_SBW_DRY_OPT = {"-n", "--dry-run"}
_SBW_NOVAL = ({"-a", "--append", "-P", "--prepend", "-V", "--verbatim", "-g", "--gray",
               "--no-gray", "--human", "-h", "--help"} | _SBW_DRY_OPT)


def _scrapbox_targets(cmd: str) -> list[str]:
    """Bash コマンド中の `scrapbox-write -t <title> [-p <project>]` 呼び出しから書込先 /proj/Title を
    抽出する。canonical な doc 書込パスは scrapbox-write CLI。日付ページ(YYYY/M/D)は日報そのものなので、
    --dry-run(=書込なし)・ツール自体の調査(`cat scrapbox-write` 等で -t を持たない)も除外する。
    daily-report skill はこれを work[].links に入れ、ハッシュ行の下に一段下げてリンクを出す。
    ponytail: 検出は scrapbox-write CLI 経由の実書込のみ(直 API patch / cosense-proxy 経由は対象外)。"""
    if "scrapbox-write" not in cmd:
        return []
    try:
        toks = shlex.split(cmd)
    except Exception:
        return []
    out = []
    i, n = 0, len(toks)
    while i < n:
        if os.path.basename(toks[i]) != "scrapbox-write":
            i += 1
            continue
        proj, title, dry, j = "plural-reality", None, False, i + 1
        while j < n:                                   # scrapbox-write 自身のオプション列だけ消費
            tk = toks[j]
            # 値を取るオプション。値が `-` 始まり = CLI 側でも欠落扱い(isMissingOptionValue)なので消費しない。
            if tk in _SBW_VAL_OPT and j + 1 < n and not toks[j + 1].startswith("-"):
                title = toks[j + 1] if tk in _SBW_TITLE_OPT else title
                proj = toks[j + 1] if tk in _SBW_PROJ_OPT else proj
                j += 2
            elif tk in _SBW_NOVAL:
                dry = dry or tk in _SBW_DRY_OPT
                j += 1
            else:
                break                                  # 値でない素トークン=次のコマンド/リダイレクト
        title = (title or "").strip()
        # "$" を含む = ループ内 `-t "$t"` 等で shell 変数が未展開のまま渡されたゴミ(壊れたリンクになる)→除外
        if title and "$" not in title and not dry and proj in KNOWN_PROJECTS and not _DATE_TITLE.match(title):
            out.append(f"/{proj}/{title}")
        i = j
    return list(dict.fromkeys(out))                    # 順序保持 dedup


def _claude_session(path: str, d: str):
    """Return (first_prompt, first_time_on_d, last_assistant_on_d, scrapbox_targets) or None."""
    first_prompt, first_time, last_assistant = "", "", ""
    scrapbox: set[str] = set()
    for line in open(path):
        try:
            o = json.loads(line)
        except Exception:
            continue
        ts = o.get("timestamp")
        t = None
        if ts:
            try:
                t = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(JST)
            except Exception:
                t = None
        on_day = bool(t) and t.strftime("%Y-%m-%d") == d
        msg = o.get("message", {}) or {}
        c = msg.get("content")
        text = c if isinstance(c, str) else (
            "".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
            if isinstance(c, list) else "")
        text = text.strip()
        # command dispatchだけでは保存・readbackを証明できないため、tool_useからScrapbox linkを推測しない。
        if o.get("type") == "user" and on_day and text and not text.startswith("<") and "Caveat" not in text[:30] and not first_prompt:
            first_prompt, first_time = " ".join(text.split())[:160], t.strftime("%H:%M")
        if o.get("type") == "assistant" and on_day and text:
            last_assistant = " ".join(text.split())[:200]
    return (first_prompt, first_time, last_assistant, sorted(scrapbox)) if first_prompt else None


def fetch_sessions(d: str) -> SourceResult:
    out = []
    for f in glob.glob(os.path.join(HOME, ".claude/projects/*/*.jsonl")):
        if os.path.basename(os.path.dirname(f)) == "subagents":
            continue
        try:
            if datetime.fromtimestamp(os.path.getmtime(f), JST).strftime("%Y-%m-%d") < d:
                continue  # 当日以降に更新されたファイルだけ（古いセッションを読まない）
            if sum(1 for _ in open(f)) <= 10:
                continue
        except Exception:
            continue
        info = _claude_session(f, d)
        if not info:
            continue
        out.append({"agent": "claude", "hash": os.path.basename(f)[:8], "time": info[1],
                    "project": os.path.basename(os.path.dirname(f)),
                    "prompt": info[0], "last": info[2], "scrapbox": info[3]})
    # history.jsonl は旧 UI の入力履歴で、現在の Codex Desktop task は sessions/**/*.jsonl が正本。
    # 当日更新された rollout だけを読み、user_message と最後の agent_message を1 taskへ畳む。
    codex: dict[str, dict] = {}
    roots = (os.path.join(HOME, ".codex/sessions/**/*.jsonl"),
             os.path.join(HOME, ".codex/archived_sessions/**/*.jsonl"))
    for f in (path for pattern in roots for path in glob.glob(pattern, recursive=True)):
        try:
            if datetime.fromtimestamp(os.path.getmtime(f), JST).strftime("%Y-%m-%d") < d:
                continue
            info = _codex_session(f, d)
        except Exception:
            continue
        if info:
            codex[info["session_id"]] = info
    out.extend(codex.values())
    out.sort(key=lambda e: e["time"] or "99:99")
    return _present(out, f"{len(out)}件")


def _codex_session(path: str, d: str) -> dict | None:
    meta, first_prompt, first_time, final = {}, "", "", ""
    active = False
    sid = Path(path).stem.rsplit("-", 5)[-1]
    for line in open(path):
        try:
            o = json.loads(line)
        except Exception:
            continue
        payload = o.get("payload") or {}
        if o.get("type") == "session_meta":
            meta = payload
            sid = payload.get("id") or sid
        try:
            t = datetime.fromisoformat((o.get("timestamp") or "").replace("Z", "+00:00")).astimezone(JST)
        except Exception:
            t = None
        if not t or t.strftime("%Y-%m-%d") != d or o.get("type") != "event_msg":
            continue
        kind = payload.get("type")
        text = str(payload.get("message") or "").strip()
        if kind == "user_message" and text and not first_prompt:
            first_prompt, first_time = " ".join(text.split())[:160], t.strftime("%H:%M")
        if kind == "agent_message" and text and payload.get("phase") == "final_answer":
            final = " ".join(text.split())[:200]
        if kind == "agent_message" and text and payload.get("phase") != "final_answer":
            active = True
    if not first_prompt:
        return None
    cwd = str(meta.get("cwd") or "")
    return {"agent": "codex", "hash": str(sid)[:8], "time": first_time,
            "project": os.path.basename(cwd.rstrip("/")) or "codex", "prompt": first_prompt,
            "last": final, "state": "完了" if final else "作業中" if active else "状態未確認",
            "scrapbox": [], "session_id": sid}


# ---------- typeless : sqlite (UTC created_at → JST) ----------
def fetch_typeless(d: str) -> SourceResult:
    db = os.path.join(HOME, "Library/Application Support/Typeless/typeless.db")
    if not os.path.exists(db):
        return _failed(TRANSIENT_STATE, "Typeless DBがありません")
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        rows = con.execute(
            "SELECT datetime(created_at,'+9 hours'), focused_app_name, refined_text "
            "FROM history WHERE refined_text IS NOT NULL "
            "AND datetime(created_at,'+9 hours') LIKE ? ORDER BY created_at", (f"{d}%",)).fetchall()
        con.close()
    except Exception as e:
        print(f"[warn] typeless failed: {e}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(e).__name__)
    out = [{"time": (r[0] or "")[11:16], "app": r[1] or "", "text": (r[2] or "").strip()} for r in rows]
    return _present(out, f"{len(out)}件")


# ---------- gmail : himalaya(IMAP) all-mail envelopes, metadata index only ----------
def fetch_gmail(d: str) -> SourceResult:
    """himalaya(IMAP) で当日(JST)送受信の Gmail 封筒メタを取得。
    本文は転記しない（index のみ）。本文が要るときは `himalaya message read -a gmail <id>` で
    live 取得する契約（world-model.md）。対象日をIMAP queryで先に絞り、全pageを取得してからJSTで
    再検証する。新しいメールが500件以上あっても過去日のbackfillを欠落させない。"""
    folder = "[Gmail]/すべてのメール"
    day = datetime.strptime(d, "%Y-%m-%d").date()
    previous, following = day - timedelta(days=1), day + timedelta(days=1)
    page_size, max_pages = 200, 50
    envs, complete, error_text = [], False, ""
    for page in range(1, max_pages + 1):
        try:
            result = subprocess.run(
                ["himalaya", "envelope", "list", "-a", "gmail", "-f", folder,
                 "-o", "json", "-s", str(page_size), "-p", str(page),
                 "after", previous.isoformat(), "and", "before", following.isoformat(),
                 "order", "by", "date", "asc"],
                capture_output=True, text=True, timeout=60)
        except Exception as error:
            return _failed(TRANSIENT_STATE, type(error).__name__)
        if result.returncode != 0:
            error_text = result.stderr.strip()
            if page > 1 and "out of bound" in error_text.casefold():
                complete = True
                break
            state = AUTH_STATE if any(code in error_text.casefold() for code in ("auth", "login", "credential")) else TRANSIENT_STATE
            return _failed(state, "Gmailから取得できませんでした", envs)
        try:
            batch = json.loads(result.stdout)
        except Exception:
            return _failed(TRANSIENT_STATE, "Gmail応答を解釈できませんでした", envs)
        envs.extend(batch)
        if len(batch) < page_size:
            complete = True
            break

    def _jst(dt: str):
        try:
            return datetime.fromisoformat((dt or "").replace(" ", "T", 1)).astimezone(JST)
        except Exception:
            return None

    try:
        import tomllib
        cfg = Path(HOME, "Library/Application Support/himalaya/config.toml")
        own = ((tomllib.loads(cfg.read_text()).get("accounts") or {}).get("gmail") or {}).get("email", "")
    except Exception:
        own = ""
    unique = {str(e.get("id", "")): e for e in envs if e.get("id") is not None}
    out = []
    for e in unique.values():
        t = _jst(e.get("date", ""))
        if not t or t.strftime("%Y-%m-%d") != d:
            continue
        frm, to = e.get("from") or {}, e.get("to") or {}
        sent = bool(own) and (frm.get("addr") or "").casefold() == own.casefold()
        peer = to if sent else frm
        out.append({"time": t.strftime("%H:%M"),
                    "direction": "送信" if sent else "受信",
                    "peer": peer.get("name") or peer.get("addr") or "",
                    "from": frm.get("name") or frm.get("addr") or "",
                    "subject": (e.get("subject") or "").strip(),
                    "id": str(e.get("id", "")), "folder": folder})
    out.sort(key=lambda e: e["time"])
    return (_present(out, f"{len(out)}件") if complete
            else _failed(TRANSIENT_STATE, f"{max_pages * page_size}件の安全上限に到達", out))


# ---------- beeper : Beeper Desktop local HTTP API (no MCP runtime needed) ----------
def fetch_beeper(d: str) -> SourceResult:
    """Beeper Desktop のローカル API から当日(JST)のメッセージを取得。token を直読して
    /v1/messages/search を date 範囲で叩く。低優先(bot/通知)は excludeLowPriority で除外。
    limit 上限は 20 なので cursor=oldestCursor + direction=before で遡って全件ページング
    （重複なし・安全上限100ページ=2,000件）。chats[chatID].title でチャット名を解決。
    Beeper API は文字列内に生の制御文字を返すため json.loads(strict=False) で読む。
    失敗時は取得済みの partial を返す (best-effort, gather を壊さない)。"""
    import urllib.request, urllib.parse
    token_path = os.path.join(HOME, ".config/beeper/token")
    if not os.path.exists(token_path):
        return _failed(AUTH_STATE, "Beeper tokenがありません")
    try:
        token = open(token_path).read().strip()
    except Exception:
        return _failed(AUTH_STATE, "Beeper tokenを読めません")
    nd = (datetime.strptime(d, "%Y-%m-%d") + timedelta(days=1)).strftime("%Y-%m-%d")
    base = {"dateAfter": f"{d}T00:00:00+09:00", "dateBefore": f"{nd}T00:00:00+09:00",
            "excludeLowPriority": "true", "limit": 20}

    def _page(cursor):
        params = dict(base, **({"cursor": cursor, "direction": "before"} if cursor else {}))
        req = urllib.request.Request(
            "http://127.0.0.1:23373/v1/messages/search?" + urllib.parse.urlencode(params),
            headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode("utf-8"), strict=False)

    items: list[dict] = []
    chats: dict = {}
    cursor = None
    has_more = False
    partial_error = ""
    try:
        for _ in range(100):  # bounded: <=2,000 msgs/day
            data = _page(cursor)
            items += data.get("items") or []
            chats.update(data.get("chats") or {})
            cursor = data.get("oldestCursor")
            has_more = bool(data.get("hasMore") and cursor)
            if not has_more:
                break
    except Exception as e:
        print(f"[warn] beeper API unreachable/failed (best-effort, partial): {type(e).__name__}", file=sys.stderr)
        partial_error = type(e).__name__
    if has_more:
        print("[warn] beeper reached safety limit (2,000 messages; partial)", file=sys.stderr)

    def _jst(ts: str) -> str:
        try:
            return datetime.fromisoformat((ts or "").replace("Z", "+00:00")).astimezone(JST).strftime("%H:%M")
        except Exception:
            return ""

    rows = [{"time": _jst(m.get("timestamp", "")),
             "chat": (chats.get(m.get("chatID", ""), {}) or {}).get("title", "") or "チャット名なし",
             "sent": bool(m.get("isSender"))}
            for m in items]
    grouped = {chat: [row for row in rows if row["chat"] == chat] for chat in {row["chat"] for row in rows}}
    out = [{"chat": chat, "first": min((row["time"] for row in group), default=""),
            "last": max((row["time"] for row in group), default=""), "count": len(group),
            "sent_count": sum(1 for row in group if row["sent"]),
            "received_count": sum(1 for row in group if not row["sent"])}
           for chat, group in grouped.items()]
    out.sort(key=lambda e: (e["first"], e["chat"]))
    return (_failed(TRANSIENT_STATE, partial_error or "2,000件の安全上限に到達", out)
            if partial_error or has_more else _present(out, f"{sum(e['count'] for e in out)}件 / {len(out)}チャット"))


def fetch_wip(d: str) -> SourceResult:
    """wip-crawl 自動処理のダイジェスト(~/.claude/.cache/wip-crawl/<date>.jsonl)。
    1行=1ページ処理 {time,project,title,summary,url,status}。未処理日は []。best-effort。"""
    path = os.path.join(HOME, ".claude/.cache/wip-crawl", f"{d}.jsonl")
    if not os.path.exists(path):
        return _present([], "0件")
    out = []
    try:
        with open(path, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if ln:
                    try:
                        out.append(json.loads(ln))
                    except Exception:
                        pass
    except Exception as e:
        print(f"[warn] wip digest failed: {e}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(e).__name__)
    out.sort(key=lambda e: e.get("time", ""))
    return _present(out, f"{len(out)}件")


# ---------- scrapbox : updated-page metadata only ----------
def fetch_scrapbox(d: str) -> SourceResult:
    """当日更新されたページの index。本文や私信を gather JSON に複製しない。"""
    import urllib.request
    session = resolve_session()
    sid = session.sid
    if not sid:
        print("[warn] scrapbox SID unavailable (best-effort, skipped)", file=sys.stderr)
        state = AUTH_STATE if session.state == "認証が必要" else TRANSIENT_STATE
        return _failed(state, session.detail or "Scrapbox sessionを確認できません")
    start = datetime.strptime(d, "%Y-%m-%d").replace(tzinfo=JST)
    end = start + timedelta(days=1)

    def pages(project: str) -> tuple[list[dict], bool]:
        acc = []
        complete = False
        for skip in range(0, 500, 100):
            url = f"https://scrapbox.io/api/pages/{project}?limit=100&skip={skip}&sort=updated"
            req = urllib.request.Request(
                url, headers={"Cookie": f"connect.sid={sid}", "User-Agent": "personal-ops/1.0"})
            data = json.loads(urllib.request.urlopen(req, timeout=12).read().decode("utf-8"))
            batch = data.get("pages") or []
            acc += [p for p in batch
                    if start <= datetime.fromtimestamp(int(p.get("updated", 0)), JST) < end]
            if len(batch) < 100 or (batch and datetime.fromtimestamp(int(batch[-1].get("updated", 0)), JST) < start):
                complete = True
                break
        return ([{"time": datetime.fromtimestamp(int(p.get("updated", 0)), JST).strftime("%H:%M"),
                  "project": project, "title": p.get("title", ""),
                  "link": f"/{project}/{p.get('title', '')}"} for p in acc if p.get("title")], complete)

    out = []
    failures = []
    for project in ("tkgshn-private", "plural-reality", "takalog"):
        try:
            batch, complete = pages(project)
            out += batch
            failures += ([] if complete else [f"{project}: 500件上限"])
        except Exception as e:
            print(f"[warn] scrapbox API failed for {project} (best-effort, partial): {type(e).__name__}",
                  file=sys.stderr)
            failures.append(f"{project}: {type(e).__name__}")
    ordered = sorted(out, key=lambda e: (e["time"], e["project"], e["title"]))
    return (_failed(TRANSIENT_STATE, " / ".join(failures), ordered)
            if failures else _present(ordered, f"{len(ordered)}件"))


# ---------- coast : aggregate metadata only (no OCR/screenshots) ----------
def fetch_coast(d: str) -> SourceResult:
    """Coast Local の低機微な利用メタだけを取得。録画本文は明示的調査時まで読まない。"""
    coast = os.path.join(HOME, ".local/bin/coast")
    if not os.path.exists(coast):
        return _failed(TRANSIENT_STATE, "Coast Local CLIがありません", {})

    def run(args: list[str]) -> dict:
        r = subprocess.run([coast, *args, "--tr", d, "--json"], capture_output=True, text=True, timeout=30)
        if r.returncode != 0 or not r.stdout.strip():
            raise RuntimeError("Coast Local CLI returned no usable result")
        data = json.loads(r.stdout)
        if not isinstance(data, dict):
            raise RuntimeError("Coast Local CLI returned an unexpected shape")
        return data

    try:
        usage = run(["usage", "time"])
        sessions = run(["usage", "sessions", "--gap", "10"])
        apps = run(["usage", "top-applications", "--limit", "12"])
        domains = run(["usage", "top-domains", "--limit", "12"])
        data = {"recorded_seconds": usage.get("recorded_seconds", 0),
                "recorded_human": usage.get("recorded_seconds_human", "0s"),
                "sessions": sessions.get("sessions", []), "session_count": sessions.get("session_count", 0),
                "applications": apps.get("items", []), "domains": domains.get("items", [])}
        return SourceResult(data, OK_STATE if data["recorded_seconds"] or data["session_count"] else EMPTY_STATE,
                            f"録画{data['recorded_human']} / {data['session_count']}まとまり")
    except Exception as e:
        print(f"[warn] coast CLI failed (best-effort, skipped): {type(e).__name__}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(e).__name__, {})


SOURCES = {"calendar": fetch_calendar, "limitless": fetch_limitless,
           "mori": fetch_mori, "plaud": fetch_plaud,
           "sessions": fetch_sessions, "typeless": fetch_typeless,
           "gmail": fetch_gmail, "beeper": fetch_beeper, "scrapbox": fetch_scrapbox,
           "coast": fetch_coast, "wip": fetch_wip}
SOURCE_NAMES = {"calendar": "Apple Calendar", "limitless": "Limitless",
                "mori": "Mori Transcript", "plaud": "Plaud Transcript",
                "sessions": "エージェント作業", "typeless": "Typeless", "gmail": "Gmail",
                "beeper": "Beeper", "scrapbox": "Scrapbox", "coast": "Coast Local",
                "wip": "WIP自動処理"}


def _capture(name: str, d: str) -> SourceResult:
    try:
        value = SOURCES[name](d)
    except Exception as error:
        print(f"[warn] {name} collector failed closed: {type(error).__name__}", file=sys.stderr)
        return _failed(TRANSIENT_STATE, type(error).__name__, {} if name == "coast" else [])
    result = value if isinstance(value, SourceResult) else _present(value)
    data = (result.data | {"state": result.state}
            if name == "coast" and isinstance(result.data, dict) else result.data)
    return SourceResult(data, result.state, result.detail)


def gather(d: str) -> dict:
    outcomes = {name: _capture(name, d) for name in SOURCES}
    return {"date": d, **{name: outcome.data for name, outcome in outcomes.items()},
            "collection": [{"name": SOURCE_NAMES[name], "state": outcome.state,
                            **({"detail": outcome.detail} if outcome.detail else {})}
                           for name, outcome in outcomes.items()]}


def main():
    p = argparse.ArgumentParser(prog="lifelog.py", description="Multi-source daily lifelog aggregator (local)")
    p.add_argument("command", choices=[*SOURCES.keys(), "gather"])
    p.add_argument("date", nargs="?", default=None, help="YYYY-MM-DD (default: today JST)")
    p.add_argument("--pretty", action="store_true")
    a = p.parse_args()
    d = a.date or _today()
    result = gather(d) if a.command == "gather" else _capture(a.command, d).data
    print(json.dumps(result, ensure_ascii=False, indent=2 if a.pretty else None))


if __name__ == "__main__":
    main()
