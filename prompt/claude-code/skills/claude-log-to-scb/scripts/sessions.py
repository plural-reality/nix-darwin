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
import datetime
import tempfile
import hashlib

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


CODEX_PARSER_VERSION = "codex-parser-v4"
AUTOMATION_PROMPT_PREFIXES = (
    EXTRACTION_PROMPT_PREFIX,
    "次の Claude Code セッションを要約・分類せよ。",
    "あなたは会話の文字起こしに見出しを付けます。",
    "あなたは会話の記録に題を付けます。",
    "あなたは日報の分類・要約器です。",
)
SAFE_SOURCE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\Z")


def content_fingerprint(value):
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def codex_session_kind(metadata, first_input):
    """Classify explicit execution markers, not certainty about a human author."""
    source = metadata.get("source")
    if isinstance(source, dict) and "subagent" in source:
        return "subagent", "explicit native subagent source"
    if first_input.lstrip().startswith(AUTOMATION_PROMPT_PREFIXES):
        return "automation", "known automation prompt prefix"
    # 'exec' also contains genuine one-shot user work. It is not an exclusion.
    return "human_session", "conversation_candidate: no explicit automation/subagent marker"


def codex_parent_id(metadata):
    parent = metadata.get("forked_from_id") or metadata.get("parent_thread_id")
    source = metadata.get("source")
    subagent = source.get("subagent") if isinstance(source, dict) else None
    spawn = subagent.get("thread_spawn") if isinstance(subagent, dict) else None
    if not parent and isinstance(spawn, dict):
        parent = spawn.get("parent_thread_id")
    return parent if isinstance(parent, str) and SAFE_SOURCE_ID.fullmatch(parent) else None


def timestamp_order(value):
    if not isinstance(value, str):
        return float("-inf")
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=datetime.timezone.utc)
        return parsed.timestamp()
    except ValueError:
        return float("-inf")


CODEX_INJECTED_USER_PREFIXES = SKILL_INJECTION_PREFIXES + (
    "# AGENTS.md instructions",
    "<environment_context>",
    "<recommended_plugins>",
    "<skills_instructions>",
    "<user_instructions>",
)


def _codex_response_message(payload, *, legacy_flat=False):
    """Read dialogue blocks; only flat rollouts lack assistant final phases."""
    if payload.get("type") != "message" or payload.get("role") not in ("user", "assistant"):
        return None, False, 0
    role = payload["role"]
    if (role == "assistant" and payload.get("phase") != "final_answer"
            and not (legacy_flat and payload.get("phase") is None)):
        return None, False, 0
    blocks = payload.get("content")
    if not isinstance(blocks, list):
        raise ValueError("Codex message has malformed content blocks")
    metadata = payload.get("internal_chat_message_metadata_passthrough")
    metadata = metadata if isinstance(metadata, dict) else {}
    kinds = metadata.get("content_item_kinds")
    legacy = role == "user" and not isinstance(kinds, list)
    excluded = 0
    if role == "user" and isinstance(kinds, list):
        if len(kinds) != len(blocks):
            raise ValueError("Codex user content kinds do not match its blocks")
        selected = [block for kind, block in zip(kinds, blocks) if kind == "user.text"]
        excluded = len(blocks) - len(selected)
    else:
        selected = blocks
    text_blocks = [block["text"] for block in selected
                   if isinstance(block, dict) and block.get("type") in ("input_text", "output_text")
                   and isinstance(block.get("text"), str)]
    # Untyped user messages can mix injected context and real input in either
    # order. Filter each block before joining, preserving explicit user.text.
    retained = [text for text in text_blocks
                if not (legacy and text.lstrip().startswith(CODEX_INJECTED_USER_PREFIXES))]
    excluded += len(text_blocks) - len(retained)
    text = "\n".join(retained).strip()
    if not text:
        return None, False, excluded
    item_id, turn_id = payload.get("id"), metadata.get("turn_id")
    message = {"sender": "human" if role == "user" else "assistant", "text": text,
               "_transport": "legacy_flat_message" if legacy_flat else "response_item"}
    if isinstance(item_id, str) and item_id:
        message["source_item_id"] = item_id
    if isinstance(turn_id, str) and turn_id:
        message["turn_id"] = turn_id
    return message, legacy, excluded


