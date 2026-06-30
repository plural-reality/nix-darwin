#!/usr/bin/env python3
"""claude-log-to-scb — Phase B/3: aggregate extracted.jsonl into per-entity
Scrapbox pages (people / projects) on takalog.

For each entity (person or project) seen across the conversations, upsert a
takalog page that carries a single MANAGED block (between ▼/▲ sentinels):
the conversations mentioning it, plus aggregated decisions/commitments. The
managed block is regenerated wholesale from extracted.jsonl (the complete SoT,
so this is idempotent and needs no per-line dedup); everything OUTSIDE the
sentinels — human/CRM content on pre-existing pages — is preserved verbatim.

This is the design's entity-index "distribute" step (Δ4): conversation pages
link to entities, and entity pages link back to conversations → the 2-hop graph.

Usage:
  aggregate_and_upsert.py [--project takalog] [--min-mentions 2] [--dry-run]
                          [--only ENTITY]
"""
import sys
import os
import json
import argparse
import subprocess
import urllib.parse
import time

from common import canon, esc, latest_archive
from ingest import clean_title, jst, HUB

CACHE_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
EXTRACTED_PATH = os.path.join(CACHE_DIR, "extracted.jsonl")
ARCHIVE_ROOT = os.path.expanduser("~/.claude/data/claude-export")
SCRAPBOX_WRITE = os.path.expanduser("~/.local/bin/scrapbox-write")
import os, sys  # noqa: E402
sys.path.insert(0, os.path.expanduser("~/.claude/scripts/lib"))
from normalize import normalize  # 表記ゆれ正規化(Scrapbox 書き込み境界)
S_START = "▼ claude会話ログ context"
S_END = "▲ claude会話ログ context"

# Entities always given a page even with a single mention (canonical, meaningful).
KNOWN = {
    "多元現実", "構想日本", "Cartographer", "Sonar", "Flux",
    "倍速会議", "倍速アンケート", "Bluemo / Shutaro Aoyama",
}


def sid():
    p = os.path.expanduser("~/.claude/settings.json")
    return json.load(open(p)).get("env", {}).get("SCRAPBOX_SID", "")


def fetch_lines(project, title, cookie):
    enc = urllib.parse.quote(title, safe="")
    r = subprocess.run(
        ["curl", "-s", "-b", f"connect.sid={cookie}", "-A", "Mozilla/5.0",
         f"https://scrapbox.io/api/pages/{project}/{enc}"],
        capture_output=True, text=True,
    )
    try:
        d = json.loads(r.stdout)
        if isinstance(d, dict) and "lines" in d:
            return [l["text"] for l in d["lines"]]
    except json.JSONDecodeError:
        pass
    return None


def render_block(entity, convs, decisions, commits):
    L = [f" [( {S_START} (claude-log-to-scb 自動管理・編集はこのブロック外へ)][claude code.icon]"]
    L.append(f"  [( 言及された会話 ({len(convs)}件):]")
    for c in convs:
        L.append(f"   [( [{c['title']}] ({c['date']})]")
        if c.get("one"):
            L.append(f"    [( {esc(c['one'])}]")
    if decisions:
        L.append("  [( 決定:]")
        for d in decisions:
            L.append(f"   [( {esc(d)}]")
    if commits:
        L.append("  [( コミット:]")
        for c in commits:
            L.append(f"   [( [⬜ {esc(c)}]]")
    L.append(f" [( {S_END}]")
    return L


def merge(existing, block):
    """Return full page lines (incl. title) with the managed block in place."""
    if existing is None:
        # new page: title is supplied via -t; body is just the block + hub link
        return [f"from [{HUB}]"] + block
    s = e = None
    for i, t in enumerate(existing):
        if S_START in t and s is None:
            s = i
        if S_END in t:
            e = i
    if s is not None and e is not None and e >= s:
        return existing[:s] + block + existing[e + 1:]
    # no managed block yet: insert right after the title, preserve the rest
    return existing[:1] + block + existing[1:]


def upsert(project, title, body_lines, dry_run, cookie):
    cmd = [SCRAPBOX_WRITE, "-p", project, "-t", title, "--verbatim"]
    if dry_run:
        cmd.append("--dry-run")
    env = dict(os.environ, SCRAPBOX_SID=cookie)
    r = subprocess.run(cmd, input=normalize("\n".join(body_lines)), capture_output=True, text=True, env=env)
    if r.returncode != 0:
        return None, r.stderr.strip()
    return (r.stdout.strip().splitlines() or [""])[-1], None


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default="takalog")
    ap.add_argument("--min-mentions", type=int, default=2)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", default=None, help="only this entity")
    args = ap.parse_args(argv)

    cookie = sid()
    cj = latest_archive()
    meta = {}
    if cj:
        for c in json.load(open(cj)):
            meta[c.get("uuid")] = {
                "title": clean_title(c.get("name"), f"claude会話 {(c.get('uuid') or '')[:8]}"),
                "date": jst(c.get("created_at")),
            }

    # entity -> {convs: {uuid: convinfo}, decisions: set, commits: set}
    ent = {}
    with open(EXTRACTED_PATH) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            o = json.loads(line)
            uuid = o.get("uuid")
            m = meta.get(uuid, {"title": f"claude会話 {(uuid or '')[:8]}", "date": ""})
            one = (o.get("ja_summary") or "").split("\n")[0].strip()[:60]
            for raw in (o.get("projects") or []) + (o.get("people") or []):
                name = canon(raw)
                if not name:
                    continue
                d = ent.setdefault(name, {"convs": {}, "decisions": set(), "commits": set()})
                d["convs"][uuid] = {"title": m["title"], "date": m["date"], "one": one}
                for x in o.get("decisions") or []:
                    d["decisions"].add(x.strip())
                for x in o.get("commitments") or []:
                    d["commits"].add(x.strip())

    written = skipped = errors = 0
    for entity, d in sorted(ent.items(), key=lambda kv: -len(kv[1]["convs"])):
        if args.only and entity != args.only:
            continue
        n = len(d["convs"])
        if not args.only and n < args.min_mentions and entity not in KNOWN:
            skipped += 1
            continue
        convs = sorted(d["convs"].values(), key=lambda c: c["date"], reverse=True)
        block = render_block(entity, convs, sorted(d["decisions"]), sorted(d["commits"]))
        existing = None if args.dry_run else fetch_lines(args.project, entity, cookie)
        full = merge(existing, block)
        body = full[1:] if existing is not None else full  # drop title only when it came from fetch
        url, err = upsert(args.project, entity, body, args.dry_run, cookie)
        if err:
            errors += 1
            sys.stderr.write(f"ERR {entity}: {err}\n")
            continue
        written += 1
        if not args.dry_run:
            time.sleep(0.4)
        print(f"{'DRY' if args.dry_run else 'OK '} [{n:>3} conv] {entity[:40]}  {url or ''}")

    print(f"\n--- entity pages written={written} skipped(<{args.min_mentions} mentions)={skipped} errors={errors} (distinct entities={len(ent)}) ---")


if __name__ == "__main__":
    main(sys.argv[1:])
