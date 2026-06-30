#!/usr/bin/env python3
"""lifelog.py — マルチソース日次ライフログ収集器（全ソース・ローカル/対話認証なし）。

Sources:
  calendar  : osascript/AppleScript → Calendar.app（Mac公式カレンダー＝全アカウント集約。
              Apple Event 送信元が /usr/bin/osascript なのでオートメーション権限が
              claude 自動更新に左右されない。生DB(Calendar.sqlitedb)直読はFDA失効で不可）
  limitless : pendant.py へ委譲（export → 当日jsonlを読む）
  sessions  : Claude(~/.claude/projects/*/*.jsonl) + Codex(~/.codex/history.jsonl)
  typeless  : Typeless の音声入力DB（sqlite, refined_text + 入力先アプリ文脈）
  gmail     : himalaya(IMAP) の当日封筒メタ（time/from/subject/id）。本文は転記せず index のみ。
              本文は `himalaya message read -a gmail <id>` で live 取得する契約（world-model.md）。
  beeper    : Beeper Desktop のローカル HTTP API（127.0.0.1:23373）。Slack/iMessage/
              Twitter/Telegram/Matrix 等を集約した当日メッセージ。MCP ランタイム不要
              （token を読んで直接叩く）。低優先(bot等)除外。これが日次の canonical な
              「自分の1日」に含まれる5番目のソース（要約/書込は beeper-to-scb skill が担う）。

各 source は `fetch_<name>(date) -> list[dict]`。失敗時は [] を返し stderr に warn（gather を壊さない）。
出力は JSON（daily-report skill が分類・キュレートして日付ページへ転記）。

Usage:
  python3 lifelog.py gather [YYYY-MM-DD] [--pretty]
  python3 lifelog.py calendar|limitless|sessions|typeless|beeper [YYYY-MM-DD]
"""
from __future__ import annotations
import argparse, glob, json, os, re, shlex, sqlite3, subprocess, sys
from datetime import datetime, timezone, timedelta

JST = timezone(timedelta(hours=9))
HOME = os.path.expanduser("~")

# Calendar.app で「チェック済（可視）」のカレンダーだけ取り込む allowlist（他人/別用途は除外）。
# Calendar.app のサイドバーのチェック状態に対応。変えたい時はここを編集。
# 祝日カレンダー(日本の祝日 / Japan Holidays)は意図的に除外: ライフログのイベントとして無価値で、
# かつ繰り返し予定が大量にあり AppleScript の `whose` が激重(タイムアウト)になるため。
CHECKED_CALENDARS = [
    "Business ", "ルーティーン", "Takaの予定",
    "Shunsuke Takagi (General)", "takagi@plural-reality.com",
]


def _today() -> str:
    return datetime.now(JST).strftime("%Y-%m-%d")


# ---------- calendar : AppleScript → Calendar.app ----------
_CAL_AS = r'''
set sd to (current date)
set time of sd to 0
set day of sd to 1
set year of sd to __Y__
set month of sd to __M__
set day of sd to __D__
set ed to sd + (1 * days)
set wanted to {__WANTED__}
set out to ""
tell application "Calendar"
  repeat with cn in wanted
    try
      set cal to first calendar whose name is cn
      repeat with e in (every event of cal whose start date ≥ sd and start date < ed)
        set sdt to start date of e
        set hh to text -2 thru -1 of ("0" & ((hours of sdt) as string))
        set mm to text -2 thru -1 of ("0" & ((minutes of sdt) as string))
        set out to out & ((allday event of e) as string) & tab & hh & ":" & mm & tab & cn & tab & (summary of e) & linefeed
      end repeat
    end try
  end repeat
end tell
return out
'''


def fetch_calendar(d: str) -> list[dict]:
    y, m, day = (int(x) for x in d.split("-"))
    wanted = ", ".join('"%s"' % c for c in CHECKED_CALENDARS)
    script = (_CAL_AS.replace("__Y__", str(y)).replace("__M__", str(m))
              .replace("__D__", str(day)).replace("__WANTED__", wanted))
    # NOTE: AppleScript の `every event ... whose start date ...` は繰り返し予定(例: ルーティーンの
    # トレーニング)の展開で遅く不安定(30〜120s、たまにタイムアウト)。日次バックグラウンド用途なので
    # best-effort（タイムアウトで [] を返す）。高速化には EventKit が要るが Calendars TCC 権限が必要で、
    # 現状は osascript の Automation 権限のみ通る(EventKit は未認証=空)ため AppleScript を採用。
    try:
        r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=120)
    except Exception as e:
        print(f"[warn] calendar (osascript) timed out/failed (best-effort, skipped): {type(e).__name__}", file=sys.stderr)
        return []
    if r.returncode != 0:
        print(f"[warn] calendar (osascript) error: {r.stderr.strip()[:200]}", file=sys.stderr)
        return []
    out = []
    for line in r.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        out.append({"time": parts[1], "allday": parts[0].strip().lower() == "true",
                    "calendar": parts[2].strip(), "summary": "\t".join(parts[3:]).strip()})
    out.sort(key=lambda e: e["time"])
    return out


