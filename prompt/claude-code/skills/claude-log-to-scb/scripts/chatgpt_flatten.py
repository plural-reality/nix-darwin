#!/usr/bin/env python3
"""claude-log-to-scb — ChatGPT source adapter (the ONE new abstraction).

ChatGPT stores a conversation as a UUID node graph: `mapping` (id -> {message,
parent, children}) + `current_node` (the active leaf). This is the same shape
claude.ai uses internally; the difference is only that claude's *export* already
linearizes into `chat_messages`, whereas ChatGPT (both the official export ZIP
and the backend-api/conversation/{id} response) hands you the raw graph.

This module is a PURE transform — the single new piece the feasibility report
identified: it walks `current_node` up the `parent` chain, reverses, and emits a
conversation in the EXACT claude.ai-export shape that split / extract / ingest
(render) / aggregate already consume unchanged:

    {uuid, name, summary, created_at, updated_at,
     chat_messages: [{sender: "human"|"assistant", text, created_at}], _hub, ...}

Both acquisition paths (PATH A = official export ZIP, PATH B = real-Chrome
same-origin poll) produce ChatGPT-native conversation objects; both feed THIS,
then the same downstream. Acquisition is the only thing that differs.

Filter usage (stdin/stdout — compose with anything):
    cat chatgpt_conversations.json | chatgpt_flatten.py > conversations.json
    chatgpt_flatten.py < export/conversations.json | jq length
"""
import sys
import json
import datetime

# ChatGPT author.role -> claude-export sender. system/tool are dropped: takalog
# transcribes the user's words in full and summarizes the model's reply; tool
# I/O and injected system context are noise that lives in the cold archive.
ROLE = {"user": "human", "assistant": "assistant"}

# content_types that carry injected context (custom instructions / memory),
# never the human's or the model's actual turn — always dropped.
_CONTEXT_TYPES = {"user_editable_context", "model_editable_context"}


def _iso(ts):
    """ChatGPT epoch-seconds float -> ISO8601 Z (so ingest.jst() parses it).
    Passes through a string unchanged (export sometimes already-stringified)."""
    if ts is None or ts == "":
        return ""
    if isinstance(ts, str):
        return ts
    try:
        return datetime.datetime.fromtimestamp(
            float(ts), tz=datetime.timezone.utc
        ).isoformat()
    except (TypeError, ValueError, OSError):
        return ""


def _text(content):
    """Clean text out of one ChatGPT message `content` block across the content
    types that actually carry prose. Multimodal image/file parts become a
    placeholder; code/tool blocks fall back to the `text` field."""
    if not isinstance(content, dict):
        return ""
    if content.get("content_type") in _CONTEXT_TYPES:
        return ""
    parts = content.get("parts")
    if isinstance(parts, list):
        out = []
        for p in parts:
            if isinstance(p, str):
                if p.strip():
                    out.append(p)
            elif isinstance(p, dict):
                ptype = str(p.get("content_type") or p.get("type") or "").lower()
                out.append("［画像］" if "image" in ptype else "［添付］")
        return "\n".join(out).strip()
    t = content.get("text")
    return t.strip() if isinstance(t, str) else ""


def _active_path(conv):
    """The conversation as the user last saw it: current_node walked up to root,
    reversed. Falls back to all message-bearing nodes ordered by create_time when
    current_node is missing or the chain is broken (defensive)."""
    mapping = conv.get("mapping") or {}
    nodes, seen, node = [], set(), conv.get("current_node")
    while node and node in mapping and node not in seen:
        seen.add(node)
        nodes.append(mapping[node])
        node = mapping[node].get("parent")
    if nodes:
        nodes.reverse()
        return nodes
    leftover = [n for n in mapping.values() if n.get("message")]
    leftover.sort(key=lambda n: (n["message"].get("create_time") or 0))
    return leftover


def flatten_conv(conv, hub, label):
    """ChatGPT-native conversation -> claude-export-shaped dict, or None when it
    holds no real human turn (empty/system-only shell)."""
    msgs = []
    for node in _active_path(conv):
        m = node.get("message")
        if not m:
            continue
        if (m.get("metadata") or {}).get("is_visually_hidden_from_conversation"):
            continue
        sender = ROLE.get((m.get("author") or {}).get("role"))
        if not sender:
            continue
        t = _text(m.get("content"))
        if not t:
            continue
        msgs.append({"sender": sender, "text": t, "created_at": _iso(m.get("create_time"))})
    if not any(m["sender"] == "human" for m in msgs):
        return None
    cid = conv.get("conversation_id") or conv.get("id") or conv.get("uuid") or ""
    created = _iso(conv.get("create_time"))
    return {
        "uuid": cid,
        "name": (conv.get("title") or "").strip(),
        "summary": "",
        "created_at": created,
        "updated_at": _iso(conv.get("update_time")) or created,
        "chat_messages": msgs,
        "_hub": hub,
        "_source_label": label,
    }


HUB = "ChatGPT会話ログ"
LABEL = ("ChatGPT 会話ログ(claude-log-to-scb 自動取り込み)。原本=ローカル archive が SoT。"
         "ユーザー入力=全文 / ChatGPT 応答=要点のみ")


def flatten_all(convs, hub=HUB, label=LABEL):
    return [c for c in (flatten_conv(x, hub, label) for x in convs) if c]


def main(argv):
    raw = open(argv[0]) if argv else sys.stdin
    data = json.load(raw)
    convs = data if isinstance(data, list) else (data.get("items") or [data])
    json.dump(flatten_all(convs), sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1:])
