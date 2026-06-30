#!/usr/bin/env python3
"""claude-log-to-scb — Claude Code CLI session adapter.

Normalizes Claude Code session transcripts (~/.claude/projects/**/*.jsonl) into
the SAME conversation shape as the claude.ai export, so the existing render +
extraction pipeline is reused. The user's prompts are transcribed in full
(normal text); Claude's replies are summarized to key points (LLM, faint).
The session's cwd maps to a [project] bracket link so sessions join the same
n-hop graph as the claude.ai conversations (native Scrapbox backlinks make a
session show up under [Cartographer] etc.).

Subcommands:
  build   enumerate real sessions -> sessions archive (conversations.json shape)
          + compact files for extraction
  render  load archive + extracted-sessions.jsonl -> write takalog pages

Real session = cwd outside tmp/var-folders AND >= MIN real user turns. Probe /
summarizer / one-shot sessions are skipped.
"""
import sys
import os
import json
import glob
import subprocess
import time
import argparse

from common import msg_text  # noqa: F401  (kept for parity / future use)
from ingest import clean_title, jst, render, load_seen, save_seen, upsert as page_upsert

PROJECTS_ROOT = os.path.expanduser("~/.claude/projects")
CACHE_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
ARCHIVE = os.path.join(os.path.expanduser("~/.claude/data/claude-export"), "sessions")
CONV_DIR = os.path.join(CACHE_DIR, "conv-sessions")
EXTRACTED = os.path.join(CACHE_DIR, "extracted-sessions.jsonl")
SEEN = os.path.join(CACHE_DIR, "seen-sessions.json")
HUB = "claude codeセッション"
LABEL = "Claude Code セッション(claude-log-to-scb 自動取り込み)。ユーザー入力=全文 / Claudeの作業=要点のみ"

# cwd substring -> canonical [project] link (from the local project map).
PROJECT_BY_PATH = [
    ("plural-reality/cartographer", "Cartographer"),
    ("plural-reality/baisoku-survey", "Sonar"),
    ("plural-reality/flux", "Flux"),
    ("plural-reality/cosense-context-proxy", "cosense-context-proxy"),
    ("plural-reality/shared-ui", "shared-ui"),
    ("plural-reality/report-generator", "sense-making"),
    ("plural-reality/civic-report", "civic-report"),
    ("plural-reality/kousounihon-book", "構想日本"),
    ("plural-reality/LP", "倍速会議"),
    ("plural-reality/internal-cartographer-watcher", "Cartographer"),
    ("plural-reality/internal-sonar-watcher", "Sonar"),
    ("beeper-scrapbox-crm", "beeper-scrapbox-crm"),
    ("Developer/website", "多元現実"),
    ("nix-darwin", "nix-darwin"),
]


def project_for_cwd(cwd):
    if not cwd:
        return None
    for sub, proj in PROJECT_BY_PATH:
        if sub in cwd:
            return proj
    return None