# ---------- limitless : delegate to pendant.py ----------
def fetch_limitless(d: str) -> list[dict]:
    pend = os.path.join(HOME, ".claude/scripts/pendant.py")
    try:
        subprocess.run(["python3", pend, "export", "--since", d, "--source", "limitless"],
                       capture_output=True, text=True, timeout=120)
    except Exception as e:
        print(f"[warn] limitless export failed: {e}", file=sys.stderr)
    path = os.path.join(HOME, ".claude/data/pendant-export/limitless", f"{d}.jsonl")
    if not os.path.exists(path):
        return []
    seen = {}
    for line in open(path):
        try:
            u = json.loads(line)["unified"]
        except Exception:
            continue
        seen[u.get("id")] = u
    # `title`/`headings` は Limitless の自動生成サマリで品質が低い(同じ "新しい仕事について" が
    # 量産される・STTノイズや他者私事をそのまま見出し化する)。鵜呑み禁止。LLM が実際に要約できるよう
    # 生トランスクリプト本文(`text`)も渡す。daily-report skill はこの `text` を読んで要約する。
    out = [{"time": (u.get("start_time", "") or "")[11:16],
            "title": u.get("title", ""),
            "headings": re.findall(r"(?m)^##\s+(.+?)\s*$", u.get("markdown", "") or ""),
            "text": _limitless_text(u.get("markdown", "") or "")}
           for u in seen.values()]
    out.sort(key=lambda e: e["time"])
    return out


def _limitless_text(md: str, cap: int = 1800) -> str:
    """markdown から話者/タイムスタンプの定型 prefix を剥がし、要約に使える素のトランスクリプトにする。
    `## 見出し` はそのまま改行で残し(文脈の区切り)、`- Speaker (ts): 発話` は発話だけ残す。"""
    strip = lambda s: re.sub(r"^-\s+.*?\):\s*", "", re.sub(r"^##\s+", "", s.strip()))
    body = [t for t in (strip(ln) for ln in md.splitlines()) if t]
    return "\n".join(body)[:cap]


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
        if on_day and isinstance(c, list):  # その日に書いた Scrapbox ページ(work[].links 用)
            for b in c:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    scrapbox.update(_scrapbox_targets(str((b.get("input") or {}).get("command", ""))))
        if o.get("type") == "user" and on_day and text and not text.startswith("<") and "Caveat" not in text[:30] and not first_prompt:
            first_prompt, first_time = " ".join(text.split())[:160], t.strftime("%H:%M")
        if o.get("type") == "assistant" and on_day and text:
            last_assistant = " ".join(text.split())[:200]
    return (first_prompt, first_time, last_assistant, sorted(scrapbox)) if first_prompt else None


def fetch_sessions(d: str) -> list[dict]:
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
    hist = os.path.join(HOME, ".codex/history.jsonl")
    if os.path.exists(hist):
        byses = {}
        for line in open(hist):
            try:
                o = json.loads(line)
                t = datetime.fromtimestamp(int(o.get("ts")), JST)
            except Exception:
                continue
            if t.strftime("%Y-%m-%d") != d:
                continue
            byses.setdefault(o.get("session_id", ""), []).append((t, o.get("text", "")))
        for sid, items in byses.items():
            items.sort()
            out.append({"agent": "codex", "hash": (sid or "")[:8],
                        "time": items[0][0].strftime("%H:%M"), "project": "codex",
                        "prompt": " ".join(items[0][1].split())[:160], "last": "", "scrapbox": []})
    out.sort(key=lambda e: e["time"] or "99:99")
    return out


# ---------- typeless : sqlite (UTC created_at → JST) ----------
def fetch_typeless(d: str) -> list[dict]:
    db = os.path.join(HOME, "Library/Application Support/Typeless/typeless.db")
    if not os.path.exists(db):
        return []
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        rows = con.execute(
            "SELECT datetime(created_at,'+9 hours'), focused_app_name, refined_text "
            "FROM history WHERE refined_text IS NOT NULL "
            "AND datetime(created_at,'+9 hours') LIKE ? ORDER BY created_at", (f"{d}%",)).fetchall()
        con.close()
    except Exception as e:
        print(f"[warn] typeless failed: {e}", file=sys.stderr)
        return []
    return [{"time": (r[0] or "")[11:16], "app": r[1] or "", "text": (r[2] or "").strip()} for r in rows]


