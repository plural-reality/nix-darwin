#!/usr/bin/env python3
"""claude-log-to-scb — ChatGPT driver (mirrors sessions.py: a third source that
reuses the SAME downstream as claude.ai).

  build   acquire ChatGPT-native conversations and merge them into a rolling
          cold archive (the SoT, kept in ChatGPT's own native graph shape), then
          emit compact per-conversation files for extraction.
            --source export <zip|dir|json>   PATH A: the official Export Data
            --source chrome                   PATH B: real-Chrome same-origin poll
          chrome is differential (poll-chatgpt.json watermark on update_time);
          first chrome run with no watermark pulls the full history — which is
          exactly the bootstrap, since the official export takes days to arrive.

  render  load the archive, flatten each conversation (mapping -> linear) into
          the claude-export shape, and write takalog pages via the SHARED
          renderer. Own hub ([ChatGPT会話ログ]) + own watermark (seen-chatgpt).

The cold archive stays in ChatGPT's NATIVE shape (full fidelity = true SoT);
flatten is applied at read time. Acquisition is the only source-specific code;
split (compact) / extract / render are reused unchanged.
"""
import sys
import os
import json
import time
import zipfile
import argparse
import datetime

from ingest import render, jst, upsert as page_upsert  # SHARED renderer
from chatgpt_flatten import flatten_all, flatten_conv, HUB, LABEL

ARCHIVE_ROOT = os.path.expanduser("~/.claude/data/chatgpt-export")
LIVE = os.path.join(ARCHIVE_ROOT, "live", "conversations.json")  # native, merged
CACHE = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
CONV_DIR = os.path.join(CACHE, "conv-chatgpt")
EXTRACTED = os.path.join(CACHE, "extracted-chatgpt.jsonl")
SEEN = os.path.join(CACHE, "seen-chatgpt.json")            # render watermark (uuid->updated_at iso)
POLL_STATE = os.path.join(CACHE, "poll-chatgpt.json")      # acquisition watermark (id->update_time)
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


def conv_id(c):
    return c.get("conversation_id") or c.get("id") or c.get("uuid") or ""


# ---- acquisition: PATH A (export) -----------------------------------------
def acquire_export(source):
    source = os.path.expanduser(source)
    if zipfile.is_zipfile(source):
        dest = os.path.join(ARCHIVE_ROOT, datetime.date.today().isoformat())
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(source) as z:
            z.extractall(dest)
        source = dest
    if os.path.isdir(source):
        source = os.path.join(source, "conversations.json")
    if not os.path.isfile(source):
        sys.exit(f"no conversations.json at {source}")
    data = json.load(open(source))
    return data if isinstance(data, list) else (data.get("items") or [data])


# ---- acquisition: PATH B (real Chrome same-origin) ------------------------
def _checkpoint(archive, state):
    """Durably persist progress so a multi-thousand-conv pull is crash-safe and
    resumable (the watermark skips what's already fetched on the next run)."""
    merged = sorted(archive.values(), key=lambda c: c.get("update_time") or 0, reverse=True)
    save_json(LIVE, merged)
    save_json(POLL_STATE, state)