def ev_text(o):
    m = o.get("message") or {}
    c = m.get("content")
    if isinstance(c, str):
        return c.strip()
    if isinstance(c, list):
        parts = [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
        return "\n".join(p for p in parts if p).strip()
    return ""


def is_real_user(o):
    m = o.get("message") or {}
    c = m.get("content")
    if isinstance(c, list) and not any(isinstance(b, dict) and b.get("type") == "text" for b in c):
        return False  # tool_result-only — not human input
    t = ev_text(o)
    if not t or len(t) < 3 or t.startswith("<"):
        return False  # empty / system-reminder / command wrapper
    return True


def parse_session(path):
    """-> conversation-shaped dict, or None if not a real session."""
    cwd = None
    first_ts = last_ts = None
    msgs = []
    real_user = 0
    for line in open(path, errors="ignore"):
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except json.JSONDecodeError:
            continue
        if o.get("cwd"):
            cwd = o["cwd"]
        ts = o.get("timestamp")
        if ts:
            first_ts = first_ts or ts
            last_ts = ts
        t = o.get("type")
        if t == "user" and is_real_user(o):
            msgs.append({"sender": "human", "text": ev_text(o)})
            real_user += 1
        elif t == "assistant":
            txt = ev_text(o)
            if txt:
                msgs.append({"sender": "assistant", "text": txt})
    if not cwd or "/var/folders/" in cwd or "/tmp/" in cwd or "/T/tmp." in cwd:
        return None
    if real_user < 2:
        return None
    sid = os.path.splitext(os.path.basename(path))[0]
    first_human = next((m["text"] for m in msgs if m["sender"] == "human"), "")
    fl = first_human.split("\n")[0].strip()
    short = (fl[:48] + "…") if len(fl) > 48 else fl
    title = clean_title(short, f"claude code {sid[:8]}")
    proj = project_for_cwd(cwd)
    return {
        "uuid": sid,
        "name": title,
        "created_at": first_ts,
        "updated_at": last_ts,
        "chat_messages": msgs,
        "_entities": [proj] if proj else [],
        "_hub": HUB,
        "_source_label": LABEL,
        "_origin": f"{path} (cwd={cwd})",
    }


def transcript(msgs, cap=4000):
    out, used = [], 0
    for m in msgs:
        chunk = f"{m['sender']}: {m['text'][:700]}"
        out.append(chunk)
        used += len(chunk)
        if used >= cap:
            out.append("…(truncated)")
            break
    return "\n".join(out)


def build():
    files = glob.glob(os.path.join(PROJECTS_ROOT, "*", "*.jsonl"))
    os.makedirs(ARCHIVE, exist_ok=True)
    os.makedirs(CONV_DIR, exist_ok=True)
    convs = []
    for f in files:
        c = parse_session(f)
        if c:
            convs.append(c)
    with open(os.path.join(ARCHIVE, "conversations.json"), "w") as fh:
        json.dump(convs, fh, ensure_ascii=False)
    index = []
    for c in convs:
        compact = {"uuid": c["uuid"], "name": c["name"], "summary": "",
                   "created_at": c["created_at"], "transcript": transcript(c["chat_messages"])}
        with open(os.path.join(CONV_DIR, f"{c['uuid']}.json"), "w") as fh:
            json.dump(compact, fh, ensure_ascii=False)
        index.append(c["uuid"])
    with open(os.path.join(CONV_DIR, "_index.json"), "w") as fh:
        json.dump(index, fh)
    print(f"built {len(convs)} real sessions -> {ARCHIVE}/conversations.json + {CONV_DIR}/ (compact)")


def load_extracted():
    out = {}
    if os.path.exists(EXTRACTED):
        for line in open(EXTRACTED):
            line = line.strip()
            if line:
                try:
                    o = json.loads(line)
                    if o.get("uuid"):
                        out[o["uuid"]] = o
                except json.JSONDecodeError:
                    pass
    return out


def render_cmd(args):
    convs = json.load(open(os.path.join(ARCHIVE, "conversations.json")))
    convs.sort(key=lambda c: c.get("updated_at") or "", reverse=True)
    ext = load_extracted()
    import datetime
    today = jst(datetime.datetime.now(datetime.timezone.utc).isoformat())
    seen = {} if args.force else load_seen_sessions()
    used = {}
    written = skipped = errors = 0
    for conv in convs:
        uuid = conv["uuid"]
        updated = conv.get("updated_at") or ""
        if not args.force and seen.get(uuid) == updated:
            skipped += 1
            continue
        title, body, ents = render(conv, ext.get(uuid), ARCHIVE, today)
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
                save_seen_sessions(seen)
            time.sleep(0.4)
        print(f"{'DRY' if args.dry_run else 'OK '} [{len(ents):>2}e] {title[:46]}  {url or ''}")
        if args.limit and written >= args.limit:
            break
    if not args.dry_run:
        save_seen_sessions(seen)
    print(f"\n--- written={written} skipped={skipped} errors={errors} (extracted={len(ext)}) ---")


def load_seen_sessions():
    try:
        return json.load(open(SEEN))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_seen_sessions(seen):
    tmp = SEEN + ".tmp"
    with open(tmp, "w") as f:
        json.dump(seen, f, ensure_ascii=False)
    os.replace(tmp, SEEN)


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build")
    r = sub.add_parser("render")
    r.add_argument("--project", default="takalog")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", action="store_true")
    r.add_argument("--limit", type=int, default=0)
    args = ap.parse_args(argv)
    if args.cmd == "build":
        build()
    elif args.cmd == "render":
        render_cmd(args)


if __name__ == "__main__":
    main(sys.argv[1:])
