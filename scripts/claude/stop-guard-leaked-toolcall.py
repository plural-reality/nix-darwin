#!/usr/bin/env python3
"""Stop-hook guard for leaked / unexecuted tool calls.

Why this exists: Opus 4.7/4.8 have a server-side regression where, on a
stop_reason:tool_use turn, the model serializes a tool call as legacy <invoke>
XML *text* (often led by a stray "court"/"count" token or with the antml:
namespace / <function_calls> wrapper dropped). The harness cannot parse it, so
it renders as plain text, NO tool runs, and the turn stalls until the human
types "続けて". This hook fires at Stop, detects that leaked markup in the final
assistant message, and bounces ONCE so the model re-issues a proper structured
call — automating the manual "続けて".

Design contract (mirrors zenn.dev/ultimatile battle-tested version):
  - Loop-safe: if stop_hook_active is already set, never bounce again.
  - Fail-open: ANY error -> exit 0, so a broken guard never wedges a session
    or hides model output.
  - Never parses/executes the leaked markup (lenient parsing would be a
    prompt-injection escalation vector). It only pattern-matches and re-prompts.
Refs: anthropics/claude-code #60584 #62344 #62407 #63870 #64658 #64314 #64235.
"""
import sys, json, re, os, datetime

# Line-anchored so inline prose mentions like `the <invoke name= tag` (which have
# text/backtick before '<') do NOT match. Allows an optional namespace prefix
# (antml:) and the three leaked shapes: <invoke name=, <function_calls>, <parameter name=.
LEAK_RE = re.compile(
    r"^[ \t]*<(?:[A-Za-z][\w.-]*:)?(?:invoke\s+name=|function_calls\s*>|parameter\s+name=)",
    re.MULTILINE,
)
TRIGGER_LOG = os.path.expanduser("~/.claude/.stop-guard-toolcall.log")


def last_assistant_text(transcript_path, tail_bytes=1024 * 1024):
    """Concatenated text blocks of the final assistant message in the transcript.

    Reads only the file tail (the final assistant message sits near EOF) so this
    stays cheap on long 1M-context sessions whose transcript is many MB. A
    partial first line from the mid-seek is skipped by the json.loads guard.
    """
    size = os.path.getsize(transcript_path)
    with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
        if size > tail_bytes:
            f.seek(size - tail_bytes)
        lines = f.readlines()
    for raw in reversed(lines):
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except Exception:
            continue
        if obj.get("type") != "assistant":
            continue
        content = obj.get("message", {}).get("content", "")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "\n".join(
                b.get("text", "")
                for b in content
                if isinstance(b, dict) and b.get("type") == "text"
            )
        return ""
    return ""


def strip_code_fences(text):
    """Drop ```-fenced regions so legitimately documented tool-call XML (in a code
    block) does not trigger. A real leak is never inside a fence."""
    out, in_fence = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def main():
    payload = json.load(sys.stdin)

    # Already in a forced continuation from a prior block -> stop here (loop guard).
    if payload.get("stop_hook_active"):
        sys.exit(0)

    transcript_path = payload.get("transcript_path")
    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    text = last_assistant_text(transcript_path)
    if not text or not LEAK_RE.search(strip_code_fences(text)):
        sys.exit(0)

    # Detected a leaked, unexecuted tool call. Log (for monitoring whether the
    # guard can eventually be retired) and bounce once.
    try:
        with open(TRIGGER_LOG, "a", encoding="utf-8") as lf:
            lf.write(json.dumps({
                "ts": datetime.datetime.now().isoformat(timespec="seconds"),
                "session": payload.get("session_id"),
                "cwd": payload.get("cwd"),
            }, ensure_ascii=False) + "\n")
    except Exception:
        pass

    reason = (
        "前のターンで tool call の開始タグが壊れ（court/count 等のゴミトークン、"
        "antml: プレフィックス欠落、または <function_calls> ラッパー消失で）、tool が"
        "実行されずテキストとして残っています。これは Opus 4.7/4.8 のサーバーサイド回帰です。\n"
        "いま意図していた tool 呼び出しを、正しい構造化フォーマットで1回だけ再発行してください。"
        "直前に出てしまった壊れた XML テキストは絶対にコピー・再現しないこと。\n"
        "もし再発行してもまた壊れる場合は、リトライを繰り返さず（自家中毒で悪化します）"
        "/clear か /rewind でセッション履歴をリセットしてください。"
    )
    print(json.dumps({
        "decision": "block",
        "reason": reason,
        "systemMessage": "⚠️ 漏れた tool call を検知し、自動で再発行を要求しました（Stop-guard）。",
    }, ensure_ascii=False))
    sys.exit(0)


try:
    main()
except Exception:
    # Fail-open: never wedge the session on a guard bug.
    sys.exit(0)