def acquire_chrome(full, limit, dry_run):
    """Fetch new/changed conversations via real Chrome, checkpointing LIVE +
    POLL_STATE every 25 (resumable). Returns the set of fetched ids (for compact
    invalidation), or None when there is nothing to do. Chrome owns its own
    durable writes — build() only rebuilds compact from the resulting LIVE."""
    from chrome_fetch import chrome_get, ensure_tab
    ensure_tab()

    def get_retry(path, tries=4):
        for k in range(tries):
            try:
                return chrome_get(path)
            except RuntimeError as e:
                if "Apple Events" in str(e) or k == tries - 1:  # toggle off → futile
                    raise
                time.sleep(1.5)
                ensure_tab()  # transient (tab vanished / busy) → re-acquire & retry

    state = load_json(POLL_STATE, {})
    is_changed = lambda m: full or state.get(conv_id(m)) != m.get("update_time")

    def page_all(archived, cap=None, stop_known=False):
        # order=updated is newest-first, so we can stop early:
        #   cap        → once we have enough changed candidates (fast --limit)
        #   stop_known → once a full page is entirely already-seen (delta sync:
        #                we've reached known territory, the rest is older/unchanged)
        out, offset = [], 0
        flag = "&is_archived=true" if archived else ""
        while True:
            resp = get_retry(f"/backend-api/conversations?offset={offset}&limit={PAGE}&order=updated{flag}")
            items = (resp.get("items") if isinstance(resp, dict) else resp) or []
            out += items
            if len(items) < PAGE:
                return out
            if cap and sum(is_changed(m) for m in out) >= cap:
                return out
            if stop_known and not any(is_changed(m) for m in items):
                return out
            offset += PAGE
            time.sleep(0.2)

    incremental = not full and bool(state)  # delta sync: stop at first all-known page
    if limit:
        listed = page_all(False, cap=limit)
    elif incremental:
        listed = page_all(False, stop_known=True) + page_all(True, stop_known=True)
    else:
        listed = page_all(False) + page_all(True)  # bootstrap / --full: enumerate all
    archive = {conv_id(c): c for c in load_json(LIVE, [])}
    changed = [m for m in listed if is_changed(m)]
    new_n = sum(1 for m in changed if conv_id(m) not in archive)
    print(f"server={len(listed)} | archive={len(archive)} | changed/new={len(changed)} (new={new_n})",
          file=sys.stderr)
    if limit:
        changed = changed[:limit]
    if dry_run:
        for m in changed[:20]:
            tag = "NEW" if conv_id(m) not in archive else "UPD"
            print(f"  {tag} {(m.get('title') or '')[:54]}", file=sys.stderr)
        return None
    if not changed:
        return None

    fetched_ids, errors = set(), 0
    for i, m in enumerate(changed, 1):
        cid = conv_id(m)
        try:
            conv = get_retry(f"/backend-api/conversation/{cid}")
        except RuntimeError as e:
            if "Apple Events" in str(e):
                _checkpoint(archive, state)  # save what we have before aborting
                raise
            errors += 1
            print(f"ERR {cid[:8]}: {e}", file=sys.stderr)
            continue  # state unset → retried on the next run
        conv["conversation_id"] = cid
        conv.setdefault("update_time", m.get("update_time"))
        conv.setdefault("title", m.get("title"))
        archive[cid] = conv
        state[cid] = m.get("update_time")
        fetched_ids.add(cid)
        if len(fetched_ids) % 25 == 0:
            _checkpoint(archive, state)
            print(f"  fetched {len(fetched_ids)}/{len(changed)} (err={errors})", file=sys.stderr)
        time.sleep(0.2)
    _checkpoint(archive, state)
    print(f"--- fetched={len(fetched_ids)} errors={errors} | archive now {len(archive)} ---", file=sys.stderr)
    return fetched_ids


# ---- build: merge into the native cold archive + emit compact --------------
def transcript(conv, cap=4000):
    out, used = [], 0
    for m in conv["chat_messages"]:
        chunk = f"{m['sender']}: {m['text'][:700]}"
        out.append(chunk)
        used += len(chunk)
        if used >= cap:
            out.append("…(truncated)")
            break
    return "\n".join(out)


def invalidate_extracted(uuids):
    if not uuids or not os.path.exists(EXTRACTED):
        return
    kept = [ln for ln in open(EXTRACTED)
            if (json.loads(ln).get("uuid") if ln.strip() else None) not in uuids]
    with open(EXTRACTED, "w") as f:
        f.writelines(kept)


