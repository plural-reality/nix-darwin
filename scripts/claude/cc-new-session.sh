#!/usr/bin/env bash
# Spawn another Claude Code thread in a NEW tab of the current Ghostty window
# (= a new tmux window in the current session). Falls back to a new Ghostty
# window only when not inside tmux.
#
# Usage:
#   cc-new-session.sh                 # fresh blank session, new window
#   cc-new-session.sh --fork          # duplicate the CURRENT session ($CLAUDE_CODE_SESSION_ID)
#   cc-new-session.sh --fork <id>     # duplicate a specific session id
#   cc-new-session.sh <id>            # back-compat: duplicate a specific id
#
# Thin adapter over the canonical launcher `cc`: it already creates a detached
# tmux session (cc-<hash>), sets ultracode, and records the Claude Control
# binding. We add CC_OPEN_TAB=1 so cc opens the thread as a new tab in the
# current Ghostty window (new tmux window in the current session) instead of
# switching the client; CC_OPEN_WINDOW=1 is the not-in-tmux fallback. Plus
# --dangerously-skip-permissions so the new thread starts friction-free.
#
# Bindings on top of this: slash commands /duplicate & /newwin, fish func cc-new.
set -euo pipefail

CC_BIN="${CC_BIN:-/Users/tkgshn/.local/bin/cc}"

case "${1:-}" in
  --fork) fork_id="${2:-${CLAUDE_CODE_SESSION_ID:-}}" ;;
  "")     fork_id="" ;;
  *)      fork_id="$1" ;;
esac

if [ -n "$fork_id" ]; then
  # `claude --resume` は cwd 依存(セッションは cwd ごとの project dir に保存)。
  # 呼び出し時の cwd がドリフトしても確実に解決できるよう、セッション本体の
  # jsonl から本来の cwd を読み取り、そこへ cd してから resume する。
  jsonl="$(ls -1 "$HOME"/.claude/projects/*/"$fork_id".jsonl 2>/dev/null | head -1)"
  if [ -n "$jsonl" ]; then
    sess_cwd="$(grep -o '"cwd":"[^"]*"' "$jsonl" | head -1 | sed 's/^"cwd":"//;s/"$//')"
    [ -n "$sess_cwd" ] && [ -d "$sess_cwd" ] && cd "$sess_cwd"
  fi
  exec env CC_OPEN_TAB=1 CC_OPEN_WINDOW=1 CC_WIN_NAME=dup "$CC_BIN" --resume "$fork_id" --fork-session --dangerously-skip-permissions
else
  exec env CC_OPEN_TAB=1 CC_OPEN_WINDOW=1 CC_WIN_NAME=claude "$CC_BIN" --dangerously-skip-permissions
fi