# ---------- gmail : himalaya(IMAP) envelopes, metadata index only ----------
def fetch_gmail(d: str) -> list[dict]:
    """himalaya(IMAP) で当日(JST)受信の Gmail 封筒メタを取得（time/from/subject/id）。
    本文は転記しない（index のみ）。本文が要るときは `himalaya message read -a gmail <id>` で
    live 取得する契約（world-model.md）。直近 200 件を取得して Python 側で当日 JST に絞る
    （himalaya の after/before クエリ構文がバージョン依存で不安定なため）。best-effort。"""
    try:
        r = subprocess.run(
            ["himalaya", "envelope", "list", "-a", "gmail", "-o", "json", "-s", "200"],
            capture_output=True, text=True, timeout=60)
    except Exception as e:
        print(f"[warn] gmail (himalaya) failed (best-effort, skipped): {type(e).__name__}", file=sys.stderr)
        return []
    if r.returncode != 0:
        print(f"[warn] gmail (himalaya) error: {r.stderr.strip()[:200]}", file=sys.stderr)
        return []
    try:
        envs = json.loads(r.stdout)
    except Exception:
        return []

    def _jst(dt: str):
        try:
            return datetime.fromisoformat((dt or "").replace(" ", "T", 1)).astimezone(JST)
        except Exception:
            return None

    out = []
    for e in envs:
        t = _jst(e.get("date", ""))
        if not t or t.strftime("%Y-%m-%d") != d:
            continue
        frm = e.get("from") or {}
        out.append({"time": t.strftime("%H:%M"),
                    "from": frm.get("name") or frm.get("addr") or "",
                    "subject": (e.get("subject") or "").strip(),
                    "id": str(e.get("id", ""))})
    out.sort(key=lambda e: e["time"])
    return out


# ---------- beeper : Beeper Desktop local HTTP API (no MCP runtime needed) ----------
def fetch_beeper(d: str) -> list[dict]:
    """Beeper Desktop のローカル API から当日(JST)のメッセージを取得。token を直読して
    /v1/messages/search を date 範囲で叩く。低優先(bot/通知)は excludeLowPriority で除外。
    limit 上限は 20 なので cursor=oldestCursor + direction=before で遡って全件ページング
    （重複なし・最大25ページ=500件で打ち切り）。chats[chatID].title でチャット名を解決。
    Beeper API は文字列内に生の制御文字を返すため json.loads(strict=False) で読む。
    失敗時は取得済みの partial を返す (best-effort, gather を壊さない)。"""
    import urllib.request, urllib.parse
    token_path = os.path.join(HOME, ".config/beeper/token")
    if not os.path.exists(token_path):
        return []
    try:
        token = open(token_path).read().strip()
    except Exception:
        return []
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
    try:
        for _ in range(25):  # bounded: <=500 msgs/day
            data = _page(cursor)
            items += data.get("items") or []
            chats.update(data.get("chats") or {})
            cursor = data.get("oldestCursor")
            if not data.get("hasMore") or not cursor:
                break
    except Exception as e:
        print(f"[warn] beeper API unreachable/failed (best-effort, partial): {type(e).__name__}", file=sys.stderr)

    def _jst(ts: str) -> str:
        try:
            return datetime.fromisoformat((ts or "").replace("Z", "+00:00")).astimezone(JST).strftime("%H:%M")
        except Exception:
            return ""

    out = [{"time": _jst(m.get("timestamp", "")),
            "chat": (chats.get(m.get("chatID", ""), {}) or {}).get("title", ""),
            "sender": m.get("senderName", ""),
            "sent": bool(m.get("isSender")),
            "text": (m.get("text") or "").strip()}
           for m in items if (m.get("text") or "").strip()]
    out.sort(key=lambda e: e["time"])
    return out


def fetch_wip(d: str) -> list[dict]:
    """wip-crawl 自動処理のダイジェスト(~/.claude/.cache/wip-crawl/<date>.jsonl)。
    1行=1ページ処理 {time,project,title,summary,url,status}。未処理日は []。best-effort。"""
    path = os.path.join(HOME, ".claude/.cache/wip-crawl", f"{d}.jsonl")
    if not os.path.exists(path):
        return []
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
        return []
    out.sort(key=lambda e: e.get("time", ""))
    return out


SOURCES = {"calendar": fetch_calendar, "limitless": fetch_limitless,
           "sessions": fetch_sessions, "typeless": fetch_typeless,
           "gmail": fetch_gmail, "beeper": fetch_beeper, "wip": fetch_wip}


def gather(d: str) -> dict:
    return {"date": d, **{name: fn(d) for name, fn in SOURCES.items()}}


def main():
    p = argparse.ArgumentParser(prog="lifelog.py", description="Multi-source daily lifelog aggregator (local)")
    p.add_argument("command", choices=[*SOURCES.keys(), "gather"])
    p.add_argument("date", nargs="?", default=None, help="YYYY-MM-DD (default: today JST)")
    p.add_argument("--pretty", action="store_true")
    a = p.parse_args()
    d = a.date or _today()
    result = gather(d) if a.command == "gather" else SOURCES[a.command](d)
    print(json.dumps(result, ensure_ascii=False, indent=2 if a.pretty else None))


if __name__ == "__main__":
    main()