def build(args):
    if args.source == "export":
        if not args.path:
            sys.exit("--source export needs a <zip|dir|json> path")
        acquired = acquire_export(args.path)
        if not acquired:
            print("--- export empty ---", file=sys.stderr)
            return
        archive = {conv_id(c): c for c in load_json(LIVE, [])}
        for c in acquired:
            archive[conv_id(c)] = c
        save_json(LIVE, sorted(archive.values(), key=lambda c: c.get("update_time") or 0, reverse=True))
        changed_ids = {conv_id(c) for c in acquired}
    elif args.source == "chrome":
        try:
            changed_ids = acquire_chrome(args.full, args.limit, args.dry_run)  # writes LIVE+state itself
        except RuntimeError as e:
            sys.exit(f"\nPATH B (実Chrome) 取得に失敗:\n{e}")
        if not changed_ids:
            print("--- dry-run / no new-changed / nothing to sync ---", file=sys.stderr)
            return
    else:
        sys.exit("--source must be export|chrome")

    # common tail: rebuild compact from the now-current LIVE, invalidate changed extracts
    merged = load_json(LIVE, [])
    os.makedirs(CONV_DIR, exist_ok=True)
    flat = flatten_all(merged)
    index = []
    for c in flat:
        compact = {"uuid": c["uuid"], "name": c["name"], "summary": "",
                   "created_at": c["created_at"], "transcript": transcript(c)}
        with open(os.path.join(CONV_DIR, f"{c['uuid']}.json"), "w") as f:
            json.dump(compact, f, ensure_ascii=False)
        index.append(c["uuid"])
    save_json(os.path.join(CONV_DIR, "_index.json"), index)
    invalidate_extracted(changed_ids)
    print(f"--- archive={len(merged)} convs, flattened={len(flat)} → {LIVE} ---", file=sys.stderr)
    print(LIVE)  # stdout = artifact path (runner keys on non-empty)


# ---- render: flatten-at-read → shared renderer → takalog ------------------
def load_extracted():
    out = {}
    if os.path.exists(EXTRACTED):
        for ln in open(EXTRACTED):
            ln = ln.strip()
            if ln:
                try:
                    o = json.loads(ln)
                    if o.get("uuid"):
                        out[o["uuid"]] = o
                except json.JSONDecodeError:
                    pass
    return out


def render_cmd(args):
    native = load_json(LIVE, [])
    convs = flatten_all(native)
    convs.sort(key=lambda c: c.get("updated_at") or "", reverse=True)
    ext = load_extracted()
    seen = {} if args.force else load_json(SEEN, {})
    today = jst(datetime.datetime.now(datetime.timezone.utc).isoformat())
    archive_dir = os.path.dirname(LIVE)
    used, written, skipped, errors = {}, 0, 0, 0
    for conv in convs:
        uuid = conv["uuid"]
        updated = conv.get("updated_at") or ""
        if not args.force and seen.get(uuid) == updated:
            skipped += 1
            continue
        conv["_origin"] = f"~/.claude/data/chatgpt-export/live/conversations.json の id={uuid}"
        title, body, ents = render(conv, ext.get(uuid), archive_dir, today)
        if title in used:
            used[title] += 1
            title = f"{title} ({used[title]})"
        else:
            used[title] = 1
        url, err = page_upsert(title, body, args.project, args.dry_run)
        if err:
            errors += 1
            sys.stderr.write(f"ERR {uuid}: {err}\n")
            continue
        written += 1
        if not args.dry_run:
            seen[uuid] = updated
            if written % 25 == 0:
                save_json(SEEN, seen)
            time.sleep(0.4)
        print(f"{'DRY' if args.dry_run else 'OK '} [{len(ents):>2}e] {title[:46]}  {url or ''}")
        if args.limit and written >= args.limit:
            break
    if not args.dry_run:
        save_json(SEEN, seen)
    print(f"\n--- written={written} skipped={skipped} errors={errors} "
          f"(total={len(convs)}, extracted={len(ext)}) ---")


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--source", choices=["export", "chrome"], required=True)
    b.add_argument("--path", default=None, help="export zip|dir|json (--source export)")
    b.add_argument("--full", action="store_true", help="ignore watermark (chrome)")
    b.add_argument("--limit", type=int, default=0)
    b.add_argument("--dry-run", action="store_true")
    r = sub.add_parser("render")
    r.add_argument("--project", default="takalog")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", action="store_true")
    r.add_argument("--limit", type=int, default=0)
    args = ap.parse_args(argv)
    build(args) if args.cmd == "build" else render_cmd(args)


if __name__ == "__main__":
    main(sys.argv[1:])
