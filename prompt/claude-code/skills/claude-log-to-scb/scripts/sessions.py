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

Real session = cwd outside root/tmp/var-folders AND >= MIN real user turns.
Probe / summarizer / one-shot sessions are skipped.

Self-check:
  bash prompt/claude-code/skills/claude-log-to-scb/scripts/sessions-sync.sh --dry-run
"""
import sys
import os
import json
import glob
import subprocess
import time
import argparse
import re

from common import msg_text  # noqa: F401  (kept for parity / future use)
from extract import EXTRACTION_PROMPT_PREFIX
from ingest import clean_title, jst, render, load_seen, save_seen, upsert as page_upsert

PROJECTS_ROOT = os.path.expanduser("~/.claude/projects")
CACHE_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
ARCHIVE = os.path.join(os.path.expanduser("~/.claude/data/claude-export"), "sessions")
CONV_DIR = os.path.join(CACHE_DIR, "conv-sessions")
EXTRACTED = os.path.join(CACHE_DIR, "extracted-sessions.jsonl")
SEEN = os.path.join(CACHE_DIR, "seen-sessions.json")
HUB = "claude codeセッション"
LABEL = "Claude Code セッション(claude-log-to-scb 自動取り込み)。ユーザー入力=全文 / Claudeの作業=要点のみ"
CODEX_ROOTS = (
    os.path.expanduser("~/.codex/sessions/**/*.jsonl"),
    os.path.expanduser("~/.codex/archived_sessions/**/*.jsonl"),
)
CODEX_ARCHIVE = os.path.join(os.path.expanduser("~/.claude/data/claude-export"), "codex-sessions")
CODEX_CONV_DIR = os.path.join(CACHE_DIR, "conv-codex-sessions")
CODEX_EXTRACTED = os.path.join(CACHE_DIR, "extracted-codex-sessions.jsonl")
CODEX_SEEN = os.path.join(CACHE_DIR, "seen-codex-sessions.json")
SKILL_OMITTED = "[( Skill注入テキスト省略]"
SKILL_OMITTED_ESCAPED = "［( Skill注入テキスト省略］"
SKILL_INJECTION_PREFIXES = (
    "<command-name>",
    "<command-name",
    "Base directory for this skill",
)
BAD_TITLE_PREFIX_RE = re.compile(r"^[\s`?？!！:：、。・／/\\|<>\[\]{}()（）]+")

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


def is_tool_result_only(o):
    m = o.get("message") or {}
    c = m.get("content")
    return isinstance(c, list) and c and all(
        isinstance(b, dict) and b.get("type") == "tool_result" for b in c
    )


def is_skill_injection_text(text):
    t = (text or "").lstrip()
    return any(t.startswith(prefix) for prefix in SKILL_INJECTION_PREFIXES)


def is_real_user(o):
    t = ev_text(o)
    if is_tool_result_only(o):
        return False
    if not t or len(t) < 3 or t.startswith("<") or is_skill_injection_text(t):
        return False  # empty / system-reminder / command wrapper
    return True


def sanitized_title_seed(text):
    t = BAD_TITLE_PREFIX_RE.sub("", (text or "").strip())
    return t[:48].strip()


def title_from_summary(ext, fallback, uuid):
    summary = ((ext or {}).get("ja_summary") or "").strip()
    source = " ".join(line.strip() for line in summary.splitlines() if line.strip())
    first_sentence = source.split("。", 1)[0] if source else ""
    title = sanitized_title_seed(first_sentence)
    return clean_title(title or fallback, f"claude code {uuid[:8]}")


def parse_session(path):
    """-> conversation-shaped dict, or None if not a real session."""
    if os.path.basename(os.path.dirname(path)) == "-":
        return None  # Claude's encoded project directory for cwd=/
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
        if t == "user" and is_skill_injection_text(ev_text(o)):
            msgs.append({"sender": "human", "text": SKILL_OMITTED})
        elif t == "user" and is_real_user(o):
            msgs.append({"sender": "human", "text": ev_text(o)})
            real_user += 1
        elif t == "assistant":
            txt = ev_text(o)
            if txt:
                msgs.append({"sender": "assistant", "text": txt})
    if not cwd or cwd == "/" or "/var/folders/" in cwd or "/tmp/" in cwd or "/T/tmp." in cwd:
        return None
    if real_user < 2:
        return None
    sid = os.path.splitext(os.path.basename(path))[0]
    first_human = next((m["text"] for m in msgs if m["sender"] == "human"), "")
    if first_human.startswith(EXTRACTION_PROMPT_PREFIX):
        return None
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


def parse_codex_session(path):
    """Normalize one Codex rollout without ingesting system/tool context."""
    metadata = {}
    first_ts = last_ts = None
    messages = []
    with open(path, errors="ignore") as source:
        events = []
        for line in source:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    for event in events:
        timestamp = event.get("timestamp")
        if timestamp:
            first_ts = first_ts or timestamp
            last_ts = timestamp
        payload = event.get("payload") or {}
        if event.get("type") == "session_meta":
            metadata = payload
        elif event.get("type") == "event_msg" and payload.get("type") == "user_message":
            text = (payload.get("message") or "").strip()
            if text:
                messages.append({"sender": "human", "text": text})
        elif (
            event.get("type") == "event_msg"
            and payload.get("type") == "agent_message"
            and payload.get("phase") in (None, "final_answer")
        ):
            text = (payload.get("message") or "").strip()
            if text:
                messages.append({"sender": "assistant", "text": text})
    humans = [message for message in messages if message["sender"] == "human"]
    cwd = metadata.get("cwd")
    if not humans or not cwd or "/var/folders/" in cwd or "/tmp/" in cwd or "/T/tmp." in cwd:
        return None
    session_id = metadata.get("id") or os.path.splitext(os.path.basename(path))[0]
    seed = humans[0]["text"].split("\n")[0].strip()
    short = (seed[:48] + "…") if len(seed) > 48 else seed
    project = project_for_cwd(cwd)
    return {
        "uuid": f"codex-{session_id}",
        "name": clean_title(short, f"codex {str(session_id)[:8]}"),
        "created_at": first_ts,
        "updated_at": last_ts,
        "chat_messages": messages,
        "_entities": [project] if project else [],
        "_hub": "Codexセッション",
        "_source_label": "Codex セッション自動取り込み。ユーザー入力=全文 / Codex応答=要点のみ",
        "_origin": f"{path} (cwd={cwd})",
    }


def source_paths(source):
    return (
        (ARCHIVE, CONV_DIR, EXTRACTED, SEEN)
        if source == "claude"
        else (CODEX_ARCHIVE, CODEX_CONV_DIR, CODEX_EXTRACTED, CODEX_SEEN)
    )


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


def build(source):
    archive, conv_dir, _, _ = source_paths(source)
    files = (
        glob.glob(os.path.join(PROJECTS_ROOT, "*", "*.jsonl"))
        if source == "claude"
        else [path for pattern in CODEX_ROOTS for path in glob.glob(pattern, recursive=True)]
    )
    parser = parse_session if source == "claude" else parse_codex_session
    os.makedirs(archive, exist_ok=True)
    os.makedirs(conv_dir, exist_ok=True)
    convs = []
    for f in files:
        c = parser(f)
        if c:
            convs.append(c)
    with open(os.path.join(archive, "conversations.json"), "w") as fh:
        json.dump(convs, fh, ensure_ascii=False)
    index = []
    for c in convs:
        compact = {"uuid": c["uuid"], "name": c["name"], "summary": "",
                   "created_at": c["created_at"], "transcript": transcript(c["chat_messages"])}
        with open(os.path.join(conv_dir, f"{c['uuid']}.json"), "w") as fh:
            json.dump(compact, fh, ensure_ascii=False)
        index.append(c["uuid"])
    with open(os.path.join(conv_dir, "_index.json"), "w") as fh:
        json.dump(index, fh)
    print(f"built {len(convs)} real {source} sessions -> {archive}/conversations.json + {conv_dir}/ (compact)")


def load_extracted(path):
    out = {}
    if os.path.exists(path):
        for line in open(path):
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
    archive, _, extracted_path, seen_path = source_paths(args.source)
    convs = json.load(open(os.path.join(archive, "conversations.json")))
    convs.sort(key=lambda c: c.get("updated_at") or "", reverse=True)
    ext = load_extracted(extracted_path)
    import datetime
    today = jst(datetime.datetime.now(datetime.timezone.utc).isoformat())
    seen = {} if args.force else load_seen_sessions(seen_path)
    used = {}
    written = skipped = errors = 0
    for conv in convs:
        uuid = conv["uuid"]
        updated = conv.get("updated_at") or ""
        if not args.force and seen.get(uuid) == updated:
            skipped += 1
            continue
        extracted = ext.get(uuid)
        render_conv = dict(conv)
        render_conv["name"] = title_from_summary(extracted, conv.get("name"), uuid)
        title, body, ents = render(render_conv, extracted, archive, today)
        body = body.replace(SKILL_OMITTED_ESCAPED, SKILL_OMITTED)
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
                save_seen_sessions(seen, seen_path)
            time.sleep(0.4)
        print(f"{'DRY' if args.dry_run else 'OK '} [{len(ents):>2}e] {title[:46]}  {url or ''}")
        if args.limit and written >= args.limit:
            break
    if not args.dry_run:
        save_seen_sessions(seen, seen_path)
    print(f"\n--- written={written} skipped={skipped} errors={errors} (extracted={len(ext)}) ---")


def load_seen_sessions(path):
    try:
        return json.load(open(path))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_seen_sessions(seen, path):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(seen, f, ensure_ascii=False)
    os.replace(tmp, path)


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--source", choices=("claude", "codex"), default="claude")
    r = sub.add_parser("render")
    r.add_argument("--source", choices=("claude", "codex"), default="claude")
    r.add_argument("--project", default="takalog")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", action="store_true")
    r.add_argument("--limit", type=int, default=0)
    args = ap.parse_args(argv)
    if args.cmd == "build":
        build(args.source)
    elif args.cmd == "render":
        render_cmd(args)


if __name__ == "__main__":
    main(sys.argv[1:])
