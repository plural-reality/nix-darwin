#!/usr/bin/env python3
"""Stop-hook: end-of-task self-learning nudge.

Why this exists: the user wants the agent to *self-learn* — after a round of
real work, pause, reconcile any memory it relied on that turned out wrong, and
capture generalizable lessons into the canonical memory store
(~/.claude/projects/-Users-tkgshn/memory/ — the store the harness AUTO-INJECTS
every session) so the same mistake is not repeated. Relying on the model to
"remember" to reflect is unreliable; this hook makes the *trigger* deterministic,
mirroring the existing stop-guard-leaked-toolcall.py contract.

This hook owns only the TRIGGER. The *procedure* (where/how to write, reconcile,
compact) is the single source of truth in the `self-learn` skill — keep it there,
not duplicated here, so it can't drift from reality (the prior version told the
model to write to ~/.codex/memories, which is NOT auto-injected: writes never
reached the next session). See [[project_memory_store_divergence]].

Design contract:
  - Loop-safe: if stop_hook_active is set, never bounce again (exit 0).
  - Once per session: a per-session marker file is written the first time it
    fires, so it nudges at most once and never spams / never loops with the
    AskUserQuestion turn it triggers.
  - Conservative: only fires when the just-finished assistant turn did
    *substantive* work (file edits, scrapbox/calendar/reminder writes, git
    commit/push, freee/osascript/swift mutations). Read-only turns never fire.
  - Fail-open: ANY error -> exit 0, so a broken nudge never wedges a session
    or hides model output.
  - Never blocks more than once; the injected reason explicitly permits
    "今回の学び: なし" so a work turn with nothing durable stops cheaply.
"""
import sys
import os
import json
import re

MARKER_DIR = os.path.expanduser("~/.claude")

# Tool names whose presence in the finished turn signals a mutation worth
# reflecting on. Read-only tools (Read/Grep/Glob/WebSearch/WebFetch/Task) are
# intentionally excluded.
MUTATING_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# Bash command fragments that count as a side-effecting / external write.
MUTATING_BASH_RE = re.compile(
    r"(scrapbox-write|cosense-write|git\s+commit|git\s+push|"
    r"osascript|/apply\b|apply\.swift|recurring\.swift|geofence_reminders\.swift|"
    r"freee_api_(post|put|delete)|gws\s+\w+\s+\w+\s+(create|update|insert)|"
    r"\bgh\s+(pr|issue|release)\s+(create|merge|edit)|"
    r"\bmv\b|\brm\b|\binstall\b|sops\b)",
    re.IGNORECASE,
)

REFLECT_REASON = (
    "[self-learning nudge] このターンで実質的な作業(ファイル編集 / 外部書き込み等)を行いました。"
    "停止する前に self-learn skill を一度だけ実施してください(詳細手順は self-learn skill が正本):\n"
    "1) 補正: 今セッションで*依拠した注入メモリが現実と矛盾していた*ら、その1ファイルを直接 修正/削除し、"
    "MEMORY.md ポインタも整合させ、readback 検証する(確認は取らない)。\n"
    "2) 追加: 再発防止に値する一般化可能な学びを洗い出す(既に code/git/hook/memory が encode 済みは除外)。"
    "(A)基本的な学び(ツールの落とし穴/手順/規約)は確認せず即 append。"
    "(B)『一度叩けば恒久キャッシュできる高レバレッジな外部情報』(保管場所/canonical title/ID・"
    "アカウント帰属/APIエンドポイント・認証経路/毎回聞き直す前提 等)だけ AskUserQuestion で取得＆保存の"
    "可否を確認する(その場で値を尋ねる＝ユーザーをAPIとして叩くのも可)。\n"
    "3) 保存先は canonical store(~/.claude/projects/-Users-tkgshn/memory/)・frontmatter 付き1ファイル・"
    "MEMORY.md に1行ポインタ・readback 検証。❌ ~/.codex/memories には書かない"
    "(Claude Code に自動注入されない＝次の自分に届かない)。\n"
    "4) 一般化できる学びが無ければ『今回の学び: なし』とだけ述べて停止してよい。\n"
    "(このnudgeはセッション1回限り。後から出た学びは『振り返って』で self-learn を再実行できます。)"
)