def _dedupe_codex_messages(candidates):
    """Prefer item identity, then pair adjacent legacy event/item mirrors once.

    Equal text from two different turns is not duplicate evidence. Without an
    ID, only an adjacent cross-transport pair can be safely recognized here.
    """
    result = []
    by_item_id = {}
    paired = set()
    for candidate in candidates:
        item_id = candidate.get("source_item_id")
        key = (candidate["sender"], item_id) if item_id else None
        existing_index = by_item_id.get(key) if key else None
        if existing_index is not None:
            # Replayed same-ID items denote one message, including an updated
            # final version. Prefer response_item's typed provenance.
            existing = result[existing_index]
            if candidate["_transport"] == "response_item" or existing["_transport"] != "response_item":
                result[existing_index] = candidate
            continue
        previous_index = len(result) - 1
        previous = result[-1] if result else None
        same_turn = previous is not None and (
            not previous.get("turn_id") or not candidate.get("turn_id")
            or previous["turn_id"] == candidate["turn_id"]
        )
        mirror = (previous is not None and previous_index not in paired and same_turn
                  and previous["_transport"] != candidate["_transport"]
                  and previous["sender"] == candidate["sender"] and previous["text"] == candidate["text"]
                  and (not previous.get("source_item_id") or not item_id
                       or previous["source_item_id"] == item_id))
        if mirror:
            if candidate["_transport"] == "response_item":
                result[previous_index] = candidate
            paired.add(previous_index)
            if key:
                by_item_id[key] = previous_index
        else:
            result.append(candidate)
            if key:
                by_item_id[key] = len(result) - 1
    return [{k: v for k, v in message.items() if k != "_transport"} for message in result]


