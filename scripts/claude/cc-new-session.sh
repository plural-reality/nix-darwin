#!/usr/bin/env bash
# Spawn another Claude Code thread in a NEW tab of the current Ghostty window
# (= a new tmux window in the current session). Falls back to a new Ghostty
# window only when not inside tmux.
#
# Usage:
#   cc-new-session.sh                 # fresh blank session, new window
#   cc-new-session.sh --fork          # duplicate the CURRENT session ($CLAUDE_CODE_SESSION_ID)
#   cc-new-session.sh --fork <id>     # duplicate a specific session id
#   cc-new-session.sh --seed <file>   # spin-off: FRESH session seeded to read <file> (a distilled
#                                     #   topic slice). Unlike --fork it carries NO parent history,
#                                     #   so the split-off topic continues clean. Bound to /spin-off.
#   cc-new-session.sh <id>            # back-compat: duplicate a specific id
#
# Thin adapter over the canonical launcher `cc`: it already creates a detached
# tmux session (cc-<hash>) and records the Claude Control
# binding. We add CC_OPEN_TAB=1 so cc opens the thread as a new tab in the
# current Ghostty window (new tmux window in the current session) instead of
# switching the client; CC_OPEN_WINDOW=1 is the not-in-tmux fallback. Plus
# --dangerously-skip-permissions so the new thread starts friction-free.
#
# Bindings on top of this: slash commands /duplicate & /newwin, fish func cc-new.
set -euo pipefail

CC_BIN="${CC_BIN:-/Users/tkgshn/.local/bin/cc}"

case "${1:-}" in
  --seed)
    # spin-off: 空セッションを開き、短い初期プロンプトで seed(=蒸留された話題スライス)を
    # 読ませて、その話題だけをそこで継続させる。全文 fork と違い親スレッドの散らかりは
    # 一切持ち込まない。seed 本体はファイル(byte stream)として渡し argv を小さく保つ。
    seed_file="${2:-}"
    [ -n "$seed_file" ] && [ -f "$seed_file" ] || {
      echo "cc-new-session: --seed needs an existing file" >&2; exit 1; }
    seed_prompt="この会話は別スレッドからの切り出し(spin-off)です。まず次のファイルを読み込み、そこに要約された話題の続きをこのスレッドで進めてください: ${seed_file} （元の親スレッドは別タブでそのまま継続します）"
    exec env CC_OPEN_TAB=1 CC_OPEN_WINDOW=1 CC_WIN_NAME=spinoff "$CC_BIN" --dangerously-skip-permissions "$seed_prompt"
    ;;
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