# MEMORY.md の SessionStart 注入は「先頭200行 OR 25KB の早い方」までで、超過分は無言で全セッションから
# 脱落する(2026-06-27 調査/実測)。over budget なら nudge に圧縮要求を足し self-learn に回収させる
# (200行ルールを skill 散文だけに頼ると skip されうるので、ここで決定論的に発火させる)。
MEMORY_MD = os.path.expanduser("~/.claude/projects/-Users-tkgshn/memory/MEMORY.md")
MEMORY_LINE_BUDGET = 200
MEMORY_BYTE_BUDGET = 25 * 1024


def memory_over_budget():
    """(lines, bytes) if MEMORY.md exceeds the injection budget, else None."""
    try:
        with open(MEMORY_MD, "rb") as fh:
            data = fh.read()
        lines = data.count(b"\n") + 1
        if lines > MEMORY_LINE_BUDGET or len(data) > MEMORY_BYTE_BUDGET:
            return (lines, len(data))
    except Exception:
        pass
    return None


def latest_turn_tool_signals(transcript_path, tail_bytes=2 * 1024 * 1024):
    """Return (tool_names, bash_commands) used in the final assistant turn.

    The final turn = assistant tool_use blocks appearing after the last genuine
    user prompt (a 'user' entry whose content is NOT solely tool_result). Only
    the file tail is read so this stays cheap on multi-MB 1M-context sessions.
    """
    size = os.path.getsize(transcript_path)
    with open(transcript_path, "rb") as fh:
        if size > tail_bytes:
            fh.seek(size - tail_bytes)
            fh.readline()  # discard partial line
        lines = fh.read().decode("utf-8", "replace").splitlines()

    objs = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            objs.append(json.loads(ln))
        except Exception:
            continue

    # Find index of the last genuine user prompt.
    last_user = -1
    for i, o in enumerate(objs):
        if o.get("type") != "user":
            continue
        msg = o.get("message") or {}
        content = msg.get("content")
        if isinstance(content, str):
            last_user = i
        elif isinstance(content, list):
            has_text = any(
                isinstance(b, dict) and b.get("type") in ("text",) for b in content
            )
            only_tool_result = all(
                isinstance(b, dict) and b.get("type") == "tool_result" for b in content
            ) and len(content) > 0
            if has_text or not only_tool_result:
                last_user = i

    tool_names = set()
    bash_cmds = []
    for o in objs[last_user + 1:]:
        if o.get("type") != "assistant":
            continue
        msg = o.get("message") or {}
        for b in msg.get("content") or []:
            if not isinstance(b, dict) or b.get("type") != "tool_use":
                continue
            name = b.get("name", "")
            tool_names.add(name)
            if name == "Bash":
                cmd = (b.get("input") or {}).get("command", "")
                if cmd:
                    bash_cmds.append(cmd)
    return tool_names, bash_cmds


def did_substantive_work(tool_names, bash_cmds):
    if tool_names & MUTATING_TOOLS:
        return True
    return any(MUTATING_BASH_RE.search(c) for c in bash_cmds)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    # Loop-safe: never bounce twice in a row.
    if data.get("stop_hook_active"):
        sys.exit(0)

    session_id = data.get("session_id") or "unknown"
    transcript_path = data.get("transcript_path") or ""
    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    marker = os.path.join(MARKER_DIR, ".reflect-nudge-%s.done" % session_id)
    if os.path.exists(marker):
        sys.exit(0)

    try:
        tool_names, bash_cmds = latest_turn_tool_signals(transcript_path)
    except Exception:
        sys.exit(0)

    if not did_substantive_work(tool_names, bash_cmds):
        sys.exit(0)

    # Fire once: write the marker BEFORE blocking so the reflection turn it
    # triggers (and its own Stop) sees the marker and exits cleanly.
    try:
        with open(marker, "w") as fh:
            fh.write("fired\n")
    except Exception:
        pass

    reason = REFLECT_REASON
    over = memory_over_budget()
    if over:
        reason += (
            "\n⚠️ 圧縮必須: MEMORY.md が %d 行 / 約%dKB で SessionStart 注入上限(先頭200行 OR 25KB の"
            "早い方しか読まれない)を超過。超過分は無言で全セッションから脱落している。今ターンで self-learn の"
            "圧縮(重複ポインタ統合 / 陳腐ファイル削除 / 詳細を topic file へ退避)を必ず実施し、"
            "200行 かつ 25KB 未満へ戻すこと。" % (over[0], over[1] // 1024)
        )
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


if __name__ == "__main__":
    main()