def parse_codex_session(path):
    """Normalize a native rollout; inherited headers never replace its identity.

    Messages may contain forked history. Preserve that scope explicitly rather
    than claiming that every user_message was newly written in this session.
    System, developer and tool bodies are not copied to the normalized archive.
    """
    metadata = None
    rollout_format = "session_meta"
    first_record = True
    created_at = updated_at = None
    inherited_ids = []
    candidates = []
    legacy_user_candidates = 0
    excluded_injected_blocks = 0
    malformed_lines = 0
    raw_hash = hashlib.sha256()
    with open(path, "rb") as source:
        for raw_line in source:
            raw_hash.update(raw_line)
            if not raw_line.strip():
                continue
            is_first_record = first_record
            first_record = False
            try:
                event = json.loads(raw_line)
            except (json.JSONDecodeError, UnicodeDecodeError):
                if metadata is None:
                    raise ValueError("Codex rollout has malformed content before native identity")
                malformed_lines += 1
                continue
            if not isinstance(event, dict):
                if metadata is None:
                    raise ValueError("Codex rollout has malformed content before native identity")
                malformed_lines += 1
                continue
            timestamp = event.get("timestamp")
            if timestamp_order(timestamp) > timestamp_order(updated_at):
                updated_at = timestamp
            # 2025 rollouts start with an untyped native header, followed by
            # record_type markers and direct message/reasoning/tool items. Only
            # that first record may establish legacy identity; never infer it
            # from a later inherited header or the filename.
            if (is_first_record and "type" not in event
                    and "id" in event and "timestamp" in event):
                session_id = event["id"]
                if not isinstance(session_id, str) or not SAFE_SOURCE_ID.fullmatch(session_id):
                    raise ValueError("Codex rollout has invalid native session identity")
                metadata = event
                rollout_format = "legacy_flat"
                created_at = timestamp
                continue
            if rollout_format == "legacy_flat" and event.get("type") == "message":
                candidate, legacy, excluded = _codex_response_message(event, legacy_flat=True)
                legacy_user_candidates += int(legacy)
                excluded_injected_blocks += excluded
                if candidate is not None:
                    candidates.append(candidate)
                continue
            payload = event.get("payload")
            if not isinstance(payload, dict):
                if event.get("type") == "session_meta" and metadata is None:
                    raise ValueError("Codex rollout has malformed native session metadata")
                continue
            if event.get("type") == "session_meta":
                if metadata is None:
                    session_id = payload.get("id")
                    if not isinstance(session_id, str) or not SAFE_SOURCE_ID.fullmatch(session_id):
                        raise ValueError("Codex rollout has invalid native session identity")
                    metadata = payload
                    created_at = timestamp or payload.get("timestamp")
                else:
                    inherited_id = payload.get("id")
                    if (isinstance(inherited_id, str) and SAFE_SOURCE_ID.fullmatch(inherited_id)
                            and inherited_id != metadata["id"] and inherited_id not in inherited_ids):
                        inherited_ids.append(inherited_id)
                continue
            if event.get("type") == "response_item":
                candidate, legacy, excluded = _codex_response_message(payload)
                legacy_user_candidates += int(legacy)
                excluded_injected_blocks += excluded
                if candidate is not None:
                    candidates.append(candidate)
                continue
            if event.get("type") != "event_msg":
                continue
            sender = None
            if payload.get("type") == "user_message":
                sender = "human"
            elif (payload.get("type") == "agent_message"
                  and payload.get("phase") in (None, "final_answer")):
                sender = "assistant"
            text = payload.get("message")
            if sender and isinstance(text, str) and text.strip():
                if sender == "human" and text.lstrip().startswith(CODEX_INJECTED_USER_PREFIXES):
                    excluded_injected_blocks += 1
                    continue
                candidate = {"sender": sender, "text": text.strip(), "_transport": "event_msg"}
                for field, value in (("source_item_id", payload.get("message_id")),
                                     ("turn_id", payload.get("turn_id"))):
                    if isinstance(value, str) and value:
                        candidate[field] = value
                candidates.append(candidate)
    if metadata is None:
        raise ValueError("Codex rollout is missing native session identity")
    messages = _dedupe_codex_messages(candidates)
    humans = [message for message in messages if message["sender"] == "human"]
    if not humans:
        return None
    session_id = metadata["id"]
    cwd = metadata.get("cwd") if isinstance(metadata.get("cwd"), str) else ""
    seed = humans[0]["text"].split("\n")[0].strip()
    short = (seed[:48] + "…") if len(seed) > 48 else seed
    project = project_for_cwd(cwd)
    kind, reason = codex_session_kind(metadata, humans[0]["text"])
    native_source = metadata.get("source")
    source_marker = "unknown_legacy" if rollout_format == "legacy_flat" else (
        native_source if isinstance(native_source, str) else (
            "subagent" if isinstance(native_source, dict) and "subagent" in native_source else "unknown"
        )
    )
    if rollout_format == "legacy_flat":
        reason += "; legacy source and assistant final phase unavailable"
    return {
        "uuid": f"codex-{session_id}",
        "name": clean_title(short, f"codex {session_id[:8]}"),
        "created_at": created_at,
        "updated_at": updated_at,
        "chat_messages": messages,
        "_entities": [project] if project else [],
        "_hub": "Codexセッション",
        "_source_label": "Codex セッション自動取り込み。入力=全文 / Codex応答=要点のみ（継承された履歴を含む場合あり）",
        "_origin": f"{path} (cwd={cwd})",
        "_source_key": f"codex:{session_id}",
        "_content_hash": content_fingerprint(messages),
        "_source_version": f"{CODEX_PARSER_VERSION}:{raw_hash.hexdigest()}",
        "_session_kind": kind,
        "_session_kind_reason": reason,
        "_provenance": {
            "native_id": session_id,
            "parent_thread_id": codex_parent_id(metadata),
            "inherited_session_ids": inherited_ids,
            "metadata_source": source_marker,
            "rollout_format": rollout_format,
            "assistant_scope": ("legacy_message_role_only_phase_unavailable" if rollout_format == "legacy_flat"
                                else "final_response_items_and_legacy_event_messages"),
            "parser_version": CODEX_PARSER_VERSION,
            "body_scope": "native_rollout_including_inherited_context",
            "malformed_lines": malformed_lines,
            "legacy_user_message_candidates": legacy_user_candidates,
            "excluded_injected_user_blocks": excluded_injected_blocks,
        },
    }


