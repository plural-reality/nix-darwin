#!/usr/bin/env python3
"""claude-log-to-scb — Phase B/2 (canonical, headless): extract Japanese
key-points + entities from each compact conversation via `claude -p` (haiku),
appending to extracted.jsonl. Parallel, incremental, Workflow-independent — so
the skill is self-contained and runnable headless (launchd / Phase D).

(For a very large first load, the Workflow tool's `model:'haiku'` fan-out is
faster, but this script is the canonical, reproducible step.)

Idempotent: a uuid already present in extracted.jsonl is skipped (--force
re-extracts all). Reads compact files written by split.py.

Usage: extract.py [--workers 6] [--limit N] [--force]
                  [--conv-dir DIR] [--out FILE]   # 既定は claude.ai 用。Claude Code セッションは
                                                  # --conv-dir .../conv-sessions --out .../extracted-sessions.jsonl
"""
import sys
import os
import json
import argparse
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor

CONV_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb/conv")
EXTRACTED_PATH = os.path.expanduser("~/.claude/.cache/claude-log-to-scb/extracted.jsonl")
MODEL = "claude-haiku-4-5"

PROMPT_HEAD = """あなたは AIアシスタントとの会話1件を分析し構造化抽出する。下のJSONオブジェクト「だけ」を出力せよ(マークダウン記法・前置き・説明を一切付けない):
{"ja_summary":"日本語3〜6行。この会話における AIアシスタントの回答の要点を会話全体としてまとめる(英語のsummaryに引きずられず日本語で。結論・要点だけ、前置き不要)","people":["会話に出てくる実在の人物名(日本語表記優先・一般名詞や役割名は除く)"],"projects":["案件/組織/プロダクト名(例: 構想日本, 多元現実, Cartographer, 倍速会議)"],"decisions":["この会話で決まったこと"],"commitments":["TODO/約束(誰が何を)"]}
該当が無い配列は [] にせよ。

入力(AIアシスタントとの会話。name=タイトル, summary=機械要約, transcript=human:/assistant: のターン):
"""


def already_done():
    done = set()
    if os.path.exists(EXTRACTED_PATH):
        with open(EXTRACTED_PATH) as f:
            for line in f:
                try:
                    done.add(json.loads(line)["uuid"])
                except (json.JSONDecodeError, KeyError):
                    pass
    return done


def parse_json(s):
    s = s.strip()
    if s.startswith("```"):
        s = s.split("```", 2)[1]
        if s[:4].lower() == "json":
            s = s[4:]
    i, j = s.find("{"), s.rfind("}")
    if i >= 0 and j > i:
        return json.loads(s[i:j + 1])
    raise ValueError("no JSON object in model output")


def extract_one(uuid):
    path = os.path.join(CONV_DIR, f"{uuid}.json")
    compact = open(path).read()
    prompt = PROMPT_HEAD + compact
    env = dict(os.environ, CLAUDE_DAILY_SUMMARY="1")  # avoid SessionEnd hook recursion
    r = subprocess.run(
        ["claude", "-p", "--model", MODEL, prompt],
        capture_output=True, text=True, env=env,
    )
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip()[:200] or "claude -p failed")
    obj = parse_json(r.stdout)
    obj["uuid"] = uuid
    for k in ("people", "projects", "decisions", "commitments"):
        obj.setdefault(k, [])
    obj.setdefault("ja_summary", "")
    return obj


def main(argv):
    global CONV_DIR, EXTRACTED_PATH
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--conv-dir", default=CONV_DIR, help="compact 会話ディレクトリ(既定: conv/)")
    ap.add_argument("--out", default=EXTRACTED_PATH, help="抽出結果 jsonl(既定: extracted.jsonl)")
    args = ap.parse_args(argv)
    # already_done()/extract_one() は呼び出し時にモジュール global を参照するので、ここで差し替える。
    CONV_DIR = os.path.expanduser(args.conv_dir)
    EXTRACTED_PATH = os.path.expanduser(args.out)

    index = json.load(open(os.path.join(CONV_DIR, "_index.json")))
    done = set() if args.force else already_done()
    todo = [u for u in index if u not in done]
    if args.limit:
        todo = todo[:args.limit]
    print(f"extract: {len(todo)} to do ({len(done)} already) with {args.workers} workers", file=sys.stderr)

    lock = threading.Lock()
    out = open(EXTRACTED_PATH, "w" if args.force else "a")  # --force rebuilds, else append
    ok = err = 0

    def work(u):
        nonlocal ok, err
        try:
            obj = extract_one(u)
            with lock:
                out.write(json.dumps(obj, ensure_ascii=False) + "\n")
                out.flush()
                ok += 1
            print(f"OK  {u[:8]}", file=sys.stderr)
        except Exception as e:
            with lock:
                err += 1
            print(f"ERR {u[:8]}: {e}", file=sys.stderr)

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        list(ex.map(work, todo))
    out.close()
    print(f"--- extracted ok={ok} err={err} ---", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
