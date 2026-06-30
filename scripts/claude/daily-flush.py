#!/usr/bin/env python3
"""daily-flush.py — その日の session 要約を Scrapbox 日付ページへ反映する。

入力(決定的に読むだけ):
  summaries-<DATE>.jsonl : session-summary.sh が LLM 要約・分類した1セッション=1行。
  <DATE>.json (pending)  : daily-report-capture.sh の gather(calendar/limitless 等)。任意。

処理: project 分類ごとに work を集約 → curated JSON を組み立て → daily-page.py write に流す。
冪等性は daily-page.py の管理ブロック再生成に委ねる(work/schedule/lifelog は毎回その日の全量で上書き、
人間が書く Habbit/Task/Notes/メモは保持)。要約(LLM)と書込(本スクリプト)は分離 —
session-summary.sh が末尾でこれを呼ぶが、手動 `python3 daily-flush.py --dry-run` でも単体動作する。

Usage: python3 daily-flush.py [--dry-run] [YYYY-MM-DD]
Env:   SCRAPBOX_SID (write 時。daily-page.py が要求)
"""
from __future__ import annotations
import json, os, subprocess, sys
from datetime import datetime, timezone, timedelta

JST = timezone(timedelta(hours=9))
HOME = os.path.expanduser("~")
SCRIPTS = os.path.join(HOME, ".claude/scripts")
CACHE = os.path.join(HOME, ".claude/.cache/daily-report")

# project 分類 → Scrapbox 出力先(single source of truth)。
# lifelog=True のページにだけ Schedule / Limitless を載せる(個人ページに集約、team は work のみ)。
PROJECTS = {
    "tkgshn-private": {"scrapbox": "tkgshn-private", "template": "pin-diary", "icon": "tkgshn", "personal": True},
    "plural-reality": {"scrapbox": "plural-reality", "template": "team", "icon": "tkgshn", "personal": False},
}


def _title_path(date: str) -> str:
    y, m, d = (int(x) for x in date.split("-"))
    return f"{y}/{m}/{d}"  # ゼロ埋め無し(daily-page.py の _fmt と一致)


def _page_url(scrapbox: str, date: str) -> str:
    # Scrapbox は階層タイトルを URL パスにそのまま使える(例 2026/5/31)。URL 生成の唯一の場所。
    return f"https://scrapbox.io/{scrapbox}/{_title_path(date)}"


def main() -> None:
    dry = "--dry-run" in sys.argv or "--dry" in sys.argv
    pos = [a for a in sys.argv[1:] if not a.startswith("-")]
    date = pos[0] if pos else datetime.now(JST).strftime("%Y-%m-%d")

    # 移行ガード: 自動反映の開始日(auto-from.txt)より前の日付は手動 /daily-report 清書を保護して触らない。
    # 導入初日に既存ページを上書きしないための一回限りの配慮。--dry-run と日付明示指定では無視する。
    afp = os.path.join(CACHE, "auto-from.txt")
    if not dry and os.path.exists(afp):
        auto_from = open(afp).read().strip()
        if auto_from and date < auto_from:
            return

    summaries_path = os.path.join(CACHE, f"summaries-{date}.jsonl")
    if not os.path.exists(summaries_path):
        return
    summaries = []
    for line in open(summaries_path):
        try:
            summaries.append(json.loads(line))
        except Exception:
            continue
    if not summaries:
        return

    pending = {}
    pending_path = os.path.join(CACHE, f"{date}.json")
    if os.path.exists(pending_path):
        try:
            pending = json.load(open(pending_path))
        except Exception:
            pending = {}

    schedule = [{"time": e.get("time", ""), "allday": e.get("allday", False),
                 "summary": e.get("summary", ""), "calendar": e.get("calendar", "")}
                for e in pending.get("calendar", [])]
    lifelog = [{"time": e.get("time", ""), "summary": e.get("title", "")}
               for e in pending.get("limitless", []) if e.get("title")]

    active = [p for p in PROJECTS if any(s.get("project") == p for s in summaries)]
    daily_page = os.path.join(SCRIPTS, "daily-page.py")

    written = []
    for proj in active:
        cfg = PROJECTS[proj]
        # work の #hash = 決定的なセッションハッシュ(hash = sid[:8])。これは
        # `claude --resume <hash>` で再開できる唯一の安定 ID。session-summary.sh の LLM が
        # 出す hashes(コミットhash想定)は空 or 幻覚で不安定なため source にしない
        # (= "違うものに違う名前": セッションIDとコミットhashは別概念で、#hash 欄はセッション側)。
        work = [{"summary": s.get("summary", ""),
                 "hashes": [s["hash"]] if s.get("hash") else []}
                for s in summaries if s.get("project") == proj]
        others = [p for p in active if p != proj]
        crosslink = f"/{PROJECTS[others[0]]['scrapbox']}/{_title_path(date)}" if others else None
        curated = {
            "date": date, "project": cfg["scrapbox"], "template": cfg["template"], "icon": cfg["icon"],
            "work": work,
            "schedule": schedule if cfg["personal"] else [],
            "lifelog": lifelog if cfg["personal"] else [],
            "crosslink": crosslink,
        }
        cmd = ["python3", daily_page, "write"] + (["--dry-run"] if dry else [])
        r = subprocess.run(cmd, input=json.dumps(curated, ensure_ascii=False),
                           capture_output=True, text=True)
        out = (r.stdout + r.stderr).strip().replace("\n", " ⏎ ")
        written.append({"project": proj, "scrapbox": cfg["scrapbox"],
                        "url": _page_url(cfg["scrapbox"], date), "ok": r.returncode == 0})
        print(f"[{proj} → {cfg['scrapbox']}/{_title_path(date)}] {out[:300]}")

    # last-saved.json: 「この日、どの project の要約がどの Scrapbox ページへ反映されたか」の
    # 唯一の機械可読ソース。完了通知(session-summary.sh)と SessionStart リンク(last-session-link.sh)は
    # ここだけを読む。--dry-run は純粋な検証実行なので副作用(ファイル書込)を出さない。
    if not dry and written:
        last = {"date": date, "pages": written, "updated_at": datetime.now(JST).isoformat()}
        tmp = os.path.join(CACHE, "last-saved.json.tmp")
        with open(tmp, "w") as f:
            json.dump(last, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(CACHE, "last-saved.json"))


if __name__ == "__main__":
    main()
