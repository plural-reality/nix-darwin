#!/usr/bin/env python3
"""claude-log-to-scb — poll claude.ai's internal API and merge new/changed
conversations into a conversations.json (the SAME artifact the manual export
produces), so split → extract → ingest → aggregate consume it unchanged. This
replaces the manual "設定→データを書き出す→メール" export with a headless puller.

Auth rides Claude Desktop's own session: claude_cookies.py decrypts the live
sessionKey + cf_clearance (+ org) from the desktop cookie jar, so there is no
sessionKey paste and Cloudflare is not re-challenged (fresh cf_clearance is
replayed). API shape (chat_conversations / chat_messages) is identical to the
export — verified.

Differential: a watermark (poll_seen.json: uuid→updated_at), seeded from the
existing archive on first run, so only conversations newer/changed than the last
manual export are fetched. Changed uuids are invalidated in extracted.jsonl so
extract.py re-summarizes them (ingest re-renders via its own updated_at check).

Usage: poll.py [--limit N] [--dry-run] [--full]
  --limit N : fetch at most N changed conversation bodies (testing)
  --dry-run : list what would be fetched; write nothing
  --full    : ignore the watermark; refetch every conversation
"""
import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error

from claude_cookies import claude_cookies
from common import latest_archive, ARCHIVE_ROOT

CACHE = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
LIVE = os.path.join(ARCHIVE_ROOT, "live", "conversations.json")  # rolling merged archive
POLL_STATE = os.path.join(CACHE, "poll_seen.json")
EXTRACTED = os.path.join(CACHE, "extracted.jsonl")
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
PAGE = 100


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, ensure_ascii=False)
    os.replace(tmp, path)


def make_api(cookie_header):
    def api(path):
        req = urllib.request.Request(
            "https://claude.ai" + path,
            headers={"Cookie": cookie_header, "User-Agent": UA,
                     "Accept": "application/json", "Referer": "https://claude.ai/"},
        )
        r = urllib.request.urlopen(req, timeout=60)
        return json.loads(r.read().decode("utf-8", "ignore"))
    return api


def invalidate_extracted(uuids):
    if not uuids or not os.path.exists(EXTRACTED):
        return
    kept = []
    with open(EXTRACTED) as f:
        for line in f:
            try:
                if json.loads(line).get("uuid") in uuids:
                    continue
            except json.JSONDecodeError:
                pass
            kept.append(line)
    with open(EXTRACTED, "w") as f:
        f.writelines(kept)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--full", action="store_true")
    args = ap.parse_args(argv)

    c = claude_cookies()
    cookie_header = (f"sessionKey={c['sessionKey']}; "
                     f"cf_clearance={c.get('cf_clearance', '')}; "
                     f"lastActiveOrg={c.get('lastActiveOrg', '')}")
    api = make_api(cookie_header)
    org = c.get("lastActiveOrg") or api("/api/organizations")[0]["uuid"]

    # full archive (uuid -> conversation) seeded from the last export/poll
    prev = latest_archive()
    archive = {x["uuid"]: x for x in load_json(prev, [])} if prev else {}
    state = load_json(POLL_STATE, {})
    if not state and archive:  # first run after a manual export: seed from it
        state = {u: x.get("updated_at", "") for u, x in archive.items()}
        print(f"seeded watermark from {prev} ({len(state)} convs)", file=sys.stderr)

    # list ALL conversations (cheap metadata, paginated)
    listed, offset = [], 0
    while True:
        page = api(f"/api/organizations/{org}/chat_conversations?limit={PAGE}&offset={offset}")
        listed += page
        if len(page) < PAGE:
            break
        offset += PAGE
        time.sleep(0.3)

    changed = [m for m in listed if args.full or state.get(m["uuid"]) != m.get("updated_at")]
    new_n = sum(1 for m in changed if m["uuid"] not in archive)
    print(f"server={len(listed)} convs | archive={len(archive)} | changed/new={len(changed)} (new={new_n})", file=sys.stderr)
    if args.limit:
        changed = changed[:args.limit]
    if args.dry_run:
        for m in changed[:20]:
            tag = "NEW" if m["uuid"] not in archive else "UPD"
            print(f"  {tag} {m.get('updated_at', '')[:10]} {(m.get('name') or '')[:50]}")
        print(f"--- dry-run: would fetch {len(changed)} bodies ---", file=sys.stderr)
        return

    fetched = 0
    for m in changed:
        uuid = m["uuid"]
        try:
            full = api(f"/api/organizations/{org}/chat_conversations/{uuid}"
                       "?tree=True&rendering_mode=messages&render_all_tools=true")
        except urllib.error.HTTPError as e:
            print(f"ERR {uuid[:8]}: HTTP {e.code}", file=sys.stderr)
            continue
        archive[uuid] = full
        state[uuid] = m.get("updated_at", "")
        fetched += 1
        time.sleep(0.3)
        if fetched % 25 == 0:
            print(f"  fetched {fetched}/{len(changed)}", file=sys.stderr)

    if fetched == 0:
        print("--- no new/changed conversations; nothing to sync ---", file=sys.stderr)
        return  # leave live/state untouched; sync.sh sees empty stdout and stops

    invalidate_extracted({m["uuid"] for m in changed})

    # write merged conversations.json (export-compatible) to the rolling live archive
    save_json(LIVE, sorted(archive.values(), key=lambda x: x.get("updated_at") or "", reverse=True))
    save_json(POLL_STATE, state)
    print(f"--- fetched={fetched} | archive now {len(archive)} convs → {LIVE} ---", file=sys.stderr)
    print(LIVE)  # stdout = the artifact path; sync.sh keys on this being non-empty


if __name__ == "__main__":
    main(sys.argv[1:])
