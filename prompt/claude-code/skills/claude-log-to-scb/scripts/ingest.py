#!/usr/bin/env python3
"""claude-log-to-scb — render per-conversation Scrapbox pages (project: takalog).

Page = the user's OWN inputs transcribed in full (verbatim, normal text) +
Claude's replies compressed to key points (LLM, faint `[( ]`) + entity links.
This mirrors the human-vs-LLM marking convention: your words show normal,
the model's summary shows faint.

Inputs:
  - conversations.json  (full human messages; the cold-archive source of truth)
  - extracted.jsonl     (per-uuid {ja_summary, people, projects, decisions,
                         commitments} from extract — LLM step). Optional: when a
                         uuid is missing the page still renders (summary pending).

Idempotency: skip when a conversation's updated_at matches the watermark
(~/.claude/.cache/claude-log-to-scb/seen.json). --force re-writes.

Usage:
  ingest.py <export_dir_or_zip> [--project takalog] [--dry-run] [--limit N]
            [--uuid UUID] [--force]
"""
import sys
import os
import json
import argparse
import subprocess
import zipfile
import time
import datetime

from common import msg_text, canon, esc

SCRAPBOX_WRITE = os.path.expanduser("~/.local/bin/scrapbox-write")
import os, sys  # noqa: E402
sys.path.insert(0, os.path.expanduser("~/.claude/scripts/lib"))
from normalize import normalize  # 表記ゆれ正規化(Scrapbox 書き込み境界)
CACHE_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb")
ARCHIVE_ROOT = os.path.expanduser("~/.claude/data/claude-export")
SEEN_PATH = os.path.join(CACHE_DIR, "seen.json")
EXTRACTED_PATH = os.path.join(CACHE_DIR, "extracted.jsonl")
HUB = "claude会話ログ"

# Heuristic fallback links when a conversation has no LLM extraction yet.
ENTITY_KEYWORDS = {
    "構想日本": "構想日本", "多元現実": "多元現実", "plural-reality": "多元現実",
    "倍速会議": "倍速会議", "倍速アンケート": "倍速アンケート",
    "cartographer": "Cartographer", "sonar": "Sonar", "flux": "Flux",
}


