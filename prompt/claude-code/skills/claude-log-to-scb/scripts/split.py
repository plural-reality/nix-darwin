#!/usr/bin/env python3
"""claude-log-to-scb — Phase B/1: split conversations.json into compact
per-conversation files for LLM entity extraction.

Each output file ~/.claude/.cache/claude-log-to-scb/conv/<uuid>.json holds a
size-capped digest (title + export summary + a truncated transcript) so a haiku
agent can extract entities cheaply without ingesting the full 223MB corpus.

Usage: split.py <export_dir_or_conversations.json> [--cap 4000]
"""
import sys
import os
import json
import argparse

from common import msg_text

CONV_DIR = os.path.expanduser("~/.claude/.cache/claude-log-to-scb/conv")


def transcript(msgs, cap):
    out, used = [], 0
    for m in msgs:
        t = msg_text(m).strip()
        if not t:
            continue
        chunk = f"{m.get('sender', '?')}: {t[:700]}"
        out.append(chunk)
        used += len(chunk)
        if used >= cap:
            out.append("…(truncated)")
            break
    return "\n".join(out)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--cap", type=int, default=4000)
    args = ap.parse_args(argv)
    src = os.path.expanduser(args.source)
    if os.path.isdir(src):
        src = os.path.join(src, "conversations.json")
    conversations = json.load(open(src))
    os.makedirs(CONV_DIR, exist_ok=True)
    n = 0
    index = []
    for c in conversations:
        uuid = c.get("uuid")
        if not uuid:
            continue
        compact = {
            "uuid": uuid,
            "name": c.get("name") or "",
            "summary": c.get("summary") or "",
            "created_at": c.get("created_at"),
            "transcript": transcript(c.get("chat_messages", []), args.cap),
        }
        with open(os.path.join(CONV_DIR, f"{uuid}.json"), "w") as f:
            json.dump(compact, f, ensure_ascii=False)
        index.append(uuid)
        n += 1
    with open(os.path.join(CONV_DIR, "_index.json"), "w") as f:
        json.dump(index, f)
    print(f"wrote {n} compact conversation files -> {CONV_DIR}")


if __name__ == "__main__":
    main(sys.argv[1:])