def source_paths(source):
    return (
        (ARCHIVE, CONV_DIR, EXTRACTED, SEEN)
        if source == "claude"
        else (CODEX_ARCHIVE, CODEX_CONV_DIR, CODEX_EXTRACTED, CODEX_SEEN)
    )


def _message_excerpt(text, budget):
    """Return literal source slices and their half-open Unicode character ranges."""
    if budget <= 0 or not text:
        return "", []
    if len(text) <= budget:
        return text, [{"start": 0, "end": len(text)}]
    marker = "\n…(message middle omitted)…\n"
    if budget < len(marker) + 2:
        return text[-budget:], [{"start": len(text) - budget, "end": len(text)}]
    available = budget - len(marker)
    head = available // 2
    tail = available - head
    return text[:head] + marker + text[-tail:], [
        {"start": 0, "end": head}, {"start": len(text) - tail, "end": len(text)}
    ]


def bounded_transcript(msgs, cap=4000):
    """Bound extraction input while retaining the newest correction and reply.

    Coverage is measured against normalized message text, in Unicode codepoints
    with end-exclusive ranges. It does not assert full original-rollout coverage.
    """
    if not isinstance(cap, int) or cap < 0:
        raise ValueError("transcript cap must be a non-negative integer")
    messages = [{"sender": m["sender"], "text": m["text"]} for m in msgs]
    labels = [f"{m['sender']}: [message {index}] " for index, m in enumerate(messages)]
    full = "\n".join(label + m["text"] for label, m in zip(labels, messages))
    chosen = {}
    if len(full) <= cap:
        text = full
        for index, m in enumerate(messages):
            if m["text"]:
                chosen[index] = (labels[index] + m["text"], [{"start": 0, "end": len(m["text"])}])
    else:
        marker = "…(partial transcript; see transcript_coverage)\n"
        # For very small caps the coverage contract remains the omission signal.
        prefix = marker if len(marker) < cap else ""
        remaining = cap - len(prefix)
        human_indices = [i for i, m in enumerate(messages) if m["sender"] == "human"]
        assistant_indices = [i for i, m in enumerate(messages) if m["sender"] == "assistant"]
        core = list(dict.fromkeys(
            (human_indices[-1:] + assistant_indices[-1:] + human_indices[:1])
            or list(range(len(messages) - 1, -1, -1))[:1]
        ))

        def include(index, budget):
            nonlocal remaining
            separator = 1 if chosen else 0
            available = min(budget, remaining) - len(labels[index]) - separator
            excerpt, ranges = _message_excerpt(messages[index]["text"], available)
            if ranges:
                chunk = labels[index] + excerpt
                chosen[index] = (chunk, ranges)
                remaining -= len(chunk) + separator

        for position, index in enumerate(core):
            # Reserve a share for every core message; a short correction frees
            # unused space for the last answer/initial request.
            include(index, remaining // (len(core) - position))
        for index in range(len(messages) - 1, -1, -1):
            if index not in chosen:
                include(index, remaining)
        text = prefix + "\n".join(chosen[i][0] for i in sorted(chosen))
    ranges = [{"message_index": i, "ranges": chosen[i][1]} for i in sorted(chosen)]
    included_chars = sum(r["end"] - r["start"] for entry in ranges for r in entry["ranges"])
    covered = sorted(chosen)
    partial = [entry["message_index"] for entry in ranges
               if sum(r["end"] - r["start"] for r in entry["ranges"])
               < len(messages[entry["message_index"]]["text"])]
    return {
        "text": text,
        "coverage": {
            "strategy": "latest-human-latest-assistant-first-human-head-tail-v1",
            "range_unit": "unicode_codepoint_end_exclusive",
            "total_messages": len(messages),
            "covered_message_indices": covered,
            "omitted_message_indices": [i for i in range(len(messages)) if i not in chosen],
            "partial_message_indices": partial,
            "message_ranges": ranges,
            "total_chars": sum(len(m["text"]) for m in messages),
            "included_chars": included_chars,
            "rendered_chars": len(text),
            "cap_chars": cap,
        },
    }


def transcript(msgs, cap=4000):
    """Compatibility wrapper for callers that need only the bounded text."""
    return bounded_transcript(msgs, cap)["text"]


def _write_private_json(path, value):
    """Atomically replace one generated artifact; a failed write preserves base."""
    directory = os.path.dirname(path)
    fd, temporary = tempfile.mkstemp(prefix=".sessions-", suffix=".json", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            os.fchmod(output.fileno(), 0o600)
            json.dump(value, output, ensure_ascii=False)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def build(source, selected_uuids=None, output_root=None):
    archive, conv_dir, _, _ = source_paths(source)
    selected = None
    if selected_uuids is not None:
        if (source != "codex" or not isinstance(selected_uuids, (list, tuple))
                or not selected_uuids or any(
                    not isinstance(uuid, str) or not uuid.startswith("codex-")
                    or not SAFE_SOURCE_ID.fullmatch(uuid[6:]) for uuid in selected_uuids)):
            raise ValueError("selected build requires explicit Codex source UUIDs")
        if not output_root:
            raise ValueError("selected build requires a separate --output-root")
        selected = set(selected_uuids)
    if output_root is not None:
        output_root = os.path.expanduser(os.fspath(output_root))
        snapshot_paths = (os.path.join(output_root, "archive"), os.path.join(output_root, "compact"))
        if selected is not None:
            # A selected subset must never replace the full normalized archive
            # or its compacts, including through an existing symlink.
            for target in map(os.path.realpath, snapshot_paths):
                for canonical in map(os.path.realpath, (archive, conv_dir)):
                    if os.path.commonpath((target, canonical)) in (target, canonical):
                        raise ValueError("selected output overlaps the canonical archive or compacts")
        archive, conv_dir = snapshot_paths
    files = (
        glob.glob(os.path.join(PROJECTS_ROOT, "*", "*.jsonl"))
        if source == "claude"
        else [path for pattern in CODEX_ROOTS for path in glob.glob(pattern, recursive=True)]
    )
    files = sorted(set(files))
    if selected is not None:
        # Filename identity is only a bounded discovery hint. Include suffix
        # fork/copy candidates too, then verify every parsed native identity.
        native_ids = [uuid[6:] for uuid in selected]
        files = [path for path in files if any(native in os.path.basename(path) for native in native_ids)]
    parser = parse_session if source == "claude" else parse_codex_session
    by_id = {}
    ignored = 0
    for path in files:
        conv = parser(path)
        if selected is not None:
            if conv is None or conv.get("uuid") not in selected:
                raise ValueError("selected filename candidate has no matching native conversation")
            if (conv.get("_session_kind") != "human_session"
                    or conv.get("_provenance", {}).get("malformed_lines") != 0):
                raise ValueError("selected source is ineligible or contains malformed records")
        if conv is None:
            ignored += 1
            continue
        # The Claude adapter keeps its prior eligibility rules, but downstream
        # compact/extraction revisions use the same explicit source contract.
        if "_source_key" not in conv:
            digest = content_fingerprint(conv["chat_messages"])
            conv = {**conv, "_source_key": f"claude-code:{conv['uuid']}",
                    "_content_hash": digest,
                    "_source_version": f"claude-parser-v1:{content_fingerprint(conv)}",
                    "_session_kind": "human_session",
                    "_session_kind_reason": "conversation_candidate: existing Claude adapter eligibility",
                    "_provenance": {"native_id": conv["uuid"], "parser_version": "claude-parser-v1"}}
        prior = by_id.get(conv["uuid"])
        if prior is not None:
            old_messages, new_messages = prior["chat_messages"], conv["chat_messages"]
            common_length = min(len(old_messages), len(new_messages))
            if (old_messages[:common_length] != new_messages[:common_length]
                    or prior["_session_kind"] != conv["_session_kind"]):
                raise ValueError(f"Conflicting source content for {conv['uuid']}; archive left unchanged")
            # A moved/copy-identical or append-only rollout is one source.
            # Keep the longer transcript; never silently merge divergent copies.
            if len(old_messages) > len(new_messages):
                continue
            if (len(old_messages) == len(new_messages)
                    and timestamp_order(prior.get("updated_at")) >= timestamp_order(conv.get("updated_at"))):
                continue
        by_id[conv["uuid"]] = conv
    if selected is not None and set(by_id) != selected:
        raise ValueError("every selected source must resolve exactly once before snapshot generation")
    convs = list(by_id.values())
    eligible = [c for c in convs if c["_session_kind"] == "human_session"]
    os.makedirs(archive, exist_ok=True)
    os.makedirs(conv_dir, exist_ok=True)
    # Persist every classified normalized transcript locally. Ineligible traces
    # remain auditable; they are omitted only from extraction's explicit index.
    _write_private_json(os.path.join(archive, "conversations.json"), convs)
    index = []
    for conv in eligible:
        bounded = bounded_transcript(conv["chat_messages"])
        compact = {"uuid": conv["uuid"], "name": conv["name"], "summary": "",
                   "created_at": conv["created_at"], "transcript": bounded["text"],
                   "source_key": conv["_source_key"], "source_version": conv["_source_version"],
                   "content_hash": conv["_content_hash"], "session_kind": conv["_session_kind"],
                   "provenance": conv["_provenance"], "transcript_coverage": bounded["coverage"]}
        _write_private_json(os.path.join(conv_dir, f"{conv['uuid']}.json"), compact)
        index.append(conv["uuid"])
    # Index goes last: interrupted builds do not advertise a not-yet-written file.
    _write_private_json(os.path.join(conv_dir, "_index.json"), index)
    kinds = {kind: sum(c["_session_kind"] == kind for c in convs)
             for kind in sorted({c["_session_kind"] for c in convs})}
    if selected is not None:
        print(json.dumps({"status": "built", "scope": "selected", "unselected_sources": "not_inspected",
                          "source_uuids": sorted(selected), "candidate_files": len(files),
                          "records": len(convs), "extraction": len(index)}, ensure_ascii=False))
    else:
        print(f"built {len(convs)} {source} source records; extraction={len(index)} ignored={ignored} kinds={kinds}")


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
    if args.source == "codex":
        if not args.uuid:
            raise SystemExit("Codex projection requires explicit --uuid; legacy title-based writes are disabled")
        from projection import main as project_main
        argv = ["--archive", os.path.join(CODEX_ARCHIVE, "conversations.json"),
                "--conv-dir", CODEX_CONV_DIR, "--extracted", CODEX_EXTRACTED,
                "--project", args.project]
        for uuid in args.uuid:
            argv.extend(["--uuid", uuid])
        if args.dry_run:
            argv.append("--dry-run")
        return project_main(argv)
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
    return 1 if errors else 0


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
    b.add_argument("--uuid", action="append", help="Inspect only filename candidates for these native Codex IDs")
    b.add_argument("--output-root", help="Separate snapshot root; required for selected builds")
    r = sub.add_parser("render")
    r.add_argument("--source", choices=("claude", "codex"), default="claude")
    r.add_argument("--uuid", action="append")
    r.add_argument("--project", default="takalog")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", action="store_true")
    r.add_argument("--limit", type=int, default=0)
    args = ap.parse_args(argv)
    if args.cmd == "build":
        build(args.source, selected_uuids=args.uuid, output_root=args.output_root)
    elif args.cmd == "render":
        return render_cmd(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