def load_seen():
    try:
        with open(SEEN_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_seen(seen):
    os.makedirs(CACHE_DIR, exist_ok=True)
    tmp = SEEN_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(seen, f, ensure_ascii=False)
    os.replace(tmp, SEEN_PATH)


def load_extracted():
    out = {}
    if not os.path.exists(EXTRACTED_PATH):
        return out
    with open(EXTRACTED_PATH) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
                if o.get("uuid"):
                    out[o["uuid"]] = o
            except json.JSONDecodeError:
                continue
    return out


def resolve_export(source):
    source = os.path.expanduser(source)
    if os.path.isdir(source):
        cj = os.path.join(source, "conversations.json")
        if not os.path.isfile(cj):
            sys.exit(f"no conversations.json in {source}")
        return cj, source
    if zipfile.is_zipfile(source):
        dest = os.path.join(ARCHIVE_ROOT, datetime.date.today().isoformat())
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(source) as z:
            z.extractall(dest)
        cj = os.path.join(dest, "conversations.json")
        if not os.path.isfile(cj):
            sys.exit(f"no conversations.json inside {source}")
        return cj, dest
    sys.exit(f"source is neither a dir nor a zip: {source}")


def jst(iso):
    if not iso:
        return ""
    dt = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    dt = dt.astimezone(datetime.timezone(datetime.timedelta(hours=9)))
    return f"{dt.year}/{dt.month}/{dt.day}"


def heuristic_entities(text):
    low = text.lower()
    hits = []
    for kw, link in ENTITY_KEYWORDS.items():
        if kw.lower() in low and link not in hits:
            hits.append(link)
    return hits


def clean_title(name, fallback):
    # Scrapbox rejects titles containing [ or ] ; also '/' is a path separator.
    name = (name or "").strip().replace("\n", " ").replace("/", "／").replace("[", "").replace("]", "")
    return name.strip() or fallback


def human_block(text):
    """Verbatim human message: first line carries the icon, continuation lines
    indent under it. Normal (non-faint) text — these are the user's own words."""
    lines = text.split("\n")
    out = [f"  [tkgshn.icon] {lines[0]}"]
    for ln in lines[1:]:
        out.append(f"  {ln}" if ln else "")
    return out


def render(conv, ext, archive_dir, today):
    uuid = conv.get("uuid", "")
    title = clean_title(conv.get("name"), f"claude会話 {uuid[:8]}")
    msgs = conv.get("chat_messages", [])
    created, updated = jst(conv.get("created_at")), jst(conv.get("updated_at"))
    span = created if created == updated else f"{created} 〜 {updated}"

    if ext:
        ents = []
        for e in (ext.get("projects") or []) + (ext.get("people") or []):
            c = canon(e)
            if c and c not in ents:
                ents.append(c)
        summary = (ext.get("ja_summary") or "").strip()
        decisions = ext.get("decisions") or []
        commits = ext.get("commitments") or []
    else:
        blob = " ".join([conv.get("name") or ""] + [msg_text(m) for m in msgs[:6]])
        ents = heuristic_entities(blob)
        summary, decisions, commits = "", [], []

    # injected entities (e.g. session cwd -> project) take precedence over extracted
    ents = list(dict.fromkeys([canon(e) for e in (conv.get("_entities") or []) if canon(e)] + ents))
    L = []
    L.append(f"from [{conv.get('_hub', HUB)}]")
    L.append(f"[{today}]")
    L.append(f" [( {conv.get('_source_label', 'claude.ai 会話ログ。原本=ローカルarchiveがSoT。ユーザー入力=全文 / Claude応答=要点のみ')}][claude code.icon]")
    L.append(f" [( 日付: {span} | メッセージ: {len(msgs)}通 | uuid: {uuid}]")
    if ents:
        L.append(" [( 関連: " + " ".join(f"[{e}]" for e in ents) + "]")
    L.append(" [( 要点(AIの回答・会話全体のまとめ):][claude code.icon]")
    if summary:
        for s in summary.split("\n"):
            s = s.strip()
            if s:
                L.append(f"  [( {esc(s)}]")
    else:
        L.append("  [( (要点未抽出 — extract 未実行)]")
    if decisions or commits:
        L.append(" [( 決定/コミット:]")
        for d in decisions:
            L.append(f"  [( {esc(d)}]")
        for c in commits:
            L.append(f"  [( [⬜ {esc(c)}]]")
    L.append(" [( ユーザー入力(全文):]")
    HCAP = 40000  # keep a single Scrapbox page sane; full text lives in the cold archive
    used = 0
    for m in msgs:
        if m.get("sender") != "human":
            continue
        t = msg_text(m)
        if not t:
            continue
        if used + len(t) > HCAP:
            L.append(f"  [( …(以降のユーザー入力は省略。全文は原本 archive 参照。総 {sum(len(msg_text(x)) for x in msgs if x.get('sender')=='human')} 文字)]")
            break
        L.extend(human_block(esc(t)))
        used += len(t)
    origin = conv.get("_origin")
    if origin:
        L.append(f" [( 原本: {origin}]")
    else:
        archive_rel = os.path.relpath(os.path.join(archive_dir, "conversations.json"), os.path.expanduser("~"))
        L.append(f" [( 原本: ~/{archive_rel} の uuid={uuid}]")
    return title, "\n".join(L), ents


def upsert(title, body, project, dry_run):
    body = normalize(body)
    cmd = [SCRAPBOX_WRITE, "-p", project, "-t", title, "--verbatim"]
    if dry_run:
        cmd.append("--dry-run")
    try:
        r = subprocess.run(cmd, input=body, capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        return None, "scrapbox-write timeout (90s)"
    if r.returncode != 0:
        return None, r.stderr.strip()
    return (r.stdout.strip().splitlines() or [""])[-1], None


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--project", default="takalog")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--uuid", default=None)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args(argv)

    cj, archive_dir = resolve_export(args.source)
    today = jst(datetime.datetime.now(datetime.timezone.utc).isoformat())
    conversations = json.load(open(cj))
    conversations.sort(key=lambda c: c.get("updated_at") or "", reverse=True)
    extracted = load_extracted()
    seen = load_seen()
    used = {}
    written = skipped = errors = 0
    for conv in conversations:
        uuid = conv.get("uuid", "")
        if args.uuid and uuid != args.uuid:
            continue
        updated = conv.get("updated_at") or ""
        if not args.force and not args.uuid and seen.get(uuid) == updated:
            skipped += 1
            continue
        title, body, ents = render(conv, extracted.get(uuid), archive_dir, today)
        if title in used:
            used[title] += 1
            title = f"{title} ({used[title]})"
        else:
            used[title] = 1
        url, err = upsert(title, body, args.project, args.dry_run)
        if err:
            errors += 1
            sys.stderr.write(f"ERR {uuid}: {err}\n")
            continue
        written += 1
        if not args.dry_run:
            seen[uuid] = updated
            if written % 25 == 0:
                save_seen(seen)
            time.sleep(0.4)
        tag = "DRY" if args.dry_run else "OK "
        print(f"{tag} [{len(ents):>2}e] {title[:48]}  {url or ''}")
        if args.limit and written >= args.limit:
            break

    if not args.dry_run:
        save_seen(seen)
    print(f"\n--- written={written} skipped={skipped} errors={errors} (total={len(conversations)}, extracted={len(extracted)}) ---")


if __name__ == "__main__":
    main(sys.argv[1:])
